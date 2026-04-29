package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"carmanager/internal/db"
	"carmanager/internal/models"

	"github.com/gorilla/mux"
)

func ListPartners(w http.ResponseWriter, r *http.Request) {
	rows, err := db.DB.Query(`SELECT id, name, COALESCE(phone,''), COALESCE(email,'') FROM partners ORDER BY name`)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()
	var out []models.Partner
	for rows.Next() {
		p := models.Partner{}
		rows.Scan(&p.ID, &p.Name, &p.Phone, &p.Email)
		out = append(out, p)
	}
	json.NewEncoder(w).Encode(out)
}

func CreatePartner(w http.ResponseWriter, r *http.Request) {
	var p models.Partner
	json.NewDecoder(r.Body).Decode(&p)
	err := db.DB.QueryRow(`INSERT INTO partners(name,phone,email) VALUES($1,$2,$3) RETURNING id`,
		p.Name, p.Phone, p.Email).Scan(&p.ID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(p)
}

func UpdatePartner(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	var p models.Partner
	json.NewDecoder(r.Body).Decode(&p)
	db.DB.Exec(`UPDATE partners SET name=$1,phone=$2,email=$3 WHERE id=$4`, p.Name, p.Phone, p.Email, id)
	p.ID = id
	json.NewEncoder(w).Encode(p)
}

func DeletePartner(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	db.DB.Exec(`DELETE FROM partners WHERE id=$1`, id)
	w.WriteHeader(http.StatusNoContent)
}

func AddCarPartner(w http.ResponseWriter, r *http.Request) {
	carID, _ := strconv.ParseInt(mux.Vars(r)["id"], 10, 64)
	var cp models.CarPartner
	json.NewDecoder(r.Body).Decode(&cp)
	cp.CarID = carID
	err := db.DB.QueryRow(`INSERT INTO car_partners(car_id,partner_id,share_pct) VALUES($1,$2,$3) RETURNING id`,
		cp.CarID, cp.PartnerID, cp.SharePct).Scan(&cp.ID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(cp)
}

func RemoveCarPartner(w http.ResponseWriter, r *http.Request) {
	cpID, _ := strconv.ParseInt(mux.Vars(r)["cpid"], 10, 64)
	db.DB.Exec(`DELETE FROM car_partners WHERE id=$1`, cpID)
	w.WriteHeader(http.StatusNoContent)
}
