package handlers

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

const maxReceiptUploadBytes = 8 << 20 // 8MB

// receiptCategories must be kept in sync with kCategories in frontend/lib/utils.dart.
const receiptCategories = "Engine, Transmission, Brakes, Suspension, Electrical, Body/Paint, Tires, Interior, AC/Heat, Transport, Storage, Inspection, Rent, Consumables, Other"

func ScanReceipt(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)

	var c models.Car
	err := db.DB.QueryRow(`SELECT id, make, model, year FROM cars WHERE id=$1`, carID).
		Scan(&c.ID, &c.Make, &c.Model, &c.Year)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxReceiptUploadBytes)
	if err := r.ParseMultipartForm(maxReceiptUploadBytes); err != nil {
		http.Error(w, `{"error":"upload too large or invalid"}`, 400)
		return
	}
	file, _, err := r.FormFile("image")
	if err != nil {
		http.Error(w, `{"error":"missing image file"}`, 400)
		return
	}
	defer file.Close()

	imgBytes, err := io.ReadAll(file)
	if err != nil {
		http.Error(w, `{"error":"failed to read image"}`, 400)
		return
	}

	mimeType := http.DetectContentType(imgBytes)
	switch mimeType {
	case "image/jpeg", "image/png", "image/webp":
	default:
		http.Error(w, fmt.Sprintf(`{"error":"unsupported file type: %s"}`, mimeType), 400)
		return
	}

	var receiptID int64
	err = db.DB.QueryRow(`
		INSERT INTO receipts(car_id, image_data, mime_type) VALUES($1,$2,$3) RETURNING id`,
		carID, imgBytes, mimeType).Scan(&receiptID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	prompt := fmt.Sprintf(`You are extracting expense line items from a photo of a receipt for a car-flipping business (this receipt is for car ID %d — %d %s %s).

Respond with ONLY a JSON object — no markdown, no code fences, no explanation. Use this exact structure:
{
  "vendor": "<store/vendor name, empty string if unreadable>",
  "receipt_date": "<YYYY-MM-DD, empty string if unreadable>",
  "tax": <number, total sales tax charged on the receipt, 0 if none>,
  "items": [
    {
      "category": "<one of: %s>",
      "description": "<short description of the part or service>",
      "part_number": "<part number if visible, else empty string>",
      "quantity": <number, default 1>,
      "unit_price": <number>,
      "amount": <number, quantity * unit_price, matching the line total on the receipt>
    }
  ]
}

Rules:
- Include one entry per distinct part or service line — most receipts have several.
- If the receipt truly has only one purchased item, return a single-element items array.
- Tax, subtotal, and total lines are not items — do not put them in "items". Report the sales tax total in "tax" instead (sum multiple tax lines if present).
- Item amounts must be pre-tax.
- Pick the closest matching category for each item; use "Other" if nothing fits well.
- If a field is illegible, make a reasonable best guess (quantity defaults to 1) rather than failing.`,
		c.ID, c.Year, c.Make, c.Model, receiptCategories)

	content := []map[string]interface{}{
		{
			"type": "image",
			"source": map[string]interface{}{
				"type":       "base64",
				"media_type": mimeType,
				"data":       base64.StdEncoding.EncodeToString(imgBytes),
			},
		},
		{"type": "text", "text": prompt},
	}

	text, err := callClaude(content, 2048)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":%q,"receipt_id":%d}`, err.Error(), receiptID), 502)
		return
	}

	var result models.ReceiptScanResult
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"parse failed: %s","raw":%q,"receipt_id":%d}`, err, text, receiptID), 500)
		return
	}
	result.ReceiptID = receiptID
	splitTax(result.Items, result.Tax)

	db.DB.Exec(`UPDATE receipts SET vendor=$1, receipt_date=$2 WHERE id=$3`, result.Vendor, result.ReceiptDate, receiptID)

	json.NewEncoder(w).Encode(result)
}

// splitTax spreads the receipt's tax across items in proportion to each item's
// pre-tax amount, so every expense reflects what was actually paid. Amounts are
// rounded to cents and the last item absorbs any rounding remainder so the
// items sum exactly to subtotal + tax.
func splitTax(items []models.ReceiptItem, tax float64) {
	if tax <= 0 || len(items) == 0 {
		return
	}
	var subtotal float64
	for _, it := range items {
		subtotal += it.Amount
	}
	if subtotal <= 0 {
		return
	}
	round := func(v float64) float64 { return math.Round(v*100) / 100 }
	remaining := round(tax)
	for i := range items {
		share := round(tax * items[i].Amount / subtotal)
		if i == len(items)-1 {
			share = remaining
		}
		remaining = round(remaining - share)
		items[i].Amount = round(items[i].Amount + share)
		if items[i].Quantity > 0 {
			items[i].UnitPrice = items[i].Amount / items[i].Quantity
		}
	}
}

func GetReceiptImage(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)

	var imageData []byte
	var mimeType string
	err := db.DB.QueryRow(`SELECT image_data, mime_type FROM receipts WHERE id=$1`, id).
		Scan(&imageData, &mimeType)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	// Overwrites the jsonMiddleware default Content-Type since headers aren't
	// flushed until the first Write.
	w.Header().Set("Content-Type", mimeType)
	w.Write(imageData)
}
