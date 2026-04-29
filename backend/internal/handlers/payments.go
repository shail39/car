package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

func ListPayments(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	rows, err := db.DB.Query(`
		SELECT id, car_id, payment_type, paid_by, amount, COALESCE(notes,'')
		FROM car_payments WHERE car_id=$1 ORDER BY payment_type, id`, carID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()
	var out []models.CarPayment
	for rows.Next() {
		p := models.CarPayment{}
		rows.Scan(&p.ID, &p.CarID, &p.PaymentType, &p.PaidBy, &p.Amount, &p.Notes)
		out = append(out, p)
	}
	json.NewEncoder(w).Encode(out)
}

func AddPayment(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	var p models.CarPayment
	json.NewDecoder(r.Body).Decode(&p)
	p.CarID = carID
	err := db.DB.QueryRow(`
		INSERT INTO car_payments(car_id, payment_type, paid_by, amount, notes)
		VALUES($1,$2,$3,$4,$5) RETURNING id`,
		p.CarID, p.PaymentType, p.PaidBy, p.Amount, p.Notes).Scan(&p.ID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(p)
}

func UpdatePayment(w http.ResponseWriter, r *http.Request) {
	pid, _ := strconv.ParseInt(mux.Vars(r)["pid"], 10, 64)
	var p models.CarPayment
	json.NewDecoder(r.Body).Decode(&p)
	db.DB.Exec(`UPDATE car_payments SET paid_by=$1, amount=$2, notes=$3 WHERE id=$4`,
		p.PaidBy, p.Amount, p.Notes, pid)
	p.ID = pid
	json.NewEncoder(w).Encode(p)
}

func DeletePayment(w http.ResponseWriter, r *http.Request) {
	pid, _ := strconv.ParseInt(mux.Vars(r)["pid"], 10, 64)
	db.DB.Exec(`DELETE FROM car_payments WHERE id=$1`, pid)
	w.WriteHeader(http.StatusNoContent)
}

// BulkSetPayments replaces all payments of a given type for a car (used by auto-settle)
func BulkSetPayments(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	paymentType := mux.Vars(r)["type"]
	var payments []models.CarPayment
	json.NewDecoder(r.Body).Decode(&payments)

	tx, err := db.DB.Begin()
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	tx.Exec(`DELETE FROM car_payments WHERE car_id=$1 AND payment_type=$2`, carID, paymentType)
	for _, p := range payments {
		tx.Exec(`INSERT INTO car_payments(car_id,payment_type,paid_by,amount,notes) VALUES($1,$2,$3,$4,$5)`,
			carID, paymentType, p.PaidBy, p.Amount, p.Notes)
	}
	if err := tx.Commit(); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func carPaymentsList(carID int64) []models.CarPayment {
	rows, _ := db.DB.Query(`
		SELECT id, car_id, payment_type, paid_by, amount, COALESCE(notes,'')
		FROM car_payments WHERE car_id=$1 ORDER BY payment_type, id`, carID)
	defer rows.Close()
	var out []models.CarPayment
	for rows.Next() {
		p := models.CarPayment{}
		rows.Scan(&p.ID, &p.CarID, &p.PaymentType, &p.PaidBy, &p.Amount, &p.Notes)
		out = append(out, p)
	}
	return out
}
