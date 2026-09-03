import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_actions/quick_actions.dart';

import 'models.dart';
import 'donut_painter.dart';
import 'piggy_painter.dart';
import 'localization.dart';
import 'currencies.dart';
import 'storage.dart';
import 'notifications.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Expense> _expenses = [];
  late List<Category> _categories;
  SavingsGoal? _savingsGoal;
  final List<SavingsContribution> _savingsContributions = [];
  final List<Debt> _debts = [];

  int _currentTab = 0; // 0 = траты, 1 = копилка, 2 = долги
  String _debtsView = 'owed_to_me'; // owed_to_me | i_owe

  String _period = 'month'; // week | month | all
  double? _monthlyLimit;
  String _searchQuery = '';
  AppLanguage _lang = AppLanguage.ru;
  String _themeMode = 'system'; // system | light | dark
  String _currencyId = 'az';
  double _fontScale = 1.0;
  bool _loaded = false;

  late final QuickActions _quickActions;

  @override
  void initState() {
    super.initState();
    _categories = List.of(defaultCategories);
    _quickActions = QuickActions();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final lang = await AppStorage.loadLang();
    final themeMode = await AppStorage.loadThemeMode();
    final currency = await AppStorage.loadCurrency();
    final limit = await AppStorage.loadLimit();
    final fontScale = await AppStorage.loadFontScale();
    final customCats = await AppStorage.loadCustomCategories();
    final expenses = await AppStorage.loadExpenses();
    final savingsGoal = await AppStorage.loadSavingsGoal();
    final contributions = await AppStorage.loadSavingsContributions();
    final debts = await AppStorage.loadDebts();
    if (!mounted) return;
    setState(() {
      _lang = lang;
      _themeMode = themeMode;
      _currencyId = currency;
      _monthlyLimit = limit;
      _fontScale = fontScale;
      _categories.addAll(customCats);
      _expenses.addAll(expenses);
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      _savingsGoal = savingsGoal;
      _savingsContributions.addAll(contributions);
      _savingsContributions.sort((a, b) => b.date.compareTo(a.date));
      _debts.addAll(debts);
      _debts.sort((a, b) => b.date.compareTo(a.date));
      _loaded = true;
    });
    _initQuickActions();
  }

  void _initQuickActions() {
    _quickActions.initialize((type) {
      if (type == 'add_expense') {
        setState(() => _currentTab = 0);
        WidgetsBinding.instance.addPostFrameCallback((_) => _openQuickCategoryPicker());
      }
    });
    _quickActions.setShortcutItems([
      ShortcutItem(type: 'add_expense', localizedTitle: tr('quick_add_title'), icon: 'ic_launcher'),
    ]);
  }

  // ---------- Перевод, валюта, цветовая палитра ----------

  String tr(String key) => AppStrings.t(_lang, key);

  /// Реальная тёмная/светлая тема с учётом режима "как в системе".
  bool get _isDark {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'light') return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

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
    return GoogleFonts.spaceGrotesk(fontSize: size * _fontScale, fontWeight: weight, color: color ?? ink);
  }

  TextStyle _body({double size = 13, FontWeight weight = FontWeight.w500, Color? color}) {
    return GoogleFonts.plusJakartaSans(fontSize: size * _fontScale, fontWeight: weight, color: color ?? ink);
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

  /// Сумма трат текущего календарного месяца — используется для проверки
  /// лимита, независимо от того, какой период выбран для отображения.
  double get _currentMonthTotal {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);
  }

  Category _categoryFor(String id) {
    return _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => _categories.last,
    );
  }

  // ---------- Действия ----------

  void _addExpense(Category cat, double amount, DateTime date, String note) {
    final prevMonthTotal = _currentMonthTotal;
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
    _checkLimitThresholds(prevMonthTotal);
  }

  /// Сравнивает сумму месяца до и после новой траты — уведомление
  /// срабатывает только один раз, ровно в момент пересечения порога.
  void _checkLimitThresholds(double prevTotal) {
    final limit = _monthlyLimit;
    if (limit == null || limit <= 0) return;

    final newTotal = _currentMonthTotal;
    final prevPct = prevTotal / limit;
    final newPct = newTotal / limit;

    if (prevPct < 1.0 && newPct >= 1.0) {
      AppNotifications.showLimitExceeded(
        title: tr('notif_exceeded_title'),
        body: tr('notif_exceeded_body'),
      );
    } else if (prevPct < 0.8 && newPct >= 0.8) {
      AppNotifications.showLimitWarning(
        title: tr('notif_warning_title'),
        body: tr('notif_warning_body'),
      );
    }
  }

  /// Общий помощник: показывает снекбар "Удалено — Отменить" на несколько секунд.
  void _showUndoSnackbar(VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr('deleted_undo_text')),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: tr('undo'), onPressed: onUndo),
      ),
    );
  }

  void _deleteExpense(Expense e) {
    setState(() => _expenses.remove(e));
    AppStorage.saveExpenses(_expenses);
    _showUndoSnackbar(() {
      setState(() {
        _expenses.add(e);
        _expenses.sort((a, b) => b.date.compareTo(a.date));
      });
      AppStorage.saveExpenses(_expenses);
    });
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

  // ---------- Действия: копилка ----------

  double get _savingsTotal =>
      _savingsContributions.fold(0.0, (s, c) => s + c.amount);

  void _setSavingsGoal(String name, double target) {
    setState(() {
      _savingsGoal = SavingsGoal(
        name: name,
        targetAmount: target,
        createdAt: DateTime.now(),
      );
    });
    AppStorage.saveSavingsGoal(_savingsGoal);
  }

  void _deleteSavingsGoal() {
    setState(() {
      _savingsGoal = null;
      _savingsContributions.clear();
    });
    AppStorage.saveSavingsGoal(null);
    AppStorage.saveSavingsContributions(_savingsContributions);
  }

  void _addSavingsContribution(double amount, DateTime date, String note) {
    setState(() {
      _savingsContributions.add(SavingsContribution(amount: amount, date: date, note: note));
      _savingsContributions.sort((a, b) => b.date.compareTo(a.date));
    });
    AppStorage.saveSavingsContributions(_savingsContributions);
  }

  void _deleteSavingsContribution(SavingsContribution c) {
    setState(() => _savingsContributions.remove(c));
    AppStorage.saveSavingsContributions(_savingsContributions);
    _showUndoSnackbar(() {
      setState(() {
        _savingsContributions.add(c);
        _savingsContributions.sort((a, b) => b.date.compareTo(a.date));
      });
      AppStorage.saveSavingsContributions(_savingsContributions);
    });
  }

  // ---------- Действия: долги ----------

  List<Debt> get _visibleDebts => _debts
      .where((d) => d.isOwedToMe == (_debtsView == 'owed_to_me'))
      .toList();

  double get _visibleDebtsTotal =>
      _visibleDebts.fold(0.0, (s, d) => s + d.amount);

  void _addDebt(String personName, double amount, DateTime date, String note) {
    setState(() {
      _debts.add(Debt(
        personName: personName,
        amount: amount,
        date: date,
        note: note,
        isOwedToMe: _debtsView == 'owed_to_me',
      ));
      _debts.sort((a, b) => b.date.compareTo(a.date));
    });
    AppStorage.saveDebts(_debts);
  }

  void _deleteDebt(Debt d) {
    setState(() => _debts.remove(d));
    AppStorage.saveDebts(_debts);
    _showUndoSnackbar(() {
      setState(() {
        _debts.add(d);
        _debts.sort((a, b) => b.date.compareTo(a.date));
      });
      AppStorage.saveDebts(_debts);
    });
  }

  // ---------- UI: модалка добавления траты ----------

  void _openQuickCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('quick_add_title'), style: _display(size: 16)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories.map((cat) {
                  return SizedBox(
                    width: _gridItemWidth(context),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openAddSheet(cat);
                        },
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
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

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

  // ---------- UI: выбор размера шрифта ----------

  void _openFontSizeSheet() {
    const options = [0.9, 1.0, 1.2];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final labels = [tr('font_small'), tr('font_medium'), tr('font_large')];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr('font_size_title'), style: _display(size: 15)),
                ),
              ),
              ...List.generate(options.length, (i) {
                final scale = options[i];
                final selected = (_fontScale - scale).abs() < 0.01;
                return ListTile(
                  title: Text(
                    labels[i],
                    style: _body(
                      color: ink,
                      weight: selected ? FontWeight.w800 : FontWeight.w500,
                      size: 13 + i * 2,
                    ),
                  ),
                  trailing: selected ? Icon(Icons.check_rounded, color: ink) : null,
                  onTap: () {
                    setState(() => _fontScale = scale);
                    AppStorage.saveFontScale(scale);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI: выбор темы ----------

  void _openThemeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final options = ['system', 'light', 'dark'];
        final icons = [Icons.brightness_auto_rounded, Icons.light_mode_rounded, Icons.dark_mode_rounded];
        final labels = [tr('theme_system'), tr('theme_light'), tr('theme_dark')];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr('theme_title'), style: _display(size: 15)),
                ),
              ),
              ...List.generate(options.length, (i) {
                final selected = _themeMode == options[i];
                return ListTile(
                  leading: Icon(icons[i], color: selected ? ink : inkSoft, size: 20),
                  title: Text(
                    labels[i],
                    style: _body(color: ink, weight: selected ? FontWeight.w800 : FontWeight.w500),
                  ),
                  trailing: selected ? Icon(Icons.check_rounded, color: ink) : null,
                  onTap: () {
                    setState(() => _themeMode = options[i]);
                    AppStorage.saveThemeMode(options[i]);
                    Navigator.pop(ctx);
                  },
                );
              }),
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

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildHeader(),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _buildExpensesTab(),
                      _buildSavingsTab(),
                      _buildDebtsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    Widget navItem(int index, IconData icon, String label) {
      final selected = _currentTab == index;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _currentTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: selected ? ink : inkFaint),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: _body(
                    size: 10.5,
                    weight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? ink : inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: panelBorder),
        ),
        child: Row(
          children: [
            navItem(0, Icons.receipt_long_rounded, tr('nav_expenses')),
            navItem(1, Icons.savings_rounded, tr('nav_savings')),
            navItem(2, Icons.handshake_rounded, tr('nav_debts')),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesTab() {
    final total = _total;
    final totalsMap = _totalsByCategory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
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
    Widget compactIcon({required VoidCallback onPressed, required Widget icon}) {
      return IconButton(
        onPressed: onPressed,
        icon: icon,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        visualDensity: VisualDensity.compact,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            tr('app_title'),
            style: _display(size: 19),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            compactIcon(
              onPressed: _openCurrencySheet,
              icon: Text(_currency.symbol, style: _display(size: 15, color: inkSoft)),
            ),
            compactIcon(
              onPressed: _openLanguageSheet,
              icon: Text(AppStrings.languageFlag(_lang), style: const TextStyle(fontSize: 16)),
            ),
            compactIcon(
              onPressed: _openFontSizeSheet,
              icon: Icon(Icons.text_fields_rounded, color: inkSoft, size: 18),
            ),
            compactIcon(
              onPressed: _openThemeSheet,
              icon: Icon(_isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: inkSoft, size: 18),
            ),
            compactIcon(
              onPressed: _openLimitDialog,
              icon: Icon(Icons.tune_rounded, color: inkSoft, size: 18),
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

  // ==================== КОПИЛКА ====================

  Widget _buildSavingsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        if (_savingsGoal == null) _buildNoSavingsGoal() else _buildSavingsGoalContent(),
      ],
    );
  }

  Widget _buildNoSavingsGoal() {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: PiggyBankPainter(
                progress: 0,
                glassColor: Colors.white.withOpacity(_isDark ? 0.05 : 0.45),
                outlineColor: inkFaint,
                coinColor: const Color(0xFFE0A458),
                coinShineColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('savings_no_goal_text'), textAlign: TextAlign.center, style: _body(color: inkSoft)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => _openSetGoalSheet(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE0A458),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(tr('savings_set_goal'), style: _body(weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalContent() {
    final goal = _savingsGoal!;
    final saved = _savingsTotal;
    final progress = (saved / goal.targetAmount).clamp(0.0, 1.0);
    final reached = saved >= goal.targetAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: panelBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(goal.name, style: _display(size: 17), overflow: TextOverflow.ellipsis),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz_rounded, color: inkSoft),
                        color: sheetBg,
                        onSelected: (v) {
                          if (v == 'edit') _openSetGoalSheet(editing: true);
                          if (v == 'delete') _confirmDeleteGoal();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'edit', child: Text(tr('savings_edit_goal'), style: _body(color: ink))),
                          PopupMenuItem(value: 'delete', child: Text(tr('savings_delete_goal'), style: _body(color: ink))),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: PiggyBankPainter(
                        progress: progress,
                        glassColor: Colors.white.withOpacity(_isDark ? 0.05 : 0.45),
                        outlineColor: inkSoft,
                        coinColor: const Color(0xFFE0A458),
                        coinShineColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${saved.round()} / ${goal.targetAmount.round()} ${_currency.symbol}', style: _display(size: 19)),
                  const SizedBox(height: 2),
                  Text(
                    '${(progress * 100).round()}% ${tr('savings_saved_label')}',
                    style: _body(color: inkSoft, size: 12),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: fieldBg,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE0A458)),
                    ),
                  ),
                  if (reached) ...[
                    const SizedBox(height: 10),
                    Text('🎉 ${tr('savings_reached')}', style: _body(weight: FontWeight.w700, color: const Color(0xFFE0A458))),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openAddContributionSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0A458),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(tr('savings_add_contribution'), style: _body(weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(tr('savings_tips_title')),
        const SizedBox(height: 10),
        _buildSavingsTips(),
        if (_savingsContributions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle(tr('history')),
          const SizedBox(height: 8),
          _buildSavingsHistory(),
        ],
      ],
    );
  }

  Widget _buildSavingsTips() {
    final tips = [tr('savings_tip_1'), tr('savings_tip_2'), tr('savings_tip_3'), tr('savings_tip_4')];
    return Column(
      children: tips.map((tip) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: panelBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFE0A458)),
              const SizedBox(width: 10),
              Expanded(child: Text(tip, style: _body(color: inkSoft, size: 12.5))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSavingsHistory() {
    return Column(
      children: _savingsContributions.map((c) {
        final dateStr = '${c.date.day.toString().padLeft(2, '0')}.'
            '${c.date.month.toString().padLeft(2, '0')}';
        return Dismissible(
          key: ValueKey(c.hashCode),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteSavingsContribution(c),
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
                  decoration: BoxDecoration(color: const Color(0xFFE0A458).withOpacity(0.16), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.savings_rounded, color: Color(0xFFE0A458), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.note.isNotEmpty ? c.note : tr('savings_add_contribution'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body(color: ink, weight: FontWeight.w600, size: 13),
                      ),
                      Text(dateStr, style: _body(color: inkFaint, size: 11)),
                    ],
                  ),
                ),
                Text(
                  '+${c.amount.round()} ${_currency.symbol}',
                  style: _display(size: 13, weight: FontWeight.w600, color: const Color(0xFFE0A458)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openSetGoalSheet({bool editing = false}) {
    final nameCtrl = TextEditingController(text: editing ? _savingsGoal?.name ?? '' : '');
    final targetCtrl = TextEditingController(
      text: editing && _savingsGoal != null ? _savingsGoal!.targetAmount.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? tr('savings_edit_goal') : tr('savings_set_goal'), style: _display(size: 16)),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: _body(color: ink),
                  decoration: InputDecoration(
                    hintText: tr('savings_goal_name_hint'),
                    hintStyle: _body(color: inkFaint),
                    filled: true,
                    fillColor: fieldBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: _body(color: ink),
                  decoration: InputDecoration(
                    hintText: tr('savings_target_hint'),
                    hintStyle: _body(color: inkFaint),
                    filled: true,
                    fillColor: fieldBg,
                    suffixText: _currency.symbol,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0A458),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final target = double.tryParse(targetCtrl.text.replaceAll(',', '.'));
                      if (name.isEmpty || target == null || target <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('error_amount'))));
                        return;
                      }
                      _setSavingsGoal(name, target);
                      Navigator.pop(ctx);
                    },
                    child: Text(tr('save'), style: _body(weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteGoal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr('savings_delete_goal'), style: _display(size: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel'), style: _body(color: inkSoft)),
          ),
          TextButton(
            onPressed: () {
              _deleteSavingsGoal();
              Navigator.pop(ctx);
            },
            child: Text(tr('savings_delete_goal'), style: _body(color: const Color(0xFFD3705A), weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openAddContributionSheet() {
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('savings_add_contribution'), style: _display(size: 16)),
                    const SizedBox(height: 18),
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
                        hintText: tr('comment_optional'),
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
                            if (picked != null) setModalState(() => selectedDate = picked);
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
                          backgroundColor: const Color(0xFFE0A458),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('error_amount'))));
                            return;
                          }
                          _addSavingsContribution(amount, selectedDate, noteCtrl.text.trim());
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

  // ==================== ДОЛГИ ====================

  Color get _debtsAccentColor =>
      _debtsView == 'owed_to_me' ? const Color(0xFF7C9885) : const Color(0xFFD3705A);

  Widget _buildDebtsTab() {
    final list = _visibleDebts;
    final total = _visibleDebtsTotal;
    final accentColor = _debtsAccentColor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _buildDebtsPills(),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('debts_total'), style: _body(color: inkFaint, size: 11, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${total.round()} ${_currency.symbol}', style: _display(size: 28, color: accentColor)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openAddDebtSheet,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: Text(tr('debts_add_person'), style: _body(weight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text(
                _debtsView == 'owed_to_me' ? tr('debts_empty_owed') : tr('debts_empty_i_owe'),
                textAlign: TextAlign.center,
                style: _body(color: inkFaint, size: 13),
              ),
            ),
          )
        else
          ...list.map((d) => _debtRow(d, accentColor)),
      ],
    );
  }

  Widget _buildDebtsPills() {
    Widget pill(String key, String label) {
      final active = _debtsView == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _debtsView = key),
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
        pill('owed_to_me', tr('debts_owed_to_me')),
        pill('i_owe', tr('debts_i_owe')),
      ],
    );
  }

  Widget _debtRow(Debt d, Color accentColor) {
    final dateStr = '${d.date.day.toString().padLeft(2, '0')}.'
        '${d.date.month.toString().padLeft(2, '0')}';
    return Dismissible(
      key: ValueKey(d.hashCode),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteDebt(d),
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
              decoration: BoxDecoration(color: accentColor.withOpacity(0.16), borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.person_rounded, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.personName, style: _body(color: ink, weight: FontWeight.w700, size: 13.5)),
                  if (d.note.isNotEmpty)
                    Text(d.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: _body(color: inkFaint, size: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${d.amount.round()} ${_currency.symbol}', style: _display(size: 13, weight: FontWeight.w600, color: accentColor)),
                Text(dateStr, style: _body(color: inkFaint, size: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAddDebtSheet() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final accentColor = _debtsAccentColor;

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
                decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _debtsView == 'owed_to_me' ? tr('debts_owed_to_me') : tr('debts_i_owe'),
                      style: _display(size: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: _body(color: ink),
                      decoration: InputDecoration(
                        hintText: tr('debts_person_name_hint'),
                        hintStyle: _body(color: inkFaint),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: _body(color: ink),
                      decoration: InputDecoration(
                        hintText: tr('debts_amount_hint'),
                        hintStyle: _body(color: inkFaint),
                        filled: true,
                        fillColor: fieldBg,
                        suffixText: _currency.symbol,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      style: _body(color: ink),
                      decoration: InputDecoration(
                        hintText: tr('debts_note_hint'),
                        hintStyle: _body(color: inkFaint),
                        filled: true,
                        fillColor: fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            if (picked != null) setModalState(() => selectedDate = picked);
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
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('error_category_name'))));
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('error_amount'))));
                            return;
                          }
                          _addDebt(name, amount, selectedDate, noteCtrl.text.trim());
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
}
