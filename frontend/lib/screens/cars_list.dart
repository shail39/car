import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../utils.dart';
import 'car_detail.dart';
import 'car_form.dart';

class CarsListScreen extends StatefulWidget {
  const CarsListScreen({super.key});

  @override
  State<CarsListScreen> createState() => _CarsListScreenState();
}

class _CarsListScreenState extends State<CarsListScreen> {
  List<Car> _cars = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cars = await Api.getCars();
    setState(() { _cars = cars; _loading = false; });
  }

  Future<void> _addCar() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CarFormScreen()));
    if (result == true) _load();
  }

  Future<void> _openCar(Car car) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CarDetailScreen(carId: car.id!)));
    if (result == true) _load();
  }

  Future<void> _deleteCar(Car car) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete Car'),
      content: Text('Delete ${car.displayName}? All expenses will be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) { await Api.deleteCar(car.id!); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? _cars
        : _cars.where((c) => c.displayName.toLowerCase().contains(_filter.toLowerCase()) ||
            c.auctionName.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Cars', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
              FilledButton.icon(onPressed: _addCar, icon: const Icon(Icons.add), label: const Text('Add Car')),
            ]),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(hintText: 'Search...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ]),
        ),
        if (_loading) const Center(child: CircularProgressIndicator())
        else Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No cars yet. Add your first car!'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _CarTile(filtered[i], onTap: () => _openCar(filtered[i]), onDelete: () => _deleteCar(filtered[i])),
                ),
        ),
      ]),
    );
  }
}

class _CarTile extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CarTile(this.car, {required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final statusColor = {
      'purchased': Colors.blue,
      'in_repair': Colors.orange,
      'ready': Colors.teal,
      'for_sale': Colors.purple,
      'sold': Colors.green,
    }[car.status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(Icons.directions_car, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(car.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(kStatusLabels[car.status] ?? car.status,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 12, children: [
              Text('Cost: ${fmtMoney(car.totalCost)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (car.profit != null)
                Text('P/L: ${fmtMoney(car.profit!)}',
                    style: TextStyle(color: profitColor(car.profit), fontWeight: FontWeight.bold, fontSize: 13)),
              if (car.auctionName.isNotEmpty)
                Text(car.auctionName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              if (car.partners.isNotEmpty)
                Text(car.partners.map((p) => p.partner?.name ?? '').join(', '),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }
}
