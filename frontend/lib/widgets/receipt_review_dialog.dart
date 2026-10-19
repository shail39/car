import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';

/// Shown after a receipt photo is scanned — lets the user review, edit, and
/// selectively confirm the AI-extracted line items before they're saved as
/// expenses.
class ReceiptReviewDialog extends StatefulWidget {
  final ReceiptScanResult result;
  final Uint8List imageBytes;
  final int carId;
  final List<String> partnerNames;
  final VoidCallback onDone;

  const ReceiptReviewDialog({
    super.key,
    required this.result,
    required this.imageBytes,
    required this.carId,
    required this.partnerNames,
    required this.onDone,
  });

  @override
  State<ReceiptReviewDialog> createState() => _ReceiptReviewDialogState();
}

class _ReceiptReviewDialogState extends State<ReceiptReviewDialog> {
  late TextEditingController _vendorCtrl;
  late String _date;
  String? _paidBy;
  late List<bool> _selected;
  late List<Expense> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _vendorCtrl = TextEditingController(text: widget.result.vendor);
    _date = widget.result.receiptDate;
    _items = List.of(widget.result.items);
    _selected = List.filled(_items.length, true);
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
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
    final toAdd = <Expense>[
      for (var i = 0; i < _items.length; i++)
        if (_selected[i]) _items[i],
    ];
    if (toAdd.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    for (final item in toAdd) {
      await Api.createExpense(
        widget.carId,
        item.copyWith(paidBy: _paidBy ?? '', expenseDate: _date),
      );
    }
    if (mounted) Navigator.pop(context);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;
    return AlertDialog(
      title: const Text('Review Scanned Receipt'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(widget.imageBytes, height: 140, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(labelText: 'Vendor', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), isDense: true),
                    child: Text(_date.isNotEmpty ? _date : 'Select date'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (widget.partnerNames.isNotEmpty)
              DropdownButtonFormField<String>(
                value: widget.partnerNames.contains(_paidBy) ? _paidBy : null,
                decoration: const InputDecoration(
                    labelText: 'Paid By', border: OutlineInputBorder(), isDense: true,
                    prefixIcon: Icon(Icons.person_outline)),
                hint: const Text('Select partner'),
                items: widget.partnerNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (v) => setState(() => _paidBy = v),
              ),
            const SizedBox(height: 16),
            Text('$selectedCount of ${_items.length} item${_items.length == 1 ? '' : 's'} selected',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(),
            ...List.generate(
              _items.length,
              (i) => _ReceiptItemRow(
                key: ValueKey(i),
                item: _items[i],
                selected: _selected[i],
                onSelectedChanged: (v) => setState(() => _selected[i] = v),
                onChanged: (e) => _items[i] = e,
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || selectedCount == 0 ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Add $selectedCount Expense${selectedCount == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
}

class _ReceiptItemRow extends StatefulWidget {
  final Expense item;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<Expense> onChanged;

  const _ReceiptItemRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onSelectedChanged,
    required this.onChanged,
  });

  @override
  State<_ReceiptItemRow> createState() => _ReceiptItemRowState();
}

class _ReceiptItemRowState extends State<_ReceiptItemRow> {
  late String _category;
  late TextEditingController _descCtrl;
  late TextEditingController _partCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _amtCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.item;
    _category = kCategories.contains(e.category) ? e.category : kCategories.last;
    _descCtrl = TextEditingController(text: e.description);
    _partCtrl = TextEditingController(text: e.partNumber);
    _qtyCtrl = TextEditingController(
        text: e.quantity == e.quantity.roundToDouble() ? e.quantity.toStringAsFixed(0) : e.quantity.toString());
    _unitCtrl = TextEditingController(text: e.unitPrice > 0 ? e.unitPrice.toStringAsFixed(2) : '');
    _amtCtrl = TextEditingController(text: e.amount > 0 ? e.amount.toStringAsFixed(2) : '');
    _qtyCtrl.addListener(_recalc);
    _unitCtrl.addListener(_recalc);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _partCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  void _recalc() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final unit = double.tryParse(_unitCtrl.text) ?? 0;
    if (qty > 0 && unit > 0) {
      _amtCtrl.text = (qty * unit).toStringAsFixed(2);
    }
    _fire();
  }

  void _fire() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final unit = double.tryParse(_unitCtrl.text) ?? 0;
    final amount = double.tryParse(_amtCtrl.text) ?? 0;
    widget.onChanged(widget.item.copyWith(
      category: _category,
      description: _descCtrl.text.trim(),
      partNumber: _partCtrl.text.trim(),
      quantity: qty,
      unitPrice: unit > 0 ? unit : (qty > 0 ? amount / qty : 0),
      amount: amount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.selected ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: widget.selected, onChanged: (v) => widget.onSelectedChanged(v ?? false)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                    items: kCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _category = v ?? _category);
                      _fire();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _descCtrl,
                    onChanged: (_) => _fire(),
                    decoration:
                        const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _partCtrl,
                    onChanged: (_) => _fire(),
                    decoration: const InputDecoration(labelText: 'Part #', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Unit Price', border: OutlineInputBorder(), isDense: true, prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _fire(),
                    decoration: const InputDecoration(
                        labelText: 'Amount', border: OutlineInputBorder(), isDense: true, prefixText: '\$ '),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
