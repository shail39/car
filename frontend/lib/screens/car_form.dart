import 'package:flutter/material.dart';
import '../api.dart';
import '../car_data.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/payment_split.dart';

class CarFormScreen extends StatefulWidget {
  final Car? car;
  const CarFormScreen({super.key, this.car});

  @override
  State<CarFormScreen> createState() => _CarFormScreenState();
}

class _CarFormScreenState extends State<CarFormScreen> {
  final _form = GlobalKey<FormState>();
  String? _selectedMake;
  String? _selectedModel;
  int? _selectedYear;
  late TextEditingController _vin, _auction, _date,
      _price, _fees, _transport, _salePrice, _notes;
  String _status = 'purchased';
  bool _saving = false;

  List<Partner> _allPartners = [];
  List<CarPartner> _selectedPartners = [];
  List<CarPayment> _purchasePayments = [];
  List<CarPayment> _transportPayments = [];

  List<String> get _models =>
      _selectedMake != null ? (kCarModels[_selectedMake] ?? []) : [];

  @override
  void initState() {
    super.initState();
    final c = widget.car;
    _selectedMake = (c?.make.isNotEmpty == true) ? c!.make : null;
    _selectedModel = (c?.model.isNotEmpty == true) ? c!.model : null;
    _selectedYear = c?.year != 0 ? c?.year : null;
    _vin = TextEditingController(text: c?.vin ?? '');
    _auction = TextEditingController(text: c?.auctionName ?? '');
    _date = TextEditingController(text: c?.purchaseDate ?? '');
    _price = TextEditingController(text: c?.purchasePrice != null ? c!.purchasePrice.toString() : '0');
    _fees = TextEditingController(text: c?.auctionFees != null ? c!.auctionFees.toString() : '0');
    _transport = TextEditingController(text: c?.transportCost != null ? c!.transportCost.toString() : '0');
    _salePrice = TextEditingController(text: c?.salePrice?.toString() ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _status = c?.status ?? 'purchased';

    if (c != null) {
      _purchasePayments = c.payments.where((p) => p.paymentType == 'purchase').toList();
      _transportPayments = c.payments.where((p) => p.paymentType == 'transport').toList();
      _selectedPartners = List.from(c.partners);
    }

    Api.getPartners().then((p) => setState(() => _allPartners = p));
  }

  @override
  void dispose() {
    for (final c in [_vin, _auction, _date, _price, _fees, _transport, _salePrice, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _purchaseTotal =>
      (double.tryParse(_price.text) ?? 0) + (double.tryParse(_fees.text) ?? 0);
  double get _transportTotal => double.tryParse(_transport.text) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final car = Car(
      make: _selectedMake ?? '',
      model: _selectedModel ?? '',
      year: _selectedYear ?? 0,
      vin: _vin.text.trim(),
      auctionName: _auction.text.trim(),
      purchaseDate: _date.text.trim(),
      purchasePrice: double.tryParse(_price.text) ?? 0,
      auctionFees: double.tryParse(_fees.text) ?? 0,
      transportCost: double.tryParse(_transport.text) ?? 0,
      status: _status,
      salePrice: _salePrice.text.isNotEmpty ? double.tryParse(_salePrice.text) : null,
      notes: _notes.text.trim(),
    );

    try {
      int carId;
      if (widget.car?.id == null) {
        final created = await Api.createCar(car);
        carId = created.id!;
        // Add partners
        for (final cp in _selectedPartners) {
          await Api.addCarPartner(carId, cp);
        }
      } else {
        carId = widget.car!.id!;
        await Api.updateCar(carId, car);
      }

      // Save payments via bulk replace
      await Api.bulkSetPayments(carId, 'purchase', _purchasePayments);
      await Api.bulkSetPayments(carId, 'transport', _transportPayments);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? type, bool required = false, String? hint, VoidCallback? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), hintText: hint),
        validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
        onChanged: onChanged != null ? (_) => onChanged() : null,
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial;
    try {
      initial = ctrl.text.isNotEmpty ? DateTime.parse(ctrl.text) : DateTime.now();
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
      setState(() => ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickDate(ctrl),
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(
            ctrl.text.isNotEmpty ? ctrl.text : 'Tap to select date',
            style: TextStyle(color: ctrl.text.isNotEmpty ? Colors.black87 : Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.car != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Car' : 'Add Car')),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Vehicle Info ──
              _sectionTitle('Vehicle Info'),
              Row(children: [
                // Make — searchable autocomplete
                Expanded(child: _MakeDropdown(
                  value: _selectedMake,
                  onChanged: (v) => setState(() { _selectedMake = v; _selectedModel = null; }),
                )),
                const SizedBox(width: 12),
                // Model — filtered by make
                Expanded(child: _ModelDropdown(
                  models: _models,
                  value: _selectedModel,
                  customValue: _selectedModel,
                  onChanged: (v) => setState(() => _selectedModel = v),
                )),
                const SizedBox(width: 12),
                // Year
                SizedBox(width: 120, child: _YearDropdown(
                  value: _selectedYear,
                  onChanged: (v) => setState(() => _selectedYear = v),
                )),
              ]),
              const SizedBox(height: 16),
              _field('VIN (optional)', _vin),

              // ── Partners (pick before payment split so Auto-Settle works) ──
              if (!isEdit) ...[
                _sectionTitle('Partners'),
                _PartnerPicker(
                  allPartners: _allPartners,
                  selected: _selectedPartners,
                  onChanged: (p) => setState(() => _selectedPartners = p),
                ),
              ],

              // ── Auction Info ──
              _sectionTitle('Auction Info'),
              Row(children: [
                Expanded(child: _field('Auction Name', _auction)),
                const SizedBox(width: 12),
                Expanded(child: _dateField('Purchase Date', _date)),
              ]),
              Row(children: [
                Expanded(child: _field('Purchase Price (\$)', _price,
                    type: TextInputType.number,
                    onChanged: () => setState(() {}))),
                const SizedBox(width: 12),
                Expanded(child: _field('Auction Fees (\$)', _fees,
                    type: TextInputType.number,
                    onChanged: () => setState(() {}))),
              ]),

              // Purchase payment split
              if (_purchaseTotal > 0)
                PaymentSplitWidget(
                  key: ValueKey('purchase-$_purchaseTotal'),
                  title: 'Who paid the purchase + fees?',
                  paymentType: 'purchase',
                  totalAmount: _purchaseTotal,
                  partners: _selectedPartners,
                  initialPayments: _purchasePayments,
                  carId: widget.car?.id ?? 0,
                  onChanged: (p) => setState(() => _purchasePayments = p),
                ),

              // ── Transport ──
              _sectionTitle('Transport'),
              _field('Transport Cost (\$)', _transport,
                  type: TextInputType.number, onChanged: () => setState(() {})),

              if (_transportTotal > 0)
                PaymentSplitWidget(
                  key: ValueKey('transport-$_transportTotal'),
                  title: 'Who paid transport?',
                  paymentType: 'transport',
                  totalAmount: _transportTotal,
                  partners: _selectedPartners,
                  initialPayments: _transportPayments,
                  carId: widget.car?.id ?? 0,
                  onChanged: (p) => setState(() => _transportPayments = p),
                ),

              // ── Status ──
              _sectionTitle('Status'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: kStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(kStatusLabels[s] ?? s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
              if (_status == 'sold')
                _field('Sale Price (\$)', _salePrice, type: TextInputType.number),
              _field('Notes', _notes),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(isEdit ? 'Update Car' : 'Add Car',
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PartnerPicker extends StatefulWidget {
  final List<Partner> allPartners;
  final List<CarPartner> selected;
  final void Function(List<CarPartner>) onChanged;

  const _PartnerPicker({
    required this.allPartners,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_PartnerPicker> createState() => _PartnerPickerState();
}

class _PartnerPickerState extends State<_PartnerPicker> {
  void _add(Partner p) {
    final updated = [
      ...widget.selected,
      CarPartner(carId: 0, partnerId: p.id!, sharePct: 50, partner: p),
    ];
    // Auto-distribute shares equally
    final share = 100 / updated.length;
    final redistributed = updated
        .map((cp) => CarPartner(
              carId: cp.carId,
              partnerId: cp.partnerId,
              sharePct: share,
              partner: cp.partner,
            ))
        .toList();
    widget.onChanged(redistributed);
  }

  void _remove(int partnerId) {
    final updated = widget.selected.where((cp) => cp.partnerId != partnerId).toList();
    if (updated.isEmpty) { widget.onChanged(updated); return; }
    final share = 100 / updated.length;
    widget.onChanged(updated
        .map((cp) => CarPartner(carId: cp.carId, partnerId: cp.partnerId, sharePct: share, partner: cp.partner))
        .toList());
  }

  void _updateShare(int partnerId, double pct) {
    widget.onChanged(widget.selected
        .map((cp) => cp.partnerId == partnerId
            ? CarPartner(carId: cp.carId, partnerId: cp.partnerId, sharePct: pct, partner: cp.partner)
            : cp)
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    final addable = widget.allPartners
        .where((p) => !widget.selected.any((cp) => cp.partnerId == p.id))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.selected.isEmpty)
        const Text('No partners added yet', style: TextStyle(color: Colors.grey)),
      ...widget.selected.map((cp) {
        final ctrl = TextEditingController(text: cp.sharePct.toStringAsFixed(1));
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            CircleAvatar(radius: 14, child: Text((cp.partner?.name ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(child: Text(cp.partner?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
            SizedBox(
              width: 80,
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                onChanged: (v) => _updateShare(cp.partnerId, double.tryParse(v) ?? cp.sharePct),
                decoration: const InputDecoration(
                    suffixText: '%', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              onPressed: () => _remove(cp.partnerId),
            ),
          ]),
        );
      }),
      const SizedBox(height: 4),
      if (addable.isNotEmpty)
        Wrap(
          spacing: 8,
          children: addable
              .map((p) => ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(p.name),
                    onPressed: () => _add(p),
                  ))
              .toList(),
        ),
      const SizedBox(height: 8),
    ]);
  }
}

// ── Make searchable autocomplete ──────────────────────────────────────────────
class _MakeDropdown extends StatelessWidget {
  final String? value;
  final void Function(String?) onChanged;
  const _MakeDropdown({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value ?? ''),
      optionsBuilder: (v) {
        final q = v.text.toLowerCase();
        if (q.isEmpty) return kCarMakes;
        return kCarMakes.where((m) => m.toLowerCase().contains(q));
      },
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final opt = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(opt),
                  onTap: () => onSelected(opt),
                );
              },
            ),
          ),
        ),
      ),
      onSelected: onChanged,
      fieldViewBuilder: (_, fc, fn, os) => TextFormField(
        controller: fc,
        focusNode: fn,
        onEditingComplete: os,
        onChanged: (v) {
          // allow custom makes not in list
          if (!kCarMakes.contains(v)) onChanged(v.isEmpty ? null : v);
        },
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: const InputDecoration(
          labelText: 'Make *',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
      ),
    );
  }
}

// ── Model dropdown (filtered by make) ────────────────────────────────────────
class _ModelDropdown extends StatelessWidget {
  final List<String> models;
  final String? value;
  final String? customValue;
  final void Function(String?) onChanged;
  const _ModelDropdown({required this.models, this.value, this.customValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // If make has known models, show dropdown; otherwise free text
    if (models.isEmpty) {
      return TextFormField(
        initialValue: customValue ?? '',
        onChanged: (v) => onChanged(v.isEmpty ? null : v),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
        decoration: const InputDecoration(labelText: 'Model *', border: OutlineInputBorder()),
      );
    }

    final safeValue = (value != null && models.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: const InputDecoration(labelText: 'Model *', border: OutlineInputBorder()),
      isExpanded: true,
      items: models.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}

// ── Year dropdown ─────────────────────────────────────────────────────────────
class _YearDropdown extends StatelessWidget {
  final int? value;
  final void Function(int?) onChanged;
  const _YearDropdown({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: const InputDecoration(labelText: 'Year *', border: OutlineInputBorder()),
      isExpanded: true,
      items: kCarYears.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
