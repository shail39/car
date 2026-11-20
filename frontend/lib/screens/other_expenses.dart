import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';

/// Account-level overhead expenses (rent, consumables, utilities, etc.) that
/// are not tied to any specific car.
class OtherExpensesScreen extends StatefulWidget {
  const OtherExpensesScreen({super.key});

  @override
  State<OtherExpensesScreen> createState() => _OtherExpensesScreenState();
}

class _OtherExpensesScreenState extends State<OtherExpensesScreen> {
  List<OtherExpense> _items = [];
  List<String> _partnerNames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await Api.getOtherExpenses();
    final partners = await Api.getPartners();
    if (!mounted) return;
    setState(() {
      _items = items;
      _partnerNames = partners.map((p) => p.name).toList();
      _loading = false;
    });
  }

  double get _total => _items.fold(0, (s, e) => s + e.amount);

  Future<void> _showForm([OtherExpense? expense]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _OtherExpenseForm(expense: expense, partnerNames: _partnerNames),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(OtherExpense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete ${e.category}${e.description.isNotEmpty ? ' — ${e.description}' : ''} (${fmtMoney(e.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await Api.deleteOtherExpense(e.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Other Expenses',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('Account overhead not tied to a car',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ]),
            ),
            FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Add Expense')),
          ]),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else ...[
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(fmtMoney(_total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                ),
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No other expenses yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      final sub = [
                        if (e.expenseDate.isNotEmpty) e.expenseDate,
                        if (e.paidBy.isNotEmpty) 'Paid by ${e.paidBy}',
                        if (e.description.isNotEmpty) e.description,
                      ].join(' · ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            child: const Icon(Icons.receipt_long_outlined, size: 20),
                          ),
                          title: Text(e.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: sub.isEmpty ? null : Text(sub),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(fmtMoney(e.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(e)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(e)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ]),
    );
  }
}

class _OtherExpenseForm extends StatefulWidget {
  final OtherExpense? expense;
  final List<String> partnerNames;

  const _OtherExpenseForm({this.expense, required this.partnerNames});

  @override
  State<_OtherExpenseForm> createState() => _OtherExpenseFormState();
}

class _OtherExpenseFormState extends State<_OtherExpenseForm> {
  late String _category;
  late TextEditingController _descCtrl;
  late TextEditingController _amtCtrl;
  String? _paidBy;
  late String _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _category = (e != null && kCategories.contains(e.category)) ? e.category : kCategories.first;
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _amtCtrl = TextEditingController(text: (e != null && e.amount > 0) ? e.amount.toStringAsFixed(2) : '');
    _paidBy = (e != null && e.paidBy.isNotEmpty) ? e.paidBy : null;
    _date = e?.expenseDate ?? '';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
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
    final amount = double.tryParse(_amtCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than 0')));
      return;
    }
    setState(() => _saving = true);
    final e = OtherExpense(
      category: _category,
      description: _descCtrl.text.trim(),
      amount: amount,
      paidBy: _paidBy ?? '',
      expenseDate: _date,
    );
    if (widget.expense == null) {
      await Api.createOtherExpense(e);
    } else {
      await Api.updateOtherExpense(widget.expense!.id!, e);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Add Other Expense' : 'Edit Other Expense'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixText: '\$ '),
            ),
            const SizedBox(height: 12),
            if (widget.partnerNames.isNotEmpty)
              DropdownButtonFormField<String>(
                value: widget.partnerNames.contains(_paidBy) ? _paidBy : null,
                decoration: const InputDecoration(
                    labelText: 'Paid By', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                hint: const Text('Select partner'),
                items: widget.partnerNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                onChanged: (v) => setState(() => _paidBy = v),
              ),
            if (widget.partnerNames.isNotEmpty) const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                child: Text(_date.isNotEmpty ? _date : 'Select date'),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.expense == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
