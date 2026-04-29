import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/payment_split.dart';
import 'car_form.dart';


class CarDetailScreen extends StatefulWidget {
  final int carId;
  const CarDetailScreen({super.key, required this.carId});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  Car? _car;
  List<Partner> _allPartners = [];
  bool _loading = true;
  AnalysisResult? _analysis;
  bool _analyzing = false;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([Api.getCar(widget.carId), Api.getPartners()]);
    setState(() {
      _car = results[0] as Car;
      _allPartners = results[1] as List<Partner>;
      _loading = false;
    });
  }

  Future<void> _runAnalysis() async {
    setState(() { _analyzing = true; _analysisError = null; });
    try {
      final r = await Api.analyzeCar(widget.carId);
      setState(() { _analysis = r; _analyzing = false; });
    } catch (e) {
      setState(() { _analysisError = e.toString(); _analyzing = false; });
    }
  }

  Future<void> _editCar() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CarFormScreen(car: _car)));
    if (result == true) _load();
  }

  Future<void> _addExpense() async {
    await _showExpenseDialog(null);
  }

  Future<void> _editExpense(Expense e) async {
    await _showExpenseDialog(e);
  }

  Future<void> _showExpenseDialog(Expense? expense) async {
    // Build partner name list from the car's partners
    final partnerNames = _car!.partners
        .map((cp) => cp.partner?.name ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    await showDialog(
      context: context,
      builder: (_) => _ExpenseDialog(
        expense: expense,
        carId: widget.carId,
        partnerNames: partnerNames,
        onSave: (e2) async {
          if (expense == null) {
            await Api.createExpense(widget.carId, e2);
          } else {
            await Api.updateExpense(widget.carId, expense.id!, e2);
          }
          _load();
        },
      ),
    );
  }

  Future<void> _deleteExpense(Expense e) async {
    await Api.deleteExpense(widget.carId, e.id!);
    _load();
  }

  Future<void> _addPartner() async {
    final existing = _car!.partners.map((p) => p.partnerId).toSet();
    final available = _allPartners.where((p) => !existing.contains(p.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All partners already added to this car')));
      return;
    }

    Partner? selected = available.first;
    final pctCtrl = TextEditingController(text: '50');

    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Add Partner'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        StatefulBuilder(builder: (_, ss) => DropdownButtonFormField<Partner>(
          value: selected,
          decoration: const InputDecoration(labelText: 'Partner', border: OutlineInputBorder()),
          items: available.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
          onChanged: (v) => ss(() => selected = v),
        )),
        const SizedBox(height: 12),
        TextField(controller: pctCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Share %', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          await Api.addCarPartner(widget.carId, CarPartner(
            carId: widget.carId,
            partnerId: selected!.id!,
            sharePct: double.tryParse(pctCtrl.text) ?? 50,
          ));
          if (mounted) Navigator.pop(context);
          _load();
        }, child: const Text('Add')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final car = _car!;

    return Scaffold(
      appBar: AppBar(
        title: Text(car.displayName),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editCar),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final leftCol = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionCard(title: 'Overview', child: Column(children: [
            _InfoRow('Status', kStatusLabels[car.status] ?? car.status),
            _InfoRow('Auction', car.auctionName.isNotEmpty ? car.auctionName : '-'),
            _InfoRow('Purchase Date', car.purchaseDate.isNotEmpty ? car.purchaseDate : '-'),
            _InfoRow('VIN', car.vin.isNotEmpty ? car.vin : '-'),
            if (car.notes.isNotEmpty) _InfoRow('Notes', car.notes),
          ])),
          const SizedBox(height: 16),
          _SectionCard(title: 'Financial Summary', child: Column(children: [
            _InfoRow('Purchase Price', fmtMoney(car.purchasePrice)),
            _InfoRow('Auction Fees', fmtMoney(car.auctionFees)),
            _InfoRow('Transport', fmtMoney(car.transportCost)),
            _InfoRow('Repairs', fmtMoney(car.totalExpenses)),
            const Divider(),
            _InfoRow('Total Cost', fmtMoney(car.totalCost), bold: true),
            if (car.salePrice != null) _InfoRow('Sale Price', fmtMoney(car.salePrice!), bold: true),
            if (car.profit != null) _InfoRow('Profit / Loss', fmtMoney(car.profit!), bold: true, valueColor: profitColor(car.profit)),
          ])),
          const SizedBox(height: 16),
          _MarketAnalysisCard(
            car: car,
            result: _analysis,
            analyzing: _analyzing,
            error: _analysisError,
            onAnalyze: _runAnalysis,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Payment Tracking',
            child: _PaymentTrackingSection(car: car, onChanged: _load),
          ),
          if (car.status == 'sold' && car.salePrice != null) ...[
            const SizedBox(height: 16),
            _PnLSection(car: car),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Partners',
            action: TextButton.icon(onPressed: _addPartner, icon: const Icon(Icons.add), label: const Text('Add')),
            child: car.partners.isEmpty
                ? const Text('No partners yet', style: TextStyle(color: Colors.grey))
                : Column(children: car.partners.map((cp) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(cp.partner?.name ?? 'Unknown'),
                    subtitle: Text('Share: ${cp.sharePct.toStringAsFixed(1)}%'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () async { await Api.removeCarPartner(widget.carId, cp.id!); _load(); },
                    ),
                  )).toList()),
          ),
        ]);

        final expenseCol = _SectionCard(
          title: 'Repair & Expenses',
          action: FilledButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text('Add Expense')),
          child: car.expenses.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No expenses yet', style: TextStyle(color: Colors.grey))))
              : _ExpenseTable(car.expenses, onEdit: _editExpense, onDelete: _deleteExpense),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: leftCol),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: expenseCol),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  leftCol,
                  const SizedBox(height: 16),
                  expenseCol,
                ]),
        );
      }),
    );
  }
}

class _ExpenseTable extends StatelessWidget {
  final List<Expense> expenses;
  final Function(Expense) onEdit;
  final Function(Expense) onDelete;
  const _ExpenseTable(this.expenses, {required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, double>{};
    for (final e in expenses) {
      grouped[e.category] = (grouped[e.category] ?? 0) + e.amount;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: grouped.entries.map((e) => Chip(
        label: Text('${e.key}: ${fmtMoney(e.value)}', style: const TextStyle(fontSize: 12)),
      )).toList()),
      const SizedBox(height: 16),
      ...expenses.map((e) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(radius: 18, child: Text(e.category[0], style: const TextStyle(fontSize: 12))),
          title: Row(children: [
            Text(e.category, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (e.description.isNotEmpty) Text(' — ${e.description}', style: const TextStyle(color: Colors.grey)),
          ]),
          subtitle: Text([
            e.expenseDate.isNotEmpty ? e.expenseDate : '—',
            'Paid by: ${e.paidBy.isNotEmpty ? e.paidBy : '—'}',
            if (e.partNumber.isNotEmpty) 'Part#: ${e.partNumber}',
            if (e.quantity > 1) '${e.quantity.toStringAsFixed(e.quantity == e.quantity.roundToDouble() ? 0 : 1)}× @ ${fmtMoney(e.unitPrice)}',
          ].join(' · ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(fmtMoney(e.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => onEdit(e)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => onDelete(e)),
          ]),
        ),
      )),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
            if (action != null) action!,
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final String? sub;
  const _InfoRow(this.label, this.value, {this.bold = false, this.valueColor, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          if (sub != null) Text(sub!, style: const TextStyle(color: Colors.blue, fontSize: 11)),
        ])),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: valueColor)),
      ]),
    );
  }
}

// ── Expense Dialog ────────────────────────────────────────────────────────────
class _ExpenseDialog extends StatefulWidget {
  final Expense? expense;
  final int carId;
  final List<String> partnerNames;
  final Future<void> Function(Expense) onSave;

  const _ExpenseDialog({
    required this.expense,
    required this.carId,
    required this.partnerNames,
    required this.onSave,
  });

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  late String _category;
  late String? _paidBy;
  late String _date;
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _partCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _category = e?.category ?? kCategories.first;
    _descCtrl.text = e?.description ?? '';
    _amtCtrl.text = e?.amount != null && e!.amount > 0 ? e.amount.toStringAsFixed(2) : '';
    _partCtrl.text = e?.partNumber ?? '';
    _qtyCtrl.text = (e?.quantity != null && e!.quantity != 1) ? e.quantity.toString() : '1';
    _unitCtrl.text = (e?.unitPrice != null && e!.unitPrice > 0) ? e.unitPrice.toStringAsFixed(2) : '';
    _date = e?.expenseDate ?? '';
    final name = e?.paidBy ?? '';
    _paidBy = widget.partnerNames.contains(name) ? name : null;
    _qtyCtrl.addListener(_recalc);
    _unitCtrl.addListener(_recalc);
  }

  void _recalc() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final unit = double.tryParse(_unitCtrl.text) ?? 0;
    if (qty > 0 && unit > 0) {
      _amtCtrl.text = (qty * unit).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    _partCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try {
      initial = _date.isNotEmpty ? DateTime.parse(_date) : DateTime.now();
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final unit = double.tryParse(_unitCtrl.text) ?? 0;
    final amount = double.tryParse(_amtCtrl.text) ?? 0;
    final e2 = Expense(
      carId: widget.carId,
      category: _category,
      description: _descCtrl.text.trim(),
      amount: amount,
      paidBy: _paidBy ?? '',
      expenseDate: _date,
      partNumber: _partCtrl.text.trim(),
      quantity: qty,
      unitPrice: unit > 0 ? unit : (qty > 0 ? amount / qty : 0),
    );
    await widget.onSave(e2);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            // Part Number
            TextField(
              controller: _partCtrl,
              decoration: const InputDecoration(
                labelText: 'Part Number (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            // Quantity × Unit Price
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _unitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                    isDense: true,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Amount
            TextField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount', prefixText: '\$ ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            // Paid By — partner dropdown
            if (widget.partnerNames.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _paidBy,
                decoration: const InputDecoration(
                    labelText: 'Paid By', border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline)),
                hint: const Text('Select partner'),
                items: [
                  ...widget.partnerNames.map((n) => DropdownMenuItem(value: n, child: Text(n))),
                  const DropdownMenuItem(value: '__other__', child: Text('Other / External')),
                ],
                onChanged: (v) => setState(() => _paidBy = v == '__other__' ? '' : v),
              )
            else
              TextField(
                onChanged: (v) => _paidBy = v,
                decoration: const InputDecoration(
                    labelText: 'Paid By', border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline)),
              ),
            const SizedBox(height: 12),

            // Date — calendar picker
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(
                  _date.isNotEmpty ? _date : 'Tap to select date',
                  style: TextStyle(
                      color: _date.isNotEmpty ? Colors.black87 : Colors.grey),
                ),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(widget.expense == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}

class _PaymentTrackingSection extends StatefulWidget {
  final Car car;
  final VoidCallback onChanged;
  const _PaymentTrackingSection({required this.car, required this.onChanged});

  @override
  State<_PaymentTrackingSection> createState() => _PaymentTrackingSectionState();
}

class _PaymentTrackingSectionState extends State<_PaymentTrackingSection> {
  late List<CarPayment> _purchasePayments;
  late List<CarPayment> _transportPayments;

  @override
  void initState() {
    super.initState();
    _purchasePayments = widget.car.payments.where((p) => p.paymentType == 'purchase').toList();
    _transportPayments = widget.car.payments.where((p) => p.paymentType == 'transport').toList();
  }

  Future<void> _save(String type, List<CarPayment> payments) async {
    await Api.bulkSetPayments(widget.car.id!, type, payments);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final purchaseTotal = widget.car.purchasePrice + widget.car.auctionFees;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (purchaseTotal > 0) ...[
        PaymentSplitWidget(
          title: 'Purchase + Fees',
          paymentType: 'purchase',
          totalAmount: purchaseTotal,
          partners: widget.car.partners,
          initialPayments: _purchasePayments,
          carId: widget.car.id!,
          onChanged: (p) {
            setState(() => _purchasePayments = p);
            _save('purchase', p);
          },
        ),
      ],
      if (widget.car.transportCost > 0)
        PaymentSplitWidget(
          title: 'Transport',
          paymentType: 'transport',
          totalAmount: widget.car.transportCost,
          partners: widget.car.partners,
          initialPayments: _transportPayments,
          carId: widget.car.id!,
          onChanged: (p) {
            setState(() => _transportPayments = p);
            _save('transport', p);
          },
        ),
      if (purchaseTotal == 0 && widget.car.transportCost == 0)
        const Text('No purchase or transport amounts recorded.',
            style: TextStyle(color: Colors.grey)),
    ]);
  }
}

class _PnLSection extends StatelessWidget {
  final Car car;
  const _PnLSection({required this.car});

  /// Amount each partner actually paid (from car_payments + expenses)
  Map<String, double> _paidByPartner() {
    final paid = <String, double>{};
    for (final p in car.payments) {
      if (p.paidBy.isNotEmpty) paid[p.paidBy] = (paid[p.paidBy] ?? 0) + p.amount;
    }
    for (final e in car.expenses) {
      if (e.paidBy.isNotEmpty) paid[e.paidBy] = (paid[e.paidBy] ?? 0) + e.amount;
    }
    return paid;
  }

  @override
  Widget build(BuildContext context) {
    final salePrice = car.salePrice!;
    final totalCost = car.totalCost;
    final netProfit = salePrice - totalCost;
    final isProfit = netProfit >= 0;
    final profitColor = isProfit ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final paid = _paidByPartner();

    return Card(
      color: isProfit ? const Color(0xFFF1F8E9) : const Color(0xFFFFF8F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: profitColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isProfit ? Icons.trending_up : Icons.trending_down, color: profitColor),
            const SizedBox(width: 8),
            Text('Sale & Profit / Loss',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: profitColor)),
          ]),
          const SizedBox(height: 16),

          // Summary row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              _SummaryCol('Sale Price', fmtMoney(salePrice), Colors.blue),
              _vDivider(),
              _SummaryCol('Total Cost', fmtMoney(totalCost), Colors.grey),
              _vDivider(),
              _SummaryCol(isProfit ? 'Net Profit' : 'Net Loss',
                  fmtMoney(netProfit.abs()), profitColor, large: true),
            ]),
          ),
          const SizedBox(height: 20),

          if (car.partners.isNotEmpty) ...[
            Text('Partner Payouts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.8),
              },
              children: [
                _headerRow(['Partner', 'Share', 'Paid In', 'Revenue', isProfit ? 'Profit' : 'Loss', 'Net Payout']),
                ...car.partners.map((cp) {
                  final name = cp.partner?.name ?? '';
                  final pct = cp.sharePct / 100;
                  final costShare = totalCost * pct;
                  final revenueShare = salePrice * pct;
                  final profitShare = netProfit * pct;
                  final alreadyPaid = paid[name] ?? 0;
                  // Net payout = their revenue share minus what they still owe
                  // (cost_share - already_paid). If they overpaid, they get more.
                  final netPayout = revenueShare - (costShare - alreadyPaid);
                  final netColor = netPayout >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
                  final psColor = profitShare >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    children: [
                      _cell(name, bold: true),
                      _cell('${cp.sharePct.toStringAsFixed(0)}%', color: Colors.grey),
                      _cell(fmtMoney(alreadyPaid), color: Colors.blue),
                      _cell(fmtMoney(revenueShare), color: Colors.indigo),
                      _cell('${profitShare >= 0 ? '+' : ''}${fmtMoney(profitShare)}', color: psColor, bold: true),
                      _cell(fmtMoney(netPayout), color: netColor, bold: true),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Net Payout = Revenue share − (Cost share − Amount already paid in)',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  TableRow _headerRow(List<String> headers) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade100),
      children: headers
          .map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              ))
          .toList(),
    );
  }

  Widget _cell(String text, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13)),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 40, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _SummaryCol extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool large;
  const _SummaryCol(this.label, this.value, this.color, {this.large = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: large ? 20 : 16)),
    ]));
  }
}

// ── Market Analysis Card ──────────────────────────────────────────────────────
class _MarketAnalysisCard extends StatelessWidget {
  final Car car;
  final AnalysisResult? result;
  final bool analyzing;
  final String? error;
  final VoidCallback onAnalyze;

  const _MarketAnalysisCard({
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
    final cachedPrice = car.marketPrice;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 18, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text('AI Market Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (hasResult)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _ratingColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _ratingColor.withValues(alpha: 0.4)),
                ),
                child: Text(result!.dealRating,
                    style: TextStyle(color: _ratingColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: analyzing ? null : onAnalyze,
              icon: analyzing
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(analyzing ? 'Analyzing…' : hasResult ? 'Re-analyze' : 'Analyze Market'),
              style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.deepPurple),
            ),
          ]),

          if (!hasResult && cachedPrice != null && !analyzing) ...[
            const SizedBox(height: 12),
            Text('Last recommended price: ${fmtMoney(cachedPrice)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],

          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],

          if (hasResult) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(children: [
              _ABox('Market Range',
                  '${fmtMoney(result!.marketValueLow)} – ${fmtMoney(result!.marketValueHigh)}',
                  Colors.blue.shade700),
              const SizedBox(width: 12),
              _ABox('Recommended Price', fmtMoney(result!.recommendedPrice),
                  Colors.deepPurple, highlight: true),
              const SizedBox(width: 12),
              _ABox('Profit Potential',
                  '${fmtMoney(result!.profitPotentialLow)} – ${fmtMoney(result!.profitPotentialHigh)}',
                  result!.profitPotentialLow >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(result!.summary,
                    style: TextStyle(color: Colors.purple.shade800, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Selling Tips',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            ...result!.tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
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

class _ABox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool highlight;
  const _ABox(this.label, this.value, this.color, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.07) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: highlight ? color.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ]),
      ),
    );
  }
}
