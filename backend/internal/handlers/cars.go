package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

func ListCars(w http.ResponseWriter, r *http.Request) {
	rows, err := db.DB.Query(`
		SELECT id, make, model, year, COALESCE(vin,''), COALESCE(auction_name,''),
		       COALESCE(purchase_date,''), purchase_price, auction_fees, transport_cost,
		       COALESCE(paid_by_purchase,''), COALESCE(paid_by_transport,''),
		       status, sale_price, COALESCE(notes,''), COALESCE(created_at::text,''), market_price
		FROM cars ORDER BY id DESC`)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()

	cars := []models.Car{}
	for rows.Next() {
		c := models.Car{}
		rows.Scan(&c.ID, &c.Make, &c.Model, &c.Year, &c.VIN, &c.AuctionName,
			&c.PurchaseDate, &c.PurchasePrice, &c.AuctionFees, &c.TransportCost,
			&c.PaidByPurchase, &c.PaidByTransport,
			&c.Status, &c.SalePrice, &c.Notes, &c.CreatedAt, &c.MarketPrice)
		c.TotalExpenses = totalExpenses(c.ID)
		c.TotalCost = c.PurchasePrice + c.AuctionFees + c.TransportCost + c.TotalExpenses
		if c.SalePrice != nil {
			p := *c.SalePrice - c.TotalCost
			c.Profit = &p
		}
		c.Partners = carPartners(c.ID)
		cars = append(cars, c)
	}
	json.NewEncoder(w).Encode(cars)
}

func GetCar(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	c := models.Car{}
	err := db.DB.QueryRow(`
		SELECT id, make, model, year, COALESCE(vin,''), COALESCE(auction_name,''),
		       COALESCE(purchase_date,''), purchase_price, auction_fees, transport_cost,
		       COALESCE(paid_by_purchase,''), COALESCE(paid_by_transport,''),
		       status, sale_price, COALESCE(notes,''), COALESCE(created_at::text,''), market_price
		FROM cars WHERE id=$1`, id).
		Scan(&c.ID, &c.Make, &c.Model, &c.Year, &c.VIN, &c.AuctionName,
			&c.PurchaseDate, &c.PurchasePrice, &c.AuctionFees, &c.TransportCost,
			&c.PaidByPurchase, &c.PaidByTransport,
			&c.Status, &c.SalePrice, &c.Notes, &c.CreatedAt, &c.MarketPrice)
	if err == sql.ErrNoRows {
		http.NotFound(w, r)
		return
	}
	c.TotalExpenses = totalExpenses(c.ID)
	c.TotalCost = c.PurchasePrice + c.AuctionFees + c.TransportCost + c.TotalExpenses
	if c.SalePrice != nil {
		p := *c.SalePrice - c.TotalCost
		c.Profit = &p
	}
	c.Partners = carPartners(c.ID)
	c.Expenses = carExpenses(c.ID)
	c.Payments = carPaymentsList(c.ID)
	json.NewEncoder(w).Encode(c)
}

func CreateCar(w http.ResponseWriter, r *http.Request) {
	var c models.Car
	json.NewDecoder(r.Body).Decode(&c)
	if c.Status == "" {
		c.Status = "purchased"
	}
	err := db.DB.QueryRow(`
		INSERT INTO cars(make,model,year,vin,auction_name,purchase_date,purchase_price,
		                 auction_fees,transport_cost,paid_by_purchase,paid_by_transport,
		                 status,sale_price,notes,market_price)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING id`,
		c.Make, c.Model, c.Year, c.VIN, c.AuctionName, c.PurchaseDate,
		c.PurchasePrice, c.AuctionFees, c.TransportCost,
		c.PaidByPurchase, c.PaidByTransport,
		c.Status, c.SalePrice, c.Notes, c.MarketPrice).Scan(&c.ID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(c)
}

func UpdateCar(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	var c models.Car
	json.NewDecoder(r.Body).Decode(&c)
	_, err := db.DB.Exec(`
		UPDATE cars SET make=$1,model=$2,year=$3,vin=$4,auction_name=$5,purchase_date=$6,
		purchase_price=$7,auction_fees=$8,transport_cost=$9,
		paid_by_purchase=$10,paid_by_transport=$11,
		status=$12,sale_price=$13,notes=$14,market_price=$15
		WHERE id=$16`,
		c.Make, c.Model, c.Year, c.VIN, c.AuctionName, c.PurchaseDate,
		c.PurchasePrice, c.AuctionFees, c.TransportCost,
		c.PaidByPurchase, c.PaidByTransport,
		c.Status, c.SalePrice, c.Notes, c.MarketPrice, id)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	c.ID = id
	json.NewEncoder(w).Encode(c)
}

func DeleteCar(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	db.DB.Exec(`DELETE FROM cars WHERE id=$1`, id)
	w.WriteHeader(http.StatusNoContent)
}

func totalExpenses(carID int64) float64 {
	var total float64
	db.DB.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM expenses WHERE car_id=$1`, carID).Scan(&total)
	return total
}

func carPartners(carID int64) []models.CarPartner {
	rows, _ := db.DB.Query(`
		SELECT cp.id, cp.car_id, cp.partner_id, cp.share_pct, p.name, COALESCE(p.phone,''), COALESCE(p.email,'')
		FROM car_partners cp JOIN partners p ON p.id=cp.partner_id
		WHERE cp.car_id=$1`, carID)
	defer rows.Close()
	var out []models.CarPartner
	for rows.Next() {
		cp := models.CarPartner{Partner: &models.Partner{}}
		rows.Scan(&cp.ID, &cp.CarID, &cp.PartnerID, &cp.SharePct,
			&cp.Partner.Name, &cp.Partner.Phone, &cp.Partner.Email)
		cp.Partner.ID = cp.PartnerID
		out = append(out, cp)
	}
	return out
}

func carExpenses(carID int64) []models.Expense {
	rows, _ := db.DB.Query(`
		SELECT id, car_id, category, COALESCE(description,''), amount,
		       COALESCE(paid_by,''), COALESCE(expense_date,''), COALESCE(part_number,''),
		       quantity, unit_price, COALESCE(created_at::text,'')
		FROM expenses WHERE car_id=$1 ORDER BY id DESC`, carID)
	defer rows.Close()
	var out []models.Expense
	for rows.Next() {
		e := models.Expense{}
		rows.Scan(&e.ID, &e.CarID, &e.Category, &e.Description, &e.Amount,
			&e.PaidBy, &e.ExpenseDate, &e.PartNumber, &e.Quantity, &e.UnitPrice, &e.CreatedAt)
		out = append(out, e)
	}
	return out
}
