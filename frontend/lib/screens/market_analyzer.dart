import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';

class MarketAnalyzerScreen extends StatefulWidget {
  const MarketAnalyzerScreen({super.key});

  @override
  State<MarketAnalyzerScreen> createState() => _MarketAnalyzerScreenState();
}

class _MarketAnalyzerScreenState extends State<MarketAnalyzerScreen> {
  List<Car> _cars = [];
  bool _loading = true;
  final Map<int, AnalysisResult?> _results = {};
  final Map<int, bool> _analyzing = {};
  final Map<int, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cars = await Api.getCars();
    setState(() {
      _cars = cars.where((c) => c.status != 'sold').toList();
      _loading = false;
    });
  }

  Future<void> _analyze(Car car) async {
    setState(() {
      _analyzing[car.id!] = true;
      _errors[car.id!] = null;
    });
    try {
      final result = await Api.analyzeCar(car.id!);
      setState(() {
        _results[car.id!] = result;
        _analyzing[car.id!] = false;
      });
    } catch (e) {
      setState(() {
        _errors[car.id!] = e.toString();
        _analyzing[car.id!] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Analyzer'),
        automaticallyImplyLeading: false,
      ),
      body: _cars.isEmpty
          ? const Center(child: Text('No active cars to analyze.', style: TextStyle(color: Colors.grey)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI-powered market analysis for your active inventory',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  ..._cars.map((car) => _CarAnalysisCard(
                        car: car,
                        result: _results[car.id],
                        analyzing: _analyzing[car.id] == true,
                        error: _errors[car.id],
                        onAnalyze: () => _analyze(car),
                      )),
                ],
              ),
            ),
    );
  }
}

class _CarAnalysisCard extends StatelessWidget {
  final Car car;
  final AnalysisResult? result;
  final bool analyzing;
  final String? error;
  final VoidCallback onAnalyze;

  const _CarAnalysisCard({
    required this.car,
    required this.result,
    required this.analyzing,
    required this.error,
    required this.onAnalyze,
  });

  Color get _ratingColor {
    switch (result?.dealRating) {
      case 'Excellent': return const Color(0xFF2E7D32);
      case 'Good': return const Color(0xFF1565C0);
      case 'Fair': return Colors.orange.shade700;
      case 'Poor': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = result != null;
    final potLow = hasResult ? result!.profitPotentialLow : 0.0;
    final potHigh = hasResult ? result!.profitPotentialHigh : 0.0;
    final avgPotential = (potLow + potHigh) / 2;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(car.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Cost basis: ${fmtMoney(car.totalCost)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ]),
            ),
            if (hasResult) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _ratingColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _ratingColor.withValues(alpha: 0.4)),
                ),
                child: Text(result!.dealRating,
                    style: TextStyle(color: _ratingColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
            ],
            FilledButton.icon(
              onPressed: analyzing ? null : onAnalyze,
              icon: analyzing
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(analyzing ? 'Analyzing…' : hasResult ? 'Re-analyze' : 'Analyze'),
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ]),

          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],

          if (hasResult) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Market value + potential row
            Row(children: [
              _StatBox(
                label: 'Market Value Range',
                value: '${fmtMoney(result!.marketValueLow)} – ${fmtMoney(result!.marketValueHigh)}',
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'Recommended Price',
                value: fmtMoney(result!.recommendedPrice),
                color: const Color(0xFF1565C0),
                highlight: true,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'Potential Profit',
                value: '${avgPotential >= 0 ? '+' : ''}${fmtMoney(avgPotential)}',
                color: avgPotential >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
            ]),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(result!.summary,
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 12),

            // Tips
            Text('Selling Tips', style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            ...result!.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
              ]),
            )),
          ],
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: highlight ? color.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ]),
      ),
    );
  }
}
