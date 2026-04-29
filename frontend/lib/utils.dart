import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _decimal = NumberFormat('#,##0.00');

String fmtMoney(double v) => _currency.format(v);
String fmtDecimal(double v) => _decimal.format(v);

Color profitColor(double? profit) {
  if (profit == null) return const Color(0xFF757575);
  return profit >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
}

const kStatuses = ['purchased', 'in_repair', 'ready', 'for_sale', 'sold'];
const kStatusLabels = {
  'purchased': 'Purchased',
  'in_repair': 'In Repair',
  'ready': 'Ready',
  'for_sale': 'For Sale',
  'sold': 'Sold',
};

const kCategories = [
  'Engine', 'Transmission', 'Brakes', 'Suspension', 'Electrical',
  'Body/Paint', 'Tires', 'Interior', 'AC/Heat', 'Transport',
  'Storage', 'Inspection', 'Other'
];
