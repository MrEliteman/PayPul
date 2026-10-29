import 'package:flutter/material.dart';
import 'editor_screen.dart';
import 'l10n.dart';
import 'money.dart';
import 'store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _month;
  String? _filter;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int d) =>
      setState(() => _month = DateTime(_month.year, _month.month + d));

  void _open([expense]) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorScreen(store: widget.store, expense: expense)));

  Future<void> _editLimit() async {
    final cur = widget.store.monthlyLimit;
    final c = TextEditingController(text: cur == null ? '' : minorToInput(cur));
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr(ctx, 'limit')),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: tr(ctx, 'amount'), errorText: err),
          ),
          actions: [
            if (cur != null)
              TextButton(
                onPressed: () async {
                  await widget.store.setLimit(null);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(tr(ctx, 'remove_limit')),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(ctx, 'cancel'))),
            TextButton(
              onPressed: () async {
                final v = parseMinor(c.text);
                if (v == null) {
                  setD(() => err = tr(ctx, 'invalid_amount'));
                  return;
                }
                await widget.store.setLimit(v);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr(ctx, 'save')),
            ),
          ],
        ),
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final total = widget.store.totalForMonth(_month.year, _month.month);
        final limit = widget.store.monthlyLimit;
        final items = widget.store.forMonth(_month.year, _month.month, category: _filter);

        return Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'app_name')),
            actions: [
              IconButton(
                tooltip: tr(context, 'limit'),
                icon: const Icon(Icons.speed_outlined),
                onPressed: _editLimit,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: tr(context, 'add'),
            onPressed: _open,
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                  Text(
                    '${_month.month.toString().padLeft(2, '0')}.${_month.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _Summary(total: total, limit: limit),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip(tr(context, 'all'), _filter == null, () => setState(() => _filter = null)),
                    for (final k in categoryKeys)
                      _chip(tr(context, 'cat_$k'), _filter == k, () => setState(() => _filter = k)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          tr(context, 'empty'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = items[i];
                          return ListTile(
                            onTap: () => _open(e),
                            title: Text(e.description.isEmpty
                                ? tr(context, 'cat_${e.category}')
                                : e.description),
                            subtitle: Text('${tr(context, 'cat_${e.category}')} · ${formatDate(e.date)}'),
                            trailing: Text(
                              formatMinor(e.amount),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.limit});
  final int total;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final over = limit != null && total > limit!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: over ? Colors.black : Colors.white,
        border: Border.all(color: Colors.black, width: over ? 2 : 1),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: over ? Colors.white : Colors.black),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'month_total'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(formatMinor(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (limit == null)
              Text(tr(context, 'no_limit'), style: const TextStyle(fontSize: 13))
            else ...[
              LinearProgressIndicator(
                value: (total / limit!).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                color: over ? Colors.white : Colors.black,
                backgroundColor: over ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 8),
              Text(
                over
                    ? '${tr(context, 'over')}: ${formatMinor(total - limit!)}'
                    : '${tr(context, 'left')}: ${formatMinor(limit! - total)}  /  ${formatMinor(limit!)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
