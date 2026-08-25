import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'donut_painter.dart';
import 'localization.dart';
import 'currencies.dart';
import 'storage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> _expenses = [];
  late List<Category> _categories;

  String _period = 'month'; // week | month | all
  double? _monthlyLimit;
  String _searchQuery = '';
  AppLanguage _lang = AppLanguage.ru;
  bool _isDark = true;
  String _currencyId = 'az';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _categories = List.of(defaultCategories);
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final lang = await AppStorage.loadLang();
    final dark = await AppStorage.loadDark();
    final currency = await AppStorage.loadCurrency();
    final limit = await AppStorage.loadLimit();
    final customCats = await AppStorage.loadCustomCategories();
    final expenses = await AppStorage.loadExpenses();
    if (!mounted) return;
    setState(() {
      _lang = lang;
      _isDark = dark;
      _currencyId = currency;
      _monthlyLimit = limit;
      _categories.addAll(customCats);
      _expenses.addAll(expenses);
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      _loaded = true;
    });
  }

  // ---------- Перевод, валюта, цветовая палитра ----------

  String tr(String key) => AppStrings.t(_lang, key);

  Currency get _currency => currencyById(_currencyId);

  String categoryName(Category cat) =>
      cat.isCustom ? (cat.customName ?? '') : tr(cat.nameKey!);

  String categoryHint(Category cat) =>
      cat.isCustom ? (cat.customHint ?? tr('own_category_hint')) : tr(cat.hintKey!);

  Color get bg => _isDark ? const Color(0xFF1B1C1E) : const Color(0xFFF5F1EA);
  Color get panelBg => _isDark ? Colors.white.withOpacity(0.045) : Colors.white.withOpacity(0.55);
  Color get panelBorder => _isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
  Color get ink => _isDark ? Colors.white : const Color(0xFF211F1B);
  Color get inkSoft => _isDark ? Colors.white60 : Colors.black45;
  Color get inkFaint => _isDark ? Colors.white38 : Colors.black38;
  Color get sheetBg => _isDark ? const Color(0xFF232427) : Colors.white;
  Color get pillActiveBg => _isDark ? Colors.white : const Color(0xFF211F1B);
  Color get pillActiveText => _isDark ? const Color(0xFF1B1C1E) : Colors.white;
  Color get fieldBg => _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.035);

  TextStyle _display({double size = 16, FontWeight weight = FontWeight.w700, Color? color}) {
    return GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color ?? ink);
  }

  TextStyle _body({double size = 13, FontWeight weight = FontWeight.w500, Color? color}) {
    return GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color ?? ink);
  }

  // ---------- Вычисления ----------

  List<Expense> get _filteredByPeriod {
    final now = DateTime.now();
    return _expenses.where((e) {
      if (_period == 'all') return true;
      if (_period == 'month') {
        return e.date.year == now.year && e.date.month == now.month;
      }
      final weekAgo = now.subtract(const Duration(days: 7));
      return e.date.isAfter(weekAgo);
    }).toList();
  }

  List<Expense> get _visibleHistory {
    final base = _filteredByPeriod;
    if (_searchQuery.trim().isEmpty) return base;
    final q = _searchQuery.trim().toLowerCase();
    return base.where((e) {
      final catName = categoryName(_categoryFor(e.categoryId)).toLowerCase();
      return catName.contains(q) || e.note.toLowerCase().contains(q);
    }).toList();
  }

  double get _total => _filteredByPeriod.fold(0.0, (s, e) => s + e.amount);

  Map<String, double> get _totalsByCategory {
    final map = <String, double>{};
    for (final e in _filteredByPeriod) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
    }
    return map;
  }

  int get _daysInPeriod {
    if (_filteredByPeriod.isEmpty) return 1;
    final dates = _filteredByPeriod
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
    return dates.length.clamp(1, 999);
  }

  String? get _topCategoryId {
    final totals = _totalsByCategory;
    if (totals.isEmpty) return null;
    return (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  Category _categoryFor(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => _categories.last,
    );
  }

  // ---------- Действия ----------

  void _addExpense(Category cat, double amount, DateTime date, String note) {
    setState(() {
      _expenses.add(Expense(
        amount: amount,
        date: date,
        categoryId: cat.id,
        note: note,
      ));
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    });
    AppStorage.saveExpenses(_expenses);
  }

  void _deleteExpense(Expense e) {
    setState(() => _expenses.remove(e));
    AppStorage.saveExpenses(_expenses);
  }

  void _addCustomCategory(String name, IconData icon, Color color) {
    setState(() {
      _categories.add(Category(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        icon: icon,
        color: color,
        isCustom: true,
        customName: name,
      ));
    });
    AppStorage.saveCustomCategories(_categories);
  }

  // ---------- UI: модалка добавления траты ----------

  void _openAddSheet(Category cat) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: cat.color.withOpacity(0.18),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(categoryName(cat), style: _display(size: 16)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: _display(size: 30, weight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: inkFaint),
                        border: InputBorder.none,
                        suffixText: '  ${_currency.symbol}',
                        suffixStyle: TextStyle(color: inkSoft, fontSize: 20),
                      ),
                    ),
                    Divider(color: panelBorder, height: 24),
                    TextField(
                      controller: noteCtrl,
                      style: _body(color: ink),
                      decoration: InputDecoration(
                        hintText: categoryHint(cat),
                        hintStyle: _body(color: inkFaint),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.edit_note_rounded, color: inkFaint),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.event_rounded, color: inkFaint, size: 18),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          child: Text(
                            '${selectedDate.day.toString().padLeft(2, '0')}.'
                            '${selectedDate.month.toString().padLeft(2, '0')}.'
                            '${selectedDate.year}',
                            style: _body(color: inkSoft, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cat.color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final amount = double.tryParse(
                            amountCtrl.text.replaceAll(',', '.'),
                          );
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(tr('error_amount'))),
                            );
                            return;
                          }
                          _addExpense(cat, amount, selectedDate, noteCtrl.text.trim());
                          Navigator.pop(ctx);
                        },
                        child: Text(tr('add_button'), style: _body(weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------- UI: модалка создания своей категории ----------

  void _openNewCategorySheet() {
    final nameCtrl = TextEditingController();
    IconData chosenIcon = customCategoryIcons.first;
    Color chosenColor = customCategoryColors.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('new_category'), style: _display(size: 16)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: _body(color: ink),
                      decoration: InputDecoration(
                        hintText: tr('category_name_hint'),
                        hintStyle: _body(color: inkFaint),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(tr('icon_label'), style: _body(color: inkSoft, size: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: customCategoryIcons.map((icon) {
                        final selected = icon == chosenIcon;
                        return GestureDetector(
                          onTap: () => setModalState(() => chosenIcon = icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: selected ? chosenColor.withOpacity(0.25) : fieldBg,
                              borderRadius: BorderRadius.circular(12),
                              border: selected
                                  ? Border.all(color: chosenColor, width: 1.5)
                                  : null,
                            ),
                            child: Icon(icon, color: inkSoft, size: 20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(tr('color_label'), style: _body(color: inkSoft, size: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: customCategoryColors.map((color) {
                        final selected = color == chosenColor;
                        return GestureDetector(
                          onTap: () => setModalState(() => chosenColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: ink, width: 2) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: chosenColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(tr('error_category_name'))),
                            );
                            return;
                          }
                          _addCustomCategory(name, chosenIcon, chosenColor);
                          Navigator.pop(ctx);
                        },
                        child: Text(tr('create_category'), style: _body(weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------- UI: диалог лимита ----------

  void _openLimitDialog() {
    final ctrl = TextEditingController(
      text: _monthlyLimit != null ? _monthlyLimit!.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr('monthly_limit_title'), style: _display(size: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: _body(color: ink),
          decoration: InputDecoration(
            suffixText: _currency.symbol,
            suffixStyle: TextStyle(color: inkSoft),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel'), style: _body(color: inkSoft)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              final newLimit = (v != null && v > 0) ? v : null;
              setState(() => _monthlyLimit = newLimit);
              AppStorage.saveLimit(newLimit);
              Navigator.pop(ctx);
            },
            child: Text(tr('save'), style: _body(color: ink)),
          ),
        ],
      ),
    );
  }

  // ---------- UI: выбор языка ----------

  void _openLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: panelBorder, borderRadius: BorderRadius.circular(4)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: AppLanguage.values.map((lang) {
                    final selected = lang == _lang;
                    return ListTile(
                      leading: Text(AppStrings.languageFlag(lang), style: const TextStyle(fontSize: 22)),
                      title: Text(
                        AppStrings.languageLabel(lang),
                        style: _body(color: ink, weight: selected ? FontWeight.w800 : FontWeight.w500),
                      ),
                      trailing: selected ? Icon(Icons.check_rounded, color: ink) : null,
                      onTap: () {
                        setState(() => _lang = lang);
                        AppStorage.saveLang(lang);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI: выбор валюты ----------

  void _openCurrencySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: panelBorder, borderRadius: BorderRadius.circular(4)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: currencies.map((c) {
                    final selected = c.id == _currencyId;
                    return ListTile(
                      leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        '${c.code}  ${c.symbol}',
                        style: _body(color: ink, weight: selected ? FontWeight.w800 : FontWeight.w500),
                      ),
                      trailing: selected ? Icon(Icons.check_rounded, color: ink) : null,
                      onTap: () {
                        setState(() => _currencyId = c.id);
                        AppStorage.saveCurrency(c.id);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Сборка экрана ----------

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: ink)),
      );
    }

    final total = _total;
    final totalsMap = _totalsByCategory;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildPeriodPills(),
                const SizedBox(height: 16),
                _buildHeroCard(total, totalsMap),
                const SizedBox(height: 16),
                _buildInsights(total),
                const SizedBox(height: 24),
                _buildSectionTitle(tr('add_expense')),
                const SizedBox(height: 10),
                _buildCategoryGrid(),
                const SizedBox(height: 24),
                _buildSectionTitle(tr('history')),
                const SizedBox(height: 8),
                _buildSearchField(),
                const SizedBox(height: 8),
                _buildHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final blobColor = _isDark ? const Color(0xFF33352F) : const Color(0xFFE7DCC8);
    final blobColor2 = _isDark ? const Color(0xFF2C3230) : const Color(0xFFDCE4D6);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.9),
                radius: 1.3,
                colors: _isDark
                    ? [const Color(0xFF26282A), const Color(0xFF1B1C1E)]
                    : [const Color(0xFFFAF7F0), const Color(0xFFF5F1EA)],
              ),
            ),
          ),
        ),
        Positioned(top: -70, right: -50, child: _softBlob(220, blobColor)),
        Positioned(bottom: 60, left: -60, child: _softBlob(200, blobColor2)),
      ],
    );
  }

  Widget _softBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(0.55), color.withOpacity(0.0)]),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(tr('app_title'), style: _display(size: 19)),
        Row(
          children: [
            IconButton(
              onPressed: _openCurrencySheet,
              icon: Text(_currency.symbol, style: _display(size: 16, color: inkSoft)),
            ),
            IconButton(
              onPressed: _openLanguageSheet,
              icon: Text(AppStrings.languageFlag(_lang), style: const TextStyle(fontSize: 18)),
            ),
            IconButton(
              onPressed: () {
                final newDark = !_isDark;
                setState(() => _isDark = newDark);
                AppStorage.saveDark(newDark);
              },
              icon: Icon(_isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: inkSoft),
            ),
            IconButton(
              onPressed: _openLimitDialog,
              icon: Icon(Icons.tune_rounded, color: inkSoft),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodPills() {
    Widget pill(String key, String label) {
      final active = _period == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _period = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? pillActiveBg : fieldBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: _body(weight: FontWeight.w700, size: 13, color: active ? pillActiveText : inkSoft),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('week', tr('period_week')),
        pill('month', tr('period_month')),
        pill('all', tr('period_all')),
      ],
    );
  }

  Widget _buildHeroCard(double total, Map<String, double> totalsMap) {
    final entries = totalsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final segments = entries.map((e) => MapEntry(_categoryFor(e.key).color, e.value)).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: panelBorder),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: DonutPainter(segments: segments, trackColor: panelBorder),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('spent'),
                          style: _body(size: 11, weight: FontWeight.w700, color: inkFaint),
                        ),
                        const SizedBox(height: 4),
                        Text('${total.round()}', style: _display(size: 34)),
                        Text(_currency.symbol, style: _body(size: 14, weight: FontWeight.w600, color: inkFaint)),
                      ],
                    ),
                  ],
                ),
              ),
              if (_monthlyLimit != null && _period == 'month') ...[
                const SizedBox(height: 16),
                _buildLimitBar(total),
              ],
              const SizedBox(height: 16),
              if (entries.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final cat = _categoryFor(entries[i].key);
                      final pct = (entries[i].value / total * 100).round();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: fieldBg, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            Icon(cat.icon, size: 13, color: cat.color),
                            const SizedBox(width: 6),
                            Text('$pct%', style: _body(color: inkSoft, weight: FontWeight.w700, size: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitBar(double total) {
    final limit = _monthlyLimit!;
    final pct = (total / limit).clamp(0.0, 1.0);
    final over = total > limit;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              over
                  ? tr('limit_over')
                  : '${tr('limit_left')} ${(limit - total).round()} ${_currency.symbol}',
              style: _body(color: inkSoft, size: 12),
            ),
            Text(
              '${tr('limit_of')} ${limit.round()} ${_currency.symbol}',
              style: _body(color: inkSoft, size: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: fieldBg,
            valueColor: AlwaysStoppedAnimation(
              over ? const Color(0xFFD3705A) : const Color(0xFF7C9885),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsights(double total) {
    final avgPerDay = total / _daysInPeriod;
    final topCatId = _topCategoryId;
    final topCat = topCatId != null ? _categoryFor(topCatId) : null;

    Widget statCard(String label, String value, {IconData? icon, Color? color}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) Icon(icon, size: 16, color: color ?? inkSoft),
              const SizedBox(height: 8),
              Text(value, style: _display(size: 15, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(label, style: _body(color: inkFaint, size: 11)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        statCard(tr('avg_per_day'), '${avgPerDay.round()} ${_currency.symbol}'),
        const SizedBox(width: 10),
        statCard(
          tr('top_category'),
          topCat != null ? categoryName(topCat) : tr('no_top_category'),
          icon: topCat?.icon,
          color: topCat?.color,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text, style: _body(color: inkFaint, size: 12, weight: FontWeight.w700));
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._categories.map((cat) => _categoryButton(cat)),
        _addCategoryButton(),
      ],
    );
  }

  double _gridItemWidth(BuildContext context) {
    return (MediaQuery.of(context).size.width - 16 * 2 - 10 * 3) / 4;
  }

  Widget _categoryButton(Category cat) {
    return SizedBox(
      width: _gridItemWidth(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openAddSheet(cat),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: panelBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: cat.color.withOpacity(0.18), shape: BoxShape.circle),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(height: 7),
                Text(
                  categoryName(cat),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(size: 10.5, weight: FontWeight.w600, color: inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _addCategoryButton() {
    return SizedBox(
      width: _gridItemWidth(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openNewCategorySheet,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: panelBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: fieldBg, shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded, color: inkSoft, size: 18),
                ),
                const SizedBox(height: 7),
                Text(tr('own_category'), style: _body(size: 10.5, weight: FontWeight.w600, color: inkFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      style: _body(color: ink, size: 13.5),
      decoration: InputDecoration(
        hintText: tr('search_hint'),
        hintStyle: _body(color: inkFaint, size: 13.5),
        prefixIcon: Icon(Icons.search_rounded, color: inkFaint, size: 20),
        filled: true,
        fillColor: panelBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildHistory() {
    final list = _visibleHistory;

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            tr('empty_history'),
            textAlign: TextAlign.center,
            style: _body(color: inkFaint, size: 13),
          ),
        ),
      );
    }

    return Column(
      children: list.map((e) {
        final cat = _categoryFor(e.categoryId);
        final dateStr = '${e.date.day.toString().padLeft(2, '0')}.'
            '${e.date.month.toString().padLeft(2, '0')}';
        return Dismissible(
          key: ValueKey(e.hashCode),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteExpense(e),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            child: Icon(Icons.delete_outline_rounded, color: inkSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cat.color.withOpacity(0.16), borderRadius: BorderRadius.circular(13)),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(categoryName(cat), style: _body(color: ink, weight: FontWeight.w700, size: 13.5)),
                      if (e.note.isNotEmpty)
                        Text(
                          e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(color: inkFaint, size: 12),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${e.amount.round()} ${_currency.symbol}', style: _display(size: 13, weight: FontWeight.w600)),
                    Text(dateStr, style: _body(color: inkFaint, size: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
