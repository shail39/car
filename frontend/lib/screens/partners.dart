import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  List<Partner> _partners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Api.getPartners();
    setState(() { _partners = list; _loading = false; });
  }

  Future<void> _showForm([Partner? partner]) async {
    final nameCtrl = TextEditingController(text: partner?.name ?? '');
    final phoneCtrl = TextEditingController(text: partner?.phone ?? '');
    final emailCtrl = TextEditingController(text: partner?.email ?? '');

    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(partner == null ? 'Add Partner' : 'Edit Partner'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final p = Partner(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), email: emailCtrl.text.trim());
          if (partner == null) {
            await Api.createPartner(p);
          } else {
            await Api.updatePartner(partner.id!, p);
          }
          if (mounted) Navigator.pop(context);
          _load();
        }, child: Text(partner == null ? 'Add' : 'Update')),
      ],
    ));
  }

  Future<void> _delete(Partner p) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Remove Partner'),
      content: Text('Remove ${p.name}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ));
    if (ok == true) { await Api.deletePartner(p.id!); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text('Partners', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add), label: const Text('Add Partner')),
          ]),
        ),
        if (_loading) const Center(child: CircularProgressIndicator())
        else Expanded(
          child: _partners.isEmpty
              ? const Center(child: Text('No partners yet'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _partners.length,
                  itemBuilder: (_, i) {
                    final p = _partners[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(p.name[0].toUpperCase())),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text([if (p.phone.isNotEmpty) p.phone, if (p.email.isNotEmpty) p.email].join(' · ')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(p)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(p)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
