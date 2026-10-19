// Command backfilltax corrects receipt-scanned expenses that were created
// before tax handling existed. For each receipt that has linked expenses, it
// re-scans the stored image to recover the pre-tax subtotal and the sales tax,
// then decides what to do by comparing the receipt's CURRENT expense total:
//
//   - current total ≈ subtotal            → tax is missing; spread tax across
//     the existing expenses (proportional
//     to each amount, cents-rounded, last
//     expense absorbs the remainder).
//   - current total ≈ subtotal + tax      → tax already applied; skip.
//   - anything else (edited / partial)    → skip and report for manual review.
//
// It is read-only unless --apply is passed. Run --apply only after reviewing
// the dry-run output and taking a database backup.
//
// Env: DATABASE_URL and ANTHROPIC_API_KEY (inherited from the backend
// container when run via `docker exec wrenchlogs-backend ...`).
package main

import (
	"bytes"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

const (
	claudeModel       = "claude-haiku-4-5-20251001"
	receiptCategories = "Engine, Transmission, Brakes, Suspension, Electrical, Body/Paint, Tires, Interior, AC/Heat, Transport, Storage, Inspection, Other"
)

func round2(v float64) float64 { return math.Round(v*100) / 100 }

func main() {
	apply := flag.Bool("apply", false, "write changes (default: dry run, no writes)")
	only := flag.Int64("receipt", 0, "process only this receipt id (0 = all)")
	limit := flag.Int("limit", 0, "process at most N receipts (0 = no limit)")
	flag.Parse()

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://coownerly:coownerly_dev_password@localhost:5432/wrenchlogs?sslmode=disable"
	}
	if os.Getenv("ANTHROPIC_API_KEY") == "" {
		log.Fatal("ANTHROPIC_API_KEY not set")
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	if err := db.Ping(); err != nil {
		log.Fatal("db ping:", err)
	}

	mode := "DRY RUN (no changes written)"
	if *apply {
		mode = "APPLY (writing changes)"
	}
	fmt.Printf("=== receipt tax backfill — %s ===\n\n", mode)

	q := `SELECT r.id, r.car_id, r.image_data, r.mime_type, c.year, c.make, c.model
	      FROM receipts r JOIN cars c ON c.id = r.car_id
	      WHERE EXISTS (SELECT 1 FROM expenses e WHERE e.receipt_id = r.id)`
	args := []interface{}{}
	if *only != 0 {
		q += " AND r.id = $1"
		args = append(args, *only)
	}
	q += " ORDER BY r.id"

	rows, err := db.Query(q, args...)
	if err != nil {
		log.Fatal(err)
	}
	type receipt struct {
		id, carID   int64
		img         []byte
		mime        string
		year        int
		make, model string
	}
	var receipts []receipt
	for rows.Next() {
		var r receipt
		if err := rows.Scan(&r.id, &r.carID, &r.img, &r.mime, &r.year, &r.make, &r.model); err != nil {
			log.Fatal(err)
		}
		receipts = append(receipts, r)
	}
	rows.Close()

	var fixed, skipAlready, skipNoTax, skipManual, errs int
	for i, r := range receipts {
		if *limit > 0 && i >= *limit {
			break
		}
		fmt.Printf("receipt %d (car %d — %d %s %s): ", r.id, r.carID, r.year, r.make, r.model)

		// Current expenses linked to this receipt.
		type exp struct {
			id     int64
			amount float64
			qty    float64
		}
		erows, err := db.Query(`SELECT id, amount, quantity FROM expenses WHERE receipt_id=$1 ORDER BY id`, r.id)
		if err != nil {
			fmt.Println("ERROR reading expenses:", err)
			errs++
			continue
		}
		var exps []exp
		var curTotal float64
		for erows.Next() {
			var e exp
			erows.Scan(&e.id, &e.amount, &e.qty)
			exps = append(exps, e)
			curTotal += e.amount
		}
		erows.Close()
		curTotal = round2(curTotal)
		if len(exps) == 0 {
			fmt.Println("no linked expenses, skip")
			continue
		}

		tax, subtotal, err := rescan(r.img, r.mime, r.year, r.make, r.model)
		if err != nil {
			fmt.Println("ERROR re-scanning:", err)
			errs++
			continue
		}
		grand := round2(subtotal + tax)
		// Tolerance scales with the number of line items (cent-rounding) plus a
		// small relative allowance for how the re-scan reads totals.
		n := float64(len(exps))
		tol := math.Max(0.02*n+0.05, 0.02*subtotal)

		fmt.Printf("current=$%.2f subtotal=$%.2f tax=$%.2f grand=$%.2f | ", curTotal, subtotal, tax, grand)

		switch {
		case tax <= 0:
			fmt.Println("no tax on receipt, skip")
			skipNoTax++
			continue
		case math.Abs(curTotal-grand) <= tol:
			fmt.Println("already includes tax, skip")
			skipAlready++
			continue
		case math.Abs(curTotal-subtotal) <= tol:
			// Needs the tax added.
		default:
			fmt.Println("current total matches neither subtotal nor grand total — SKIP for manual review")
			skipManual++
			continue
		}

		// Spread tax across existing expenses proportionally to their amount.
		remaining := round2(tax)
		updates := make([]struct {
			id        int64
			newAmount float64
			newUnit   float64
		}, len(exps))
		for j, e := range exps {
			share := round2(tax * e.amount / subtotal)
			if j == len(exps)-1 {
				share = remaining
			}
			remaining = round2(remaining - share)
			na := round2(e.amount + share)
			nu := na
			if e.qty > 0 {
				nu = na / e.qty
			}
			updates[j].id = e.id
			updates[j].newAmount = na
			updates[j].newUnit = nu
		}

		fmt.Printf("FIX: adding $%.2f tax across %d item(s)\n", tax, len(exps))
		for j, u := range updates {
			fmt.Printf("    expense %d: $%.2f -> $%.2f\n", u.id, exps[j].amount, u.newAmount)
		}

		if *apply {
			tx, err := db.Begin()
			if err != nil {
				fmt.Println("    ERROR begin tx:", err)
				errs++
				continue
			}
			ok := true
			for _, u := range updates {
				if _, err := tx.Exec(`UPDATE expenses SET amount=$1, unit_price=$2 WHERE id=$3`,
					u.newAmount, u.newUnit, u.id); err != nil {
					fmt.Println("    ERROR update:", err)
					ok = false
					break
				}
			}
			if ok {
				if err := tx.Commit(); err != nil {
					fmt.Println("    ERROR commit:", err)
					errs++
					continue
				}
			} else {
				tx.Rollback()
				errs++
				continue
			}
		}
		fixed++
		time.Sleep(300 * time.Millisecond) // be gentle with the API
	}

	fmt.Printf("\n=== summary ===\n")
	fmt.Printf("fixed:                %d\n", fixed)
	fmt.Printf("skipped (has tax):    %d\n", skipAlready)
	fmt.Printf("skipped (no tax):     %d\n", skipNoTax)
	fmt.Printf("skipped (manual):     %d\n", skipManual)
	fmt.Printf("errors:               %d\n", errs)
	if !*apply && fixed > 0 {
		fmt.Printf("\nThis was a DRY RUN — re-run with --apply to write the %d fix(es) above.\n", fixed)
	}
}

// rescan sends the stored receipt image to Claude and returns the sales tax and
// the pre-tax subtotal (sum of item amounts).
func rescan(img []byte, mime string, year int, make, model string) (tax, subtotal float64, err error) {
	switch mime {
	case "image/jpeg", "image/png", "image/webp":
	default:
		mime = http.DetectContentType(img)
	}

	prompt := fmt.Sprintf(`You are extracting expense line items from a photo of a receipt for a car-flipping business (this receipt is for a %d %s %s).

Respond with ONLY a JSON object — no markdown, no code fences, no explanation. Use this exact structure:
{
  "tax": <number, total sales tax charged on the receipt, 0 if none>,
  "items": [
    { "amount": <number, pre-tax line total> }
  ]
}

Rules:
- Include one entry per distinct part or service line — most receipts have several.
- Tax, subtotal, and total lines are not items. Report the sales tax total in "tax" (sum multiple tax lines if present).
- Item amounts must be pre-tax.
- Pick categories closest match; if a field is illegible, make a reasonable best guess.`,
		year, make, model)

	content := []map[string]interface{}{
		{"type": "image", "source": map[string]interface{}{
			"type": "base64", "media_type": mime,
			"data": base64.StdEncoding.EncodeToString(img),
		}},
		{"type": "text", "text": prompt},
	}
	text, err := callClaude(content, 2048)
	if err != nil {
		return 0, 0, err
	}
	var parsed struct {
		Tax   float64 `json:"tax"`
		Items []struct {
			Amount float64 `json:"amount"`
		} `json:"items"`
	}
	if err := json.Unmarshal([]byte(text), &parsed); err != nil {
		return 0, 0, fmt.Errorf("parse failed: %v (raw: %.120s)", err, text)
	}
	for _, it := range parsed.Items {
		subtotal += it.Amount
	}
	return round2(parsed.Tax), round2(subtotal), nil
}

func callClaude(content []map[string]interface{}, maxTokens int) (string, error) {
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	reqBody, _ := json.Marshal(map[string]interface{}{
		"model": claudeModel, "max_tokens": maxTokens,
		"messages": []map[string]interface{}{{"role": "user", "content": content}},
	})
	req, _ := http.NewRequest("POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(reqBody))
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	var cr struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&cr)
	if cr.Error != nil {
		return "", fmt.Errorf("%s", cr.Error.Message)
	}
	if len(cr.Content) == 0 {
		return "", fmt.Errorf("empty response from Claude")
	}
	text := strings.TrimSpace(cr.Content[0].Text)
	if strings.HasPrefix(text, "```") {
		text = strings.TrimPrefix(text, "```json")
		text = strings.TrimPrefix(text, "```")
		if idx := strings.LastIndex(text, "```"); idx != -1 {
			text = text[:idx]
		}
		text = strings.TrimSpace(text)
	}
	return text, nil
}
