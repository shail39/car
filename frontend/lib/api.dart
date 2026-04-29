import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

const _base = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8083/api');

class Api {
  static Future<DashboardStats> getDashboard() async {
    final r = await http.get(Uri.parse('$_base/dashboard'));
    return DashboardStats.fromJson(jsonDecode(r.body));
  }

  static Future<List<Car>> getCars() async {
    final r = await http.get(Uri.parse('$_base/cars'));
    final list = jsonDecode(r.body) as List? ?? [];
    return list.map((e) => Car.fromJson(e)).toList();
  }

  static Future<Car> getCar(int id) async {
    final r = await http.get(Uri.parse('$_base/cars/$id'));
    return Car.fromJson(jsonDecode(r.body));
  }

  static Future<Car> createCar(Car car) async {
    final r = await http.post(Uri.parse('$_base/cars'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(car.toJson()));
    return Car.fromJson(jsonDecode(r.body));
  }

  static Future<void> updateCar(int id, Car car) async {
    await http.put(Uri.parse('$_base/cars/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(car.toJson()));
  }

  static Future<void> deleteCar(int id) async {
    await http.delete(Uri.parse('$_base/cars/$id'));
  }

  static Future<List<Partner>> getPartners() async {
    final r = await http.get(Uri.parse('$_base/partners'));
    final list = jsonDecode(r.body) as List? ?? [];
    return list.map((e) => Partner.fromJson(e)).toList();
  }

  static Future<Partner> createPartner(Partner p) async {
    final r = await http.post(Uri.parse('$_base/partners'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(p.toJson()));
    return Partner.fromJson(jsonDecode(r.body));
  }

  static Future<void> updatePartner(int id, Partner p) async {
    await http.put(Uri.parse('$_base/partners/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(p.toJson()));
  }

  static Future<void> deletePartner(int id) async {
    await http.delete(Uri.parse('$_base/partners/$id'));
  }

  static Future<void> addCarPartner(int carId, CarPartner cp) async {
    await http.post(Uri.parse('$_base/cars/$carId/partners'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cp.toJson()));
  }

  static Future<void> removeCarPartner(int carId, int cpId) async {
    await http.delete(Uri.parse('$_base/cars/$carId/partners/$cpId'));
  }

  static Future<Expense> createExpense(int carId, Expense e) async {
    final r = await http.post(Uri.parse('$_base/cars/$carId/expenses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(e.toJson()));
    return Expense.fromJson(jsonDecode(r.body));
  }

  static Future<void> updateExpense(int carId, int eid, Expense e) async {
    await http.put(Uri.parse('$_base/cars/$carId/expenses/$eid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(e.toJson()));
  }

  static Future<void> deleteExpense(int carId, int eid) async {
    await http.delete(Uri.parse('$_base/cars/$carId/expenses/$eid'));
  }

  static Future<Insights> getInsights() async {
    final r = await http.get(Uri.parse('$_base/insights'));
    return Insights.fromJson(jsonDecode(r.body));
  }

  static Future<List<CarPayment>> getPayments(int carId) async {
    final r = await http.get(Uri.parse('$_base/cars/$carId/payments'));
    final list = jsonDecode(r.body) as List? ?? [];
    return list.map((e) => CarPayment.fromJson(e)).toList();
  }

  static Future<CarPayment> addPayment(int carId, CarPayment p) async {
    final r = await http.post(Uri.parse('$_base/cars/$carId/payments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(p.toJson()));
    return CarPayment.fromJson(jsonDecode(r.body));
  }

  static Future<void> updatePayment(int carId, int pid, CarPayment p) async {
    await http.put(Uri.parse('$_base/cars/$carId/payments/$pid'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(p.toJson()));
  }

  static Future<void> deletePayment(int carId, int pid) async {
    await http.delete(Uri.parse('$_base/cars/$carId/payments/$pid'));
  }

  static Future<AnalysisResult> analyzeCar(int carId) async {
    final r = await http.post(Uri.parse('$_base/cars/$carId/analyze'),
        headers: {'Content-Type': 'application/json'});
    return AnalysisResult.fromJson(jsonDecode(r.body));
  }

  static Future<void> bulkSetPayments(int carId, String type, List<CarPayment> payments) async {
    await http.post(Uri.parse('$_base/cars/$carId/payments/bulk/$type'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payments.map((p) => p.toJson()).toList()));
  }
}
