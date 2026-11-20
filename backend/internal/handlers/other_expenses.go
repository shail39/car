package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

func ListOtherExpenses(w http.ResponseWriter, r *http.Request) {
	rows, err := db.DB.Query(`
		SELECT id, category, COALESCE(description,''), amount,
		       COALESCE(paid_by,''), COALESCE(expense_date,''), COALESCE(created_at::text,'')
		FROM other_expenses ORDER BY expense_date DESC, id DESC`)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()
	out := []models.OtherExpense{}
	for rows.Next() {
		e := models.OtherExpense{}
		rows.Scan(&e.ID, &e.Category, &e.Description, &e.Amount, &e.PaidBy, &e.ExpenseDate, &e.CreatedAt)
		out = append(out, e)
	}
	json.NewEncoder(w).Encode(out)
}

func CreateOtherExpense(w http.ResponseWriter, r *http.Request) {
	var e models.OtherExpense
	json.NewDecoder(r.Body).Decode(&e)
	err := db.DB.QueryRow(`
		INSERT INTO other_expenses(category,description,amount,paid_by,expense_date)
		VALUES($1,$2,$3,$4,$5) RETURNING id`,
		e.Category, e.Description, e.Amount, e.PaidBy, e.ExpenseDate).Scan(&e.ID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(e)
}

func UpdateOtherExpense(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	var e models.OtherExpense
	json.NewDecoder(r.Body).Decode(&e)
	db.DB.Exec(`UPDATE other_expenses SET category=$1,description=$2,amount=$3,paid_by=$4,expense_date=$5 WHERE id=$6`,
		e.Category, e.Description, e.Amount, e.PaidBy, e.ExpenseDate, id)
	e.ID = id
	json.NewEncoder(w).Encode(e)
}

func DeleteOtherExpense(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	db.DB.Exec(`DELETE FROM other_expenses WHERE id=$1`, id)
	w.WriteHeader(http.StatusNoContent)
}
