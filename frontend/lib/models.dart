class Car {
  final int? id;
  final String make;
  final String model;
  final int year;
  final String vin;
  final String auctionName;
  final String purchaseDate;
  final double purchasePrice;
  final double auctionFees;
  final double transportCost;
  final String paidByPurchase;
  final String paidByTransport;
  final String status;
  final double? salePrice;
  final String notes;
  final double totalExpenses;
  final double totalCost;
  final double? profit;
  final double? marketPrice;
  final List<CarPartner> partners;
  final List<Expense> expenses;
  final List<CarPayment> payments;

  Car({
    this.id,
    required this.make,
    required this.model,
    required this.year,
    this.vin = '',
    this.auctionName = '',
    this.purchaseDate = '',
    required this.purchasePrice,
    this.auctionFees = 0,
    this.transportCost = 0,
    this.paidByPurchase = '',
    this.paidByTransport = '',
    this.status = 'purchased',
    this.salePrice,
    this.notes = '',
    this.totalExpenses = 0,
    this.totalCost = 0,
    this.profit,
    this.marketPrice,
    this.partners = const [],
    this.expenses = const [],
    this.payments = const [],
  });

  factory Car.fromJson(Map<String, dynamic> j) => Car(
        id: j['id'],
        make: j['make'] ?? '',
        model: j['model'] ?? '',
        year: j['year'] ?? 0,
        vin: j['vin'] ?? '',
        auctionName: j['auction_name'] ?? '',
        purchaseDate: j['purchase_date'] ?? '',
        purchasePrice: (j['purchase_price'] ?? 0).toDouble(),
        auctionFees: (j['auction_fees'] ?? 0).toDouble(),
        transportCost: (j['transport_cost'] ?? 0).toDouble(),
        paidByPurchase: j['paid_by_purchase'] ?? '',
        paidByTransport: j['paid_by_transport'] ?? '',
        status: j['status'] ?? 'purchased',
        salePrice: j['sale_price']?.toDouble(),
        notes: j['notes'] ?? '',
        totalExpenses: (j['total_expenses'] ?? 0).toDouble(),
        totalCost: (j['total_cost'] ?? 0).toDouble(),
        profit: j['profit']?.toDouble(),
        marketPrice: j['market_price']?.toDouble(),
        partners: (j['partners'] as List? ?? []).map((e) => CarPartner.fromJson(e)).toList(),
        expenses: (j['expenses'] as List? ?? []).map((e) => Expense.fromJson(e)).toList(),
        payments: (j['payments'] as List? ?? []).map((e) => CarPayment.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'year': year,
        'vin': vin,
        'auction_name': auctionName,
        'purchase_date': purchaseDate,
        'purchase_price': purchasePrice,
        'auction_fees': auctionFees,
        'transport_cost': transportCost,
        'paid_by_purchase': paidByPurchase,
        'paid_by_transport': paidByTransport,
        'status': status,
        'sale_price': salePrice,
        'notes': notes,
        'market_price': marketPrice,
      };

  String get displayName => '$year $make $model';
}

class Partner {
  final int? id;
  final String name;
  final String phone;
  final String email;

  Partner({this.id, required this.name, this.phone = '', this.email = ''});

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
        id: j['id'],
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'email': email};
}

class CarPartner {
  final int? id;
  final int carId;
  final int partnerId;
  final double sharePct;
  final Partner? partner;

  CarPartner({this.id, required this.carId, required this.partnerId, this.sharePct = 50, this.partner});

  factory CarPartner.fromJson(Map<String, dynamic> j) => CarPartner(
        id: j['id'],
        carId: j['car_id'] ?? 0,
        partnerId: j['partner_id'] ?? 0,
        sharePct: (j['share_pct'] ?? 50).toDouble(),
        partner: j['partner'] != null ? Partner.fromJson(j['partner']) : null,
      );

  Map<String, dynamic> toJson() => {'partner_id': partnerId, 'share_pct': sharePct};
}

class Expense {
  final int? id;
  final int carId;
  final String category;
  final String description;
  final double amount;
  final String paidBy;
  final String expenseDate;
  final String partNumber;
  final double quantity;
  final double unitPrice;

  Expense({
    this.id,
    required this.carId,
    required this.category,
    this.description = '',
    required this.amount,
    this.paidBy = '',
    this.expenseDate = '',
    this.partNumber = '',
    this.quantity = 1,
    this.unitPrice = 0,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'],
        carId: j['car_id'] ?? 0,
        category: j['category'] ?? '',
        description: j['description'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
        paidBy: j['paid_by'] ?? '',
        expenseDate: j['expense_date'] ?? '',
        partNumber: j['part_number'] ?? '',
        quantity: (j['quantity'] ?? 1).toDouble(),
        unitPrice: (j['unit_price'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'amount': amount,
        'paid_by': paidBy,
        'expense_date': expenseDate,
        'part_number': partNumber,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

class CarPayment {
  final int? id;
  final int carId;
  final String paymentType; // 'purchase' | 'transport'
  final String paidBy;
  final double amount;
  final String notes;

  CarPayment({
    this.id,
    required this.carId,
    required this.paymentType,
    required this.paidBy,
    required this.amount,
    this.notes = '',
  });

  factory CarPayment.fromJson(Map<String, dynamic> j) => CarPayment(
        id: j['id'],
        carId: j['car_id'] ?? 0,
        paymentType: j['payment_type'] ?? 'purchase',
        paidBy: j['paid_by'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
        notes: j['notes'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'payment_type': paymentType,
        'paid_by': paidBy,
        'amount': amount,
        'notes': notes,
      };

  CarPayment copyWith({String? paidBy, double? amount, String? notes}) => CarPayment(
        id: id,
        carId: carId,
        paymentType: paymentType,
        paidBy: paidBy ?? this.paidBy,
        amount: amount ?? this.amount,
        notes: notes ?? this.notes,
      );
}

class AnalysisResult {
  final double marketValueLow;
  final double marketValueHigh;
  final double recommendedPrice;
  final double profitPotentialLow;
  final double profitPotentialHigh;
  final String dealRating;
  final List<String> tips;
  final String summary;

  AnalysisResult({
    required this.marketValueLow,
    required this.marketValueHigh,
    required this.recommendedPrice,
    required this.profitPotentialLow,
    required this.profitPotentialHigh,
    required this.dealRating,
    required this.tips,
    required this.summary,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) => AnalysisResult(
        marketValueLow: (j['market_value_low'] ?? 0).toDouble(),
        marketValueHigh: (j['market_value_high'] ?? 0).toDouble(),
        recommendedPrice: (j['recommended_price'] ?? 0).toDouble(),
        profitPotentialLow: (j['profit_potential_low'] ?? 0).toDouble(),
        profitPotentialHigh: (j['profit_potential_high'] ?? 0).toDouble(),
        dealRating: j['deal_rating'] ?? '',
        tips: (j['tips'] as List? ?? []).map((e) => e.toString()).toList(),
        summary: j['summary'] ?? '',
      );
}

class DashboardStats {
  final int totalCars;
  final int activeCars;
  final int soldCars;
  final double totalInvested;
  final double totalRepairs;
  final double totalProfit;
  final double pendingRepairs;

  DashboardStats({
    this.totalCars = 0,
    this.activeCars = 0,
    this.soldCars = 0,
    this.totalInvested = 0,
    this.totalRepairs = 0,
    this.totalProfit = 0,
    this.pendingRepairs = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalCars: j['total_cars'] ?? 0,
        activeCars: j['active_cars'] ?? 0,
        soldCars: j['sold_cars'] ?? 0,
        totalInvested: (j['total_invested'] ?? 0).toDouble(),
        totalRepairs: (j['total_repairs'] ?? 0).toDouble(),
        totalProfit: (j['total_profit'] ?? 0).toDouble(),
        pendingRepairs: (j['pending_repairs'] ?? 0).toDouble(),
      );
}

class PartnerBalance {
  final String partner;
  final double totalPaid;
  final double totalOwed;
  final double net;

  PartnerBalance({required this.partner, required this.totalPaid, required this.totalOwed, required this.net});

  factory PartnerBalance.fromJson(Map<String, dynamic> j) => PartnerBalance(
        partner: j['partner'] ?? '',
        totalPaid: (j['total_paid'] ?? 0).toDouble(),
        totalOwed: (j['total_owed'] ?? 0).toDouble(),
        net: (j['net'] ?? 0).toDouble(),
      );
}

class Settlement {
  final String from;
  final String to;
  final double amount;

  Settlement({required this.from, required this.to, required this.amount});

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        from: j['from'] ?? '',
        to: j['to'] ?? '',
        amount: (j['amount'] ?? 0).toDouble(),
      );
}

class PartnerCarShare {
  final String partner;
  final double paid;
  final double owed;
  final double net;

  PartnerCarShare({required this.partner, required this.paid, required this.owed, required this.net});

  factory PartnerCarShare.fromJson(Map<String, dynamic> j) => PartnerCarShare(
        partner: j['partner'] ?? '',
        paid: (j['paid'] ?? 0).toDouble(),
        owed: (j['owed'] ?? 0).toDouble(),
        net: (j['net'] ?? 0).toDouble(),
      );
}

class CarInsight {
  final int carId;
  final String carName;
  final String status;
  final double totalCost;
  final double? salePrice;
  final double? profit;
  final List<PartnerCarShare> breakdown;
  final List<Settlement> settlements;

  CarInsight({
    required this.carId,
    required this.carName,
    required this.status,
    this.totalCost = 0,
    this.salePrice,
    this.profit,
    required this.breakdown,
    this.settlements = const [],
  });

  factory CarInsight.fromJson(Map<String, dynamic> j) => CarInsight(
        carId: j['car_id'] ?? 0,
        carName: j['car_name'] ?? '',
        status: j['status'] ?? '',
        totalCost: (j['total_cost'] ?? 0).toDouble(),
        salePrice: j['sale_price']?.toDouble(),
        profit: j['profit']?.toDouble(),
        breakdown: (j['breakdown'] as List? ?? []).map((e) => PartnerCarShare.fromJson(e)).toList(),
        settlements: (j['settlements'] as List? ?? []).map((e) => Settlement.fromJson(e)).toList(),
      );
}

class Insights {
  final List<PartnerBalance> partnerBalances;
  final List<Settlement> settlements;
  final List<CarInsight> carInsights;

  Insights({required this.partnerBalances, required this.settlements, required this.carInsights});

  factory Insights.fromJson(Map<String, dynamic> j) => Insights(
        partnerBalances: (j['partner_balances'] as List? ?? []).map((e) => PartnerBalance.fromJson(e)).toList(),
        settlements: (j['settlements'] as List? ?? []).map((e) => Settlement.fromJson(e)).toList(),
        carInsights: (j['car_insights'] as List? ?? []).map((e) => CarInsight.fromJson(e)).toList(),
      );
}
