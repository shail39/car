package handlers

import (
	"encoding/json"
	"math"
	"net/http"

	"carmanager/internal/db"
	"carmanager/internal/models"
)

func Insights(w http.ResponseWriter, r *http.Request) {
	cars := loadAllCars()

	paid := map[string]float64{}
	owed := map[string]float64{}

	var carInsights []models.CarInsight

	for _, c := range cars {
		if len(c.Partners) == 0 {
			continue
		}
		totalCost := c.PurchasePrice + c.AuctionFees + c.TransportCost + c.TotalExpenses

		carPaid := map[string]float64{}

		// Use car_payments table (multi-payer support)
		for _, p := range c.Payments {
			if p.PaidBy != "" {
				carPaid[p.PaidBy] += p.Amount
			}
		}
		// Fallback: legacy single paid_by fields if no car_payments recorded
		if len(c.Payments) == 0 {
			if c.PaidByPurchase != "" {
				carPaid[c.PaidByPurchase] += c.PurchasePrice + c.AuctionFees
			}
			if c.PaidByTransport != "" {
				carPaid[c.PaidByTransport] += c.TransportCost
			}
		}
		// Repair expenses paid by
		for _, e := range c.Expenses {
			if e.PaidBy != "" {
				carPaid[e.PaidBy] += e.Amount
			}
		}

		carOwed := map[string]float64{}
		for _, cp := range c.Partners {
			name := cp.Partner.Name
			carOwed[name] = totalCost * cp.SharePct / 100
		}

		for name, amt := range carPaid {
			paid[name] += amt
		}
		for name, amt := range carOwed {
			owed[name] += amt
		}

		names := map[string]bool{}
		for n := range carPaid {
			names[n] = true
		}
		for n := range carOwed {
			names[n] = true
		}
		var breakdown []models.PartnerCarShare
		for name := range names {
			p := carPaid[name]
			o := carOwed[name]
			breakdown = append(breakdown, models.PartnerCarShare{
				Partner: name, Paid: p, Owed: o, Net: p - o,
			})
		}

		carInsights = append(carInsights, models.CarInsight{
			CarID: c.ID, CarName: c.DisplayName(), Status: c.Status, Breakdown: breakdown,
		})
	}

	allNames := map[string]bool{}
	for n := range paid {
		allNames[n] = true
	}
	for n := range owed {
		allNames[n] = true
	}
	var balances []models.PartnerBalance
	for name := range allNames {
		balances = append(balances, models.PartnerBalance{
			Partner: name, TotalPaid: paid[name], TotalOwed: owed[name], Net: paid[name] - owed[name],
		})
	}

	json.NewEncoder(w).Encode(models.Insights{
		PartnerBalances: balances,
		Settlements:     computeSettlements(balances),
		CarInsights:     carInsights,
	})
}

func computeSettlements(balances []models.PartnerBalance) []models.Settlement {
	type entry struct {
		name string
		amt  float64
	}
	var creditors, debtors []entry
	for _, b := range balances {
		if b.Net > 0.01 {
			creditors = append(creditors, entry{b.Partner, b.Net})
		} else if b.Net < -0.01 {
			debtors = append(debtors, entry{b.Partner, -b.Net})
		}
	}
	var settlements []models.Settlement
	ci, di := 0, 0
	for ci < len(creditors) && di < len(debtors) {
		c := &creditors[ci]
		d := &debtors[di]
		amount := math.Round(math.Min(c.amt, d.amt)*100) / 100
		if amount > 0 {
			settlements = append(settlements, models.Settlement{From: d.name, To: c.name, Amount: amount})
		}
		c.amt -= amount
		d.amt -= amount
		if c.amt < 0.01 {
			ci++
		}
		if d.amt < 0.01 {
			di++
		}
	}
	return settlements
}

func loadAllCars() []models.Car {
	rows, err := db.DB.Query(`
		SELECT id, make, model, year, COALESCE(paid_by_purchase,''), COALESCE(paid_by_transport,''),
		       purchase_price, auction_fees, transport_cost, status, sale_price
		FROM cars ORDER BY id`)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var cars []models.Car
	for rows.Next() {
		c := models.Car{}
		rows.Scan(&c.ID, &c.Make, &c.Model, &c.Year,
			&c.PaidByPurchase, &c.PaidByTransport,
			&c.PurchasePrice, &c.AuctionFees, &c.TransportCost,
			&c.Status, &c.SalePrice)
		c.TotalExpenses = totalExpenses(c.ID)
		c.Partners = carPartners(c.ID)
		c.Expenses = carExpenses(c.ID)
		c.Payments = carPaymentsList(c.ID)
		cars = append(cars, c)
	}
	return cars
}
