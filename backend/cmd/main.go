package main

import (
	"log"
	"net/http"
	"os"

	"carmanager/internal/db"
	"carmanager/internal/handlers"

	"github.com/gorilla/mux"
	"github.com/rs/cors"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://coownerly:coownerly_dev_password@localhost:5432/wrenchlogs?sslmode=disable"
	}
	db.Init(dsn)

	r := mux.NewRouter()
	r.Use(jsonMiddleware)

	api := r.PathPrefix("/api").Subrouter()

	api.HandleFunc("/dashboard", handlers.Dashboard).Methods("GET")
	api.HandleFunc("/insights", handlers.Insights).Methods("GET")

	api.HandleFunc("/cars", handlers.ListCars).Methods("GET")
	api.HandleFunc("/cars", handlers.CreateCar).Methods("POST")
	api.HandleFunc("/cars/{id:[0-9]+}", handlers.GetCar).Methods("GET")
	api.HandleFunc("/cars/{id:[0-9]+}", handlers.UpdateCar).Methods("PUT")
	api.HandleFunc("/cars/{id:[0-9]+}", handlers.DeleteCar).Methods("DELETE")

	api.HandleFunc("/cars/{id:[0-9]+}/expenses", handlers.ListExpenses).Methods("GET")
	api.HandleFunc("/cars/{id:[0-9]+}/expenses", handlers.CreateExpense).Methods("POST")
	api.HandleFunc("/cars/{id:[0-9]+}/expenses/{eid:[0-9]+}", handlers.UpdateExpense).Methods("PUT")
	api.HandleFunc("/cars/{id:[0-9]+}/expenses/{eid:[0-9]+}", handlers.DeleteExpense).Methods("DELETE")

	api.HandleFunc("/cars/{id:[0-9]+}/partners", handlers.AddCarPartner).Methods("POST")
	api.HandleFunc("/cars/{id:[0-9]+}/partners/{cpid:[0-9]+}", handlers.RemoveCarPartner).Methods("DELETE")

	api.HandleFunc("/cars/{id:[0-9]+}/payments", handlers.ListPayments).Methods("GET")
	api.HandleFunc("/cars/{id:[0-9]+}/payments", handlers.AddPayment).Methods("POST")
	api.HandleFunc("/cars/{id:[0-9]+}/payments/{pid:[0-9]+}", handlers.UpdatePayment).Methods("PUT")
	api.HandleFunc("/cars/{id:[0-9]+}/payments/{pid:[0-9]+}", handlers.DeletePayment).Methods("DELETE")
	api.HandleFunc("/cars/{id:[0-9]+}/payments/bulk/{type}", handlers.BulkSetPayments).Methods("POST")
	api.HandleFunc("/cars/{id:[0-9]+}/analyze", handlers.AnalyzeCar).Methods("POST")

	api.HandleFunc("/partners", handlers.ListPartners).Methods("GET")
	api.HandleFunc("/partners", handlers.CreatePartner).Methods("POST")
	api.HandleFunc("/partners/{id:[0-9]+}", handlers.UpdatePartner).Methods("PUT")
	api.HandleFunc("/partners/{id:[0-9]+}", handlers.DeletePartner).Methods("DELETE")

	c := cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Content-Type"},
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server running on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, c.Handler(r)))
}

func jsonMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		next.ServeHTTP(w, r)
	})
}
