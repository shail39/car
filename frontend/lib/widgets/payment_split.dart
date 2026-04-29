import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';

/// Inline widget for splitting a payment among multiple payers.
/// Shows payer rows, remaining amount, Auto-Settle, and Mark as Settled.
class PaymentSplitWidget extends StatefulWidget {
  final String title;
  final String paymentType;
  final double totalAmount;
  final List<CarPartner> partners;
  final List<CarPayment> initialPayments;
  final int carId;
  final void Function(List<CarPayment>) onChanged;

  const PaymentSplitWidget({
    super.key,
    required this.title,
    required this.paymentType,
    required this.totalAmount,
    required this.partners,
    required this.initialPayments,
    required this.carId,
    required this.onChanged,
  });

  @override
  State<PaymentSplitWidget> createState() => _PaymentSplitWidgetState();
}

class _PaymentSplitWidgetState extends State<PaymentSplitWidget> {
  late List<_PaymentRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialPayments.isNotEmpty
        ? widget.initialPayments.map((p) => _PaymentRow(p.paidBy, p.amount)).toList()
        : [];
  }

  double get _totalPaid => _rows.fold(0, (s, r) => s + r.amount);
  double get _remaining => widget.totalAmount - _totalPaid;
  bool get _isSettled => _remaining.abs() < 0.01;

  void _notify() {
    final payments = _rows
        .where((r) => r.paidBy.isNotEmpty && r.amount > 0)
        .map((r) => CarPayment(
              carId: widget.carId,
              paymentType: widget.paymentType,
              paidBy: r.paidBy,
              amount: r.amount,
            ))
        .toList();
    widget.onChanged(payments);
  }

  void _addRow() {
    setState(() => _rows.add(_PaymentRow('', 0)));
  }

  void _removeRow(int i) {
    setState(() => _rows.removeAt(i));
    _notify();
  }

  void _autoSettle() {
    if (widget.partners.isEmpty) return;
    setState(() {
      _rows.clear();
      final total = widget.totalAmount;
      for (final cp in widget.partners) {
        final share = total * cp.sharePct / 100;
        _rows.add(_PaymentRow(cp.partner?.name ?? '', share));
      }
    });
    _notify();
  }

  void _markOnePersonPaid(String name) {
    setState(() {
      _rows = [_PaymentRow(name, widget.totalAmount)];
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(widget.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        Text(fmtMoney(widget.totalAmount),
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),

      // Payer rows
      ..._rows.asMap().entries.map((e) => _PayerRow(
            index: e.key,
            row: e.value,
            partners: widget.partners,
            onRemove: () => _removeRow(e.key),
            onChanged: (paidBy, amount) {
              setState(() {
                _rows[e.key] = _PaymentRow(paidBy, amount);
              });
              _notify();
            },
          )),

      // Actions row
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Payer'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        if (widget.partners.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _autoSettle,
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Auto-Settle by Share'),
            style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Colors.purple),
          ),
        if (widget.partners.length == 2)
          ...widget.partners.map((cp) => OutlinedButton(
                onPressed: () => _markOnePersonPaid(cp.partner?.name ?? ''),
                style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.teal),
                child: Text('${cp.partner?.name ?? ''} paid all'),
              )),
      ]),
      const SizedBox(height: 6),

      // Remaining indicator
      if (_rows.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isSettled
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(_isSettled ? Icons.check_circle : Icons.warning_amber,
                size: 14,
                color: _isSettled ? Colors.green : Colors.orange),
            const SizedBox(width: 6),
            Text(
              _isSettled
                  ? 'Fully accounted'
                  : 'Unaccounted: ${fmtMoney(_remaining.abs())}${_remaining < 0 ? ' (over)' : ''}',
              style: TextStyle(
                  fontSize: 12,
                  color: _isSettled ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      const SizedBox(height: 16),
    ]);
  }
}

class _PaymentRow {
  String paidBy;
  double amount;
  _PaymentRow(this.paidBy, this.amount);
}

class _PayerRow extends StatefulWidget {
  final int index;
  final _PaymentRow row;
  final List<CarPartner> partners;
  final VoidCallback onRemove;
  final void Function(String paidBy, double amount) onChanged;

  const _PayerRow({
    required this.index,
    required this.row,
    required this.partners,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_PayerRow> createState() => _PayerRowState();
}

class _PayerRowState extends State<_PayerRow> {
  late TextEditingController _nameCtrl;
  late TextEditingController _amtCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.row.paidBy);
    _amtCtrl = TextEditingController(
        text: widget.row.amount > 0 ? widget.row.amount.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  void _fire() {
    widget.onChanged(_nameCtrl.text.trim(), double.tryParse(_amtCtrl.text) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final partnerNames = widget.partners.map((p) => p.partner?.name ?? '').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: _nameCtrl.text),
            optionsBuilder: (v) {
              final q = v.text.toLowerCase();
              return partnerNames.where((n) => n.toLowerCase().contains(q));
            },
            onSelected: (v) {
              _nameCtrl.text = v;
              _fire();
            },
            fieldViewBuilder: (_, fc, fn, os) => TextField(
              controller: fc,
              focusNode: fn,
              onEditingComplete: os,
              onChanged: (v) {
                _nameCtrl.text = v;
                _fire();
              },
              decoration: const InputDecoration(
                hintText: 'Who paid?',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => _fire(),
            decoration: const InputDecoration(
              hintText: 'Amount',
              border: OutlineInputBorder(),
              isDense: true,
              prefixText: '\$ ',
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
          onPressed: widget.onRemove,
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }
}
