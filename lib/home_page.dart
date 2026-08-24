import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'donut_painter.dart';
import 'translations.dart';
import 'glass_container.dart';

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

  @override
  void initState() {
    super.initState();
    _categories = List.of(defaultCategories);
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
      return e.categoryName.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q);
    }).toList();
  }

  double get _total => _filteredByPeriod.fold(0.0, (s, e) => s + e.amount);

  Map<String, double> get _totalsByCategory {
    final map = <String, double>{};
    for (final e in _filteredByPeriod) {
      map[e.categoryName] = (map[e.categoryName] ?? 0) + e.amount;
    }
    return map;
  }

  int get _daysInPeriod {
    if (_filteredByPeriod.isEmpty) return 1;
    final dates = _filteredByPeriod.map((e) =>
        DateTime(e.date.year, e.date.month, e.date.day)).toSet();
    return dates.length.clamp(1, 999);
  }

  String? get _topCategory {
    final totals = _totalsByCategory;
    if (totals.isEmpty) return null;
    return (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  Category _categoryFor(String name) {
    return _categories.firstWhere(
      (c) => c.name == name,
      orElse: () => _categories.last,
    );
  }

  // ---------- Действия ----------

  void _addExpense(Category cat, double amount, DateTime date, String note) {
    setState(() {
      _expenses.add(Expense(
        amount: amount,
        date: date,
        categoryName: cat.name,
        note: note,
      ));
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  void _deleteExpense(Expense e) {
    setState(() => _expenses.remove(e));
  }

  void _addCustomCategory(String name, IconData icon, Color color) {
    setState(() {
      _categories.add(Category(
        name: name,
        icon: icon,
        color: color,
        hint: AppTranslations.tr('custom_cat'),
        isCustom: true,
      ));
    });
  }

  // ---------- UI: выбор языка ----------

  void _openLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTranslations.tr('select_lang'),
          style: GoogleFonts.unbounded(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: AppTranslations.languages.entries.map((entry) {
              final isSelected = AppTranslations.currentLang == entry.key;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                title: Text(
                  entry.value,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C9885)) : null,
                onTap: () {
                  setState(() {
                    AppTranslations.currentLang = entry.key;
                  });
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: GlassContainer(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                opacity: 0.15,
                blur: 25,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: cat.color.withOpacity(0.2),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          cat.name,
                          style: GoogleFonts.unbounded(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.unbounded(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        suffixText: '  ₼',
                        suffixStyle: TextStyle(color: Colors.white38, fontSize: 20),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    TextField(
                      controller: noteCtrl,
                      style: GoogleFonts.manrope(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: cat.hint,
                        hintStyle: GoogleFonts.manrope(color: Colors.white38),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.white38),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.event_rounded, color: Colors.white38, size: 18),
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
                            style: GoogleFonts.manrope(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(AppTranslations.tr('enter_amount_err'))),
                            );
                            return;
                          }
                          _addExpense(cat, amount, selectedDate, noteCtrl.text.trim());
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          AppTranslations.tr('add'),
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                        ),
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

  // ---------- UI: создание категории ----------

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
              child: GlassContainer(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                opacity: 0.15,
                blur: 25,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.tr('new_cat'),
                      style: GoogleFonts.unbounded(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: GoogleFonts.manrope(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: AppTranslations.tr('cat_name'),
                        hintStyle: GoogleFonts.manrope(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(AppTranslations.tr('icon'), style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12)),
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
                              color: selected ? chosenColor.withOpacity(0.25) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: selected ? Border.all(color: chosenColor, width: 1.5) : null,
                            ),
                            child: Icon(icon, color: Colors.white70, size: 20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(AppTranslations.tr('color'), style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12)),
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
                              border: selected ? Border.all(color: Colors.white, width: 2) : null,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(AppTranslations.tr('enter_cat_err'))),
                            );
                            return;
                          }
                          _addCustomCategory(name, chosenIcon, chosenColor);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          AppTranslations.tr('create_cat'),
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                        ),
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
        backgroundColor: const Color(0xFF1E2026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.tr('limit_title'), style: GoogleFonts.unbounded(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.manrope(color: Colors.white),
          decoration: const InputDecoration(
            suffixText: '₼',
            suffixStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.tr('cancel'), style: GoogleFonts.manrope(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              setState(() => _monthlyLimit = (v != null && v > 0) ? v : null);
              Navigator.pop(ctx);
            },
            child: Text(AppTranslations.tr('save'), style: GoogleFonts.manrope(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------- Сборка экрана ----------

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final totalsMap = _totalsByCategory;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: Stack(
        children: [
          _buildNeoBackground(),
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
                _buildSectionTitle(AppTranslations.tr('add_expense_title')),
                const SizedBox(height: 10),
                _buildCategoryGrid(),
                const SizedBox(height: 24),
                _buildSectionTitle(AppTranslations.tr('history_title')),
                const SizedBox(height: 8),
                _buildSearchField(),
                const SizedBox(height: 12),
                _buildHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Переливающийся неоновый фон необанков
  Widget _buildNeoBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFF0F1015)),
        Positioned(
          top: -60,
          left: -40,
          child: _blurSpot(260, const Color(0xFF7C9885).withOpacity(0.3)),
        ),
        Positioned(
          top: 240,
         
