package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

func ListExpenses(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	rows, err := db.DB.Query(`
		SELECT id, car_id, category, COALESCE(description,''), amount,
		       COALESCE(paid_by,''), COALESCE(expense_date,''), COALESCE(part_number,''),
		       quantity, unit_price, COALESCE(created_at::text,'')
		FROM expenses WHERE car_id=$1 ORDER BY id DESC`, carID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()
	var out []models.Expense
	for rows.Next() {
		e := models.Expense{}
		rows.Scan(&e.ID, &e.CarID, &e.Category, &e.Description, &e.Amount,
			&e.PaidBy, &e.ExpenseDate, &e.PartNumber, &e.Quantity, &e.UnitPrice, &e.CreatedAt)
		out = append(out, e)
	}
	json.NewEncoder(w).Encode(out)
}

func CreateExpense(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	var e models.Expense
	json.NewDecoder(r.Body).Decode(&e)
	e.CarID = carID
	err := db.DB.QueryRow(`
		INSERT INTO expenses(car_id,category,description,amount,paid_by,expense_date,part_number,quantity,unit_price)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
		e.CarID, e.Category, e.Description, e.Amount, e.PaidBy, e.ExpenseDate,
		e.PartNumber, e.Quantity, e.UnitPrice).Scan(&e.ID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(e)
}

func UpdateExpense(w http.ResponseWriter, r *http.Request) {
	eid, _ := strconv.ParseInt(mux.Vars(r)["eid"], 10, 64)
	var e models.Expense
	json.NewDecoder(r.Body).Decode(&e)
	db.DB.Exec(`UPDATE expenses SET category=$1,description=$2,amount=$3,paid_by=$4,expense_date=$5,part_number=$6,quantity=$7,unit_price=$8 WHERE id=$9`,
		e.Category, e.Description, e.Amount, e.PaidBy, e.ExpenseDate, e.PartNumber, e.Quantity, e.UnitPrice, eid)
	e.ID = eid
	json.NewEncoder(w).Encode(e)
}

func DeleteExpense(w http.ResponseWriter, r *http.Request) {
	eid, _ := strconv.ParseInt(mux.Vars(r)["eid"], 10, 64)
	db.DB.Exec(`DELETE FROM expenses WHERE id=$1`, eid)
	w.WriteHeader(http.StatusNoContent)
}

func Dashboard(w http.ResponseWriter, r *http.Request) {
	type Stats struct {
		TotalCars      int     `json:"total_cars"`
		ActiveCars     int     `json:"active_cars"`
		SoldCars       int     `json:"sold_cars"`
		TotalInvested  float64 `json:"total_invested"`
		TotalRepairs   float64 `json:"total_repairs"`
		TotalProfit    float64 `json:"total_profit"`
		PendingRepairs float64 `json:"pending_repairs"`
	}
	var s Stats
	db.DB.QueryRow(`SELECT COUNT(*) FROM cars`).Scan(&s.TotalCars)
	db.DB.QueryRow(`SELECT COUNT(*) FROM cars WHERE status='sold'`).Scan(&s.SoldCars)
	s.ActiveCars = s.TotalCars - s.SoldCars
	db.DB.QueryRow(`SELECT COALESCE(SUM(purchase_price+auction_fees+transport_cost),0) FROM cars`).Scan(&s.TotalInvested)
	db.DB.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM expenses`).Scan(&s.TotalRepairs)
	db.DB.QueryRow(`
		SELECT COALESCE(SUM(c.sale_price - (c.purchase_price+c.auction_fees+c.transport_cost+COALESCE(e.exp,0))),0)
		FROM cars c
		LEFT JOIN (SELECT car_id, SUM(amount) exp FROM expenses GROUP BY car_id) e ON e.car_id=c.id
		WHERE c.status='sold' AND c.sale_price IS NOT NULL`).Scan(&s.TotalProfit)
	db.DB.QueryRow(`
		SELECT COALESCE(SUM(e.amount),0) FROM expenses e
		JOIN cars c ON c.id=e.car_id WHERE c.status != 'sold'`).Scan(&s.PendingRepairs)
	json.NewEncoder(w).Encode(s)
}
