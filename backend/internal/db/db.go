package db

import (
	"database/sql"
	"log"

	_ "github.com/lib/pq"
)

var DB *sql.DB

func Init(dsn string) {
	var err error
	DB, err = sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	if err = DB.Ping(); err != nil {
		log.Fatal("db ping:", err)
	}
	migrate()
}

func migrate() {
	_, err := DB.Exec(`
	CREATE TABLE IF NOT EXISTS cars (
		id BIGSERIAL PRIMARY KEY,
		make TEXT NOT NULL,
		model TEXT NOT NULL,
		year INTEGER NOT NULL,
		vin TEXT DEFAULT '',
		auction_name TEXT DEFAULT '',
		purchase_date TEXT DEFAULT '',
		purchase_price NUMERIC NOT NULL DEFAULT 0,
		auction_fees NUMERIC NOT NULL DEFAULT 0,
		transport_cost NUMERIC NOT NULL DEFAULT 0,
		paid_by_purchase TEXT DEFAULT '',
		paid_by_transport TEXT DEFAULT '',
		status TEXT NOT NULL DEFAULT 'purchased',
		sale_price NUMERIC,
		notes TEXT DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW()
	);

	ALTER TABLE cars ADD COLUMN IF NOT EXISTS paid_by_purchase TEXT DEFAULT '';
	ALTER TABLE cars ADD COLUMN IF NOT EXISTS paid_by_transport TEXT DEFAULT '';
	ALTER TABLE cars ADD COLUMN IF NOT EXISTS market_price NUMERIC;
	ALTER TABLE expenses ADD COLUMN IF NOT EXISTS part_number TEXT DEFAULT '';
	ALTER TABLE expenses ADD COLUMN IF NOT EXISTS quantity NUMERIC NOT NULL DEFAULT 1;
	ALTER TABLE expenses ADD COLUMN IF NOT EXISTS unit_price NUMERIC NOT NULL DEFAULT 0;

	CREATE TABLE IF NOT EXISTS partners (
		id BIGSERIAL PRIMARY KEY,
		name TEXT NOT NULL UNIQUE,
		phone TEXT DEFAULT '',
		email TEXT DEFAULT ''
	);

	CREATE TABLE IF NOT EXISTS car_partners (
		id BIGSERIAL PRIMARY KEY,
		car_id BIGINT NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
		partner_id BIGINT NOT NULL REFERENCES partners(id),
		share_pct NUMERIC NOT NULL DEFAULT 50
	);

	CREATE TABLE IF NOT EXISTS expenses (
		id BIGSERIAL PRIMARY KEY,
		car_id BIGINT NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
		category TEXT NOT NULL,
		description TEXT DEFAULT '',
		amount NUMERIC NOT NULL DEFAULT 0,
		paid_by TEXT DEFAULT '',
		expense_date TEXT DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS car_payments (
		id BIGSERIAL PRIMARY KEY,
		car_id BIGINT NOT NULL REFERENCES cars(id) ON DELETE CASCADE,
		payment_type TEXT NOT NULL DEFAULT 'purchase',
		paid_by TEXT NOT NULL,
		amount NUMERIC NOT NULL DEFAULT 0,
		notes TEXT DEFAULT ''
	);
	`)
	if err != nil {
		log.Fatal("migrate:", err)
	}
}
