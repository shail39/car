package models

type Car struct {
	ID              int64    `json:"id"`
	Make            string   `json:"make"`
	Model           string   `json:"model"`
	Year            int      `json:"year"`
	VIN             string   `json:"vin"`
	AuctionName     string   `json:"auction_name"`
	PurchaseDate    string   `json:"purchase_date"`
	PurchasePrice   float64  `json:"purchase_price"`
	AuctionFees     float64  `json:"auction_fees"`
	TransportCost   float64  `json:"transport_cost"`
	PaidByPurchase  string   `json:"paid_by_purchase"`
	PaidByTransport string   `json:"paid_by_transport"`
	Status          string   `json:"status"`
	SalePrice       *float64 `json:"sale_price"`
	Notes           string   `json:"notes"`
	CreatedAt       string   `json:"created_at"`

	MarketPrice   *float64     `json:"market_price"`

	TotalExpenses float64      `json:"total_expenses"`
	TotalCost     float64      `json:"total_cost"`
	Profit        *float64     `json:"profit"`
	Partners      []CarPartner `json:"partners"`
	Expenses      []Expense    `json:"expenses"`
	Payments      []CarPayment `json:"payments"`
}

func (c Car) DisplayName() string {
	return c.Make + " " + c.Model
}

type Partner struct {
	ID    int64  `json:"id"`
	Name  string `json:"name"`
	Phone string `json:"phone"`
	Email string `json:"email"`
}

type CarPartner struct {
	ID        int64    `json:"id"`
	CarID     int64    `json:"car_id"`
	PartnerID int64    `json:"partner_id"`
	SharePct  float64  `json:"share_pct"`
	Partner   *Partner `json:"partner,omitempty"`
}

type Expense struct {
	ID          int64   `json:"id"`
	CarID       int64   `json:"car_id"`
	Category    string  `json:"category"`
	Description string  `json:"description"`
	Amount      float64 `json:"amount"`
	PaidBy      string  `json:"paid_by"`
	ExpenseDate string  `json:"expense_date"`
	PartNumber  string  `json:"part_number"`
	Quantity    float64 `json:"quantity"`
	UnitPrice   float64 `json:"unit_price"`
	CreatedAt   string  `json:"created_at"`
}

type CarPayment struct {
	ID          int64   `json:"id"`
	CarID       int64   `json:"car_id"`
	PaymentType string  `json:"payment_type"` // "purchase" | "transport"
	PaidBy      string  `json:"paid_by"`
	Amount      float64 `json:"amount"`
	Notes       string  `json:"notes"`
}

type PartnerBalance struct {
	Partner   string  `json:"partner"`
	TotalPaid float64 `json:"total_paid"`
	TotalOwed float64 `json:"total_owed"`
	Net       float64 `json:"net"` // positive = others owe them, negative = they owe others
}

type Settlement struct {
	From   string  `json:"from"`
	To     string  `json:"to"`
	Amount float64 `json:"amount"`
}

type CarInsight struct {
	CarID       int64             `json:"car_id"`
	CarName     string            `json:"car_name"`
	Status      string            `json:"status"`
	TotalCost   float64           `json:"total_cost"`
	SalePrice   *float64          `json:"sale_price"`
	Profit      *float64          `json:"profit"`
	Breakdown   []PartnerCarShare `json:"breakdown"`
	Settlements []Settlement      `json:"settlements"`
}

type PartnerCarShare struct {
	Partner string  `json:"partner"`
	Paid    float64 `json:"paid"`
	Owed    float64 `json:"owed"`
	Net     float64 `json:"net"`
}

type AnalysisResult struct {
	MarketValueLow      float64  `json:"market_value_low"`
	MarketValueHigh     float64  `json:"market_value_high"`
	RecommendedPrice    float64  `json:"recommended_price"`
	ProfitPotentialLow  float64  `json:"profit_potential_low"`
	ProfitPotentialHigh float64  `json:"profit_potential_high"`
	DealRating          string   `json:"deal_rating"`
	Tips                []string `json:"tips"`
	Summary             string   `json:"summary"`
}

type Insights struct {
	PartnerBalances []PartnerBalance `json:"partner_balances"`
	Settlements     []Settlement     `json:"settlements"`
	CarInsights     []CarInsight     `json:"car_insights"`
}
