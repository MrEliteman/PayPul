import 'package:flutter/material.dart';
import 'l10n.dart';
import 'models.dart';
import 'money.dart';
import 'store.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store, this.expense});
  final AppStore store;
  final Expense? expense;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _desc;
  late String _category;
  late DateTime _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amount = TextEditingController(text: e == null ? '' : minorToInput(e.amount));
    _desc = TextEditingController(text: e?.description ?? '');
    _category = e?.category ?? 'food';
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final minor = parseMinor(_amount.text);
    if (minor == null) {
      setState(() => _error = tr(context, 'invalid_amount'));
      return;
    }
    final nav = Navigator.of(context);
    final old = widget.expense;
    if (old == null) {
      await widget.store.add(Expense(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        amount: minor,
        description: _desc.text.trim(),
        category: _category,
        date: _date,
      ));
    } else {
      await widget.store.update(old.copyWith(
        amount: minor,
        description: _desc.text.trim(),
        category: _category,
        date: _date,
      ));
    }
    nav.pop();
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, 'delete_q')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr(c, 'cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr(c, 'delete'))),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.delete(widget.expense!.id);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.expense != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, editing ? 'edit' : 'add')),
        actions: [
          if (editing)
            IconButton(
              tooltip: tr(context, 'delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _amount,
            autofocus: !editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: tr(context, 'amount'),
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr(context, 'description')),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: tr(context, 'category')),
            items: [
              for (final k in categoryKeys)
                DropdownMenuItem(value: k, child: Text(tr(context, 'cat_$k'))),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'other'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: tr(context, 'date')),
              child: Text(formatDate(_date)),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(onPressed: _save, child: Text(tr(context, 'save'))),
          ),
        ],
      ),
    );
  }
}
