package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

func AnalyzeCar(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)

	var c models.Car
	err := db.DB.QueryRow(`
		SELECT id, make, model, year, status, purchase_price, auction_fees,
		       transport_cost, COALESCE(notes,'')
		FROM cars WHERE id=$1`, id).
		Scan(&c.ID, &c.Make, &c.Model, &c.Year, &c.Status,
			&c.PurchasePrice, &c.AuctionFees, &c.TransportCost, &c.Notes)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	c.TotalExpenses = totalExpenses(c.ID)
	c.TotalCost = c.PurchasePrice + c.AuctionFees + c.TransportCost + c.TotalExpenses

	expSummary := expenseSummary(c.ID)

	prompt := fmt.Sprintf(`You are a used car market expert in the USA. Analyze this car for resale potential.

Car: %d %s %s
Purchase Price: $%.0f
Auction Fees: $%.0f
Transport Cost: $%.0f
Repair Expenses: %s
Total Cost Basis: $%.0f
Status: %s
Notes: %s

Respond with ONLY a JSON object — no markdown, no code fences, no explanation. Use this exact structure:
{
  "market_value_low": <number>,
  "market_value_high": <number>,
  "recommended_price": <number>,
  "profit_potential_low": <number>,
  "profit_potential_high": <number>,
  "deal_rating": "<Excellent|Good|Fair|Poor>",
  "tips": ["<tip1>", "<tip2>", "<tip3>"],
  "summary": "<2-3 sentence market summary>"
}`,
		c.Year, c.Make, c.Model,
		c.PurchasePrice, c.AuctionFees, c.TransportCost,
		expSummary, c.TotalCost, c.Status, c.Notes)

	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		http.Error(w, `{"error":"ANTHROPIC_API_KEY not configured"}`, 500)
		return
	}

	reqBody, _ := json.Marshal(map[string]interface{}{
		"model":      "claude-haiku-4-5-20251001",
		"max_tokens": 1024,
		"messages": []map[string]string{
			{"role": "user", "content": prompt},
		},
	})

	req, _ := http.NewRequest("POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(reqBody))
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("content-type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, `{"error":"failed to reach Anthropic API"}`, 502)
		return
	}
	defer resp.Body.Close()

	var claudeResp struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&claudeResp)

	if claudeResp.Error != nil {
		http.Error(w, fmt.Sprintf(`{"error":%q}`, claudeResp.Error.Message), 502)
		return
	}
	if len(claudeResp.Content) == 0 {
		http.Error(w, `{"error":"empty response from Claude"}`, 500)
		return
	}

	text := strings.TrimSpace(claudeResp.Content[0].Text)
	var result models.AnalysisResult
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"parse failed: %s","raw":%q}`, err, text), 500)
		return
	}

	// Persist the recommended market price back to the car
	db.DB.Exec(`UPDATE cars SET market_price=$1 WHERE id=$2`, result.RecommendedPrice, id)

	json.NewEncoder(w).Encode(result)
}

func expenseSummary(carID int64) string {
	rows, err := db.DB.Query(`
		SELECT category, SUM(amount) FROM expenses WHERE car_id=$1 GROUP BY category`, carID)
	if err != nil {
		return "none"
	}
	defer rows.Close()
	var parts []string
	for rows.Next() {
		var cat string
		var amt float64
		rows.Scan(&cat, &amt)
		parts = append(parts, fmt.Sprintf("%s: $%.0f", cat, amt))
	}
	if len(parts) == 0 {
		return "none"
	}
	return strings.Join(parts, ", ")
}
