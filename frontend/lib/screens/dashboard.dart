import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  Insights? _insights;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([Api.getDashboard(), Api.getInsights()]);
    setState(() {
      _stats = results[0] as DashboardStats;
      _insights = results[1] as Insights;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final s = _stats!;
    final ins = _insights!;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // ── Summary stats ──
          Wrap(spacing: 16, runSpacing: 16, children: [
            _StatCard('Total Cars', '${s.totalCars}', Icons.directions_car, Colors.blue),
            _StatCard('Active', '${s.activeCars}', Icons.build, Colors.orange),
            _StatCard('Sold', '${s.soldCars}', Icons.sell, Colors.green),
            _StatCard('Total Invested', fmtMoney(s.totalInvested), Icons.attach_money, Colors.purple),
            _StatCard('Total Repairs', fmtMoney(s.totalRepairs), Icons.build_circle, Colors.red),
            _StatCard('Total Profit', fmtMoney(s.totalProfit), Icons.trending_up,
                s.totalProfit >= 0 ? Colors.green : Colors.red),
          ]),
          const SizedBox(height: 32),

          // ── Who Owes Whom ──
          if (ins.settlements.isNotEmpty) ...[
            _sectionHeader(context, 'Who Owes Whom', Icons.account_balance_wallet),
            const SizedBox(height: 12),
            ...ins.settlements.map((s) => _SettlementCard(s)),
            const SizedBox(height: 32),
          ],

          // ── Partner Balances ──
          if (ins.partnerBalances.isNotEmpty) ...[
            _sectionHeader(context, 'Partner Balances', Icons.people),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (_, c) => c.maxWidth < 600
                ? Column(children: ins.partnerBalances
                    .map((b) => SizedBox(width: double.infinity, child: _PartnerBalanceCard(b)))
                    .toList())
                : Wrap(spacing: 16, runSpacing: 16,
                    children: ins.partnerBalances.map((b) => _PartnerBalanceCard(b)).toList())),
            const SizedBox(height: 32),
          ],

          // ── Per-car breakdown ──
          if (ins.carInsights.isNotEmpty) ...[
            _sectionHeader(context, 'Per Car Breakdown', Icons.bar_chart),
            const SizedBox(height: 12),
            ...ins.carInsights.map((ci) => _CarInsightCard(ci)),
            const SizedBox(height: 32),
          ],
        ]),
      ),
    );
  }

  Widget _sectionHeader(BuildContext ctx, String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: Theme.of(ctx).colorScheme.primary),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = screenW < 600 ? (screenW - 56) / 2 : 180.0;
    return SizedBox(
      width: cardW,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final Settlement s;
  const _SettlementCard(this.s);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          const Icon(Icons.arrow_forward, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                children: [
                  TextSpan(text: s.from, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  const TextSpan(text: ' owes '),
                  TextSpan(text: s.to, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
          ),
          Text(fmtMoney(s.amount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
        ]),
      ),
    );
  }
}

class _PartnerBalanceCard extends StatelessWidget {
  final PartnerBalance b;
  const _PartnerBalanceCard(this.b);

  @override
  Widget build(BuildContext context) {
    final isPositive = b.net >= 0;
    final netColor = isPositive ? Colors.green : Colors.red;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 18, child: Text(b.partner[0].toUpperCase())),
              const SizedBox(width: 10),
              Expanded(child: Text(b.partner, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            ]),
            const SizedBox(height: 14),
            _row('Paid Out', fmtMoney(b.totalPaid), Colors.blue),
            _row('Should Pay', fmtMoney(b.totalOwed), Colors.grey),
            const Divider(height: 20),
            _row(isPositive ? 'Others owe' : 'Owes', fmtMoney(b.net.abs()), netColor, bold: true),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Text(value, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }
}

class _CarInsightCard extends StatelessWidget {
  final CarInsight ci;
  const _CarInsightCard(this.ci);

  @override
  Widget build(BuildContext context) {
    final statusColor = {
      'purchased': Colors.blue, 'in_repair': Colors.orange,
      'ready': Colors.teal, 'for_sale': Colors.purple, 'sold': Colors.green,
    }[ci.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(ci.carName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(kStatusLabels[ci.status] ?? ci.status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (ci.breakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5)},
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[100]),
                  children: ['Partner', 'Paid', 'Should Pay', 'Balance']
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          ))
                      .toList(),
                ),
                ...ci.breakdown.map((p) {
                  final netColor = p.net >= 0 ? Colors.green : Colors.red;
                  return TableRow(children: [
                    _cell(p.partner, bold: true),
                    _cell(fmtMoney(p.paid), color: Colors.blue),
                    _cell(fmtMoney(p.owed), color: Colors.grey),
                    _cell('${p.net >= 0 ? '+' : ''}${fmtMoney(p.net)}', color: netColor, bold: true),
                  ]);
                }),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Widget _cell(String text, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
    );
  }
}
