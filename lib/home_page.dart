import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'donut_painter.dart';

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
        hint: 'своя категория',
        isCustom: true,
      ));
    });
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
                decoration: const BoxDecoration(
                  color: Color(0xFF232427),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                        fontSize: 30,
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
                              const SnackBar(content: Text('Введи сумму больше нуля')),
                            );
                            return;
                          }
                          _addExpense(cat, amount, selectedDate, noteCtrl.text.trim());
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Добавить',
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
                decoration: const BoxDecoration(
                  color: Color(0xFF232427),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Новая категория',
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
                        hintText: 'название категории',
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
                    Text('Иконка', style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12)),
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
                              color: selected
                                  ? chosenColor.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: selected
                                  ? Border.all(color: chosenColor, width: 1.5)
                                  : null,
                            ),
                            child: Icon(icon, color: Colors.white70, size: 20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Цвет', style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12)),
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
                              border: selected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
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
                              const SnackBar(content: Text('Введи название категории')),
                            );
                            return;
                          }
                          _addCustomCategory(name, chosenIcon, chosenColor);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Создать категорию',
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
        backgroundColor: const Color(0xFF232427),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Лимит на месяц', style: GoogleFonts.unbounded(color: Colors.white, fontSize: 15)),
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
            child: Text('Отмена', style: GoogleFonts.manrope(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              setState(() => _monthlyLimit = (v != null && v > 0) ? v : null);
              Navigator.pop(ctx);
            },
            child: Text('Сохранить', style: GoogleFonts.manrope(color: Colors.white)),
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
      backgroundColor: const Color(0xFF1B1C1E),
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
                _buildSectionTitle('ДОБАВИТЬ ТРАТУ'),
                const SizedBox(height: 10),
                _buildCategoryGrid(),
                const SizedBox(height: 24),
                _buildSectionTitle('ИСТОРИЯ'),
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
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.9),
                radius: 1.3,
                colors: [
                  const Color(0xFF26282A),
                  const Color(0xFF1B1C1E),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -70,
          right: -50,
          child: _softBlob(220, const Color(0xFF33352F)),
        ),
        Positioned(
          bottom: 60,
          left: -60,
          child: _softBlob(200, const Color(0xFF2C3230)),
        ),
      ],
    );
  }

  Widget _softBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.45), color.withOpacity(0.0)],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Мои траты',
          style: GoogleFonts.unbounded(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: _openLimitDialog,
          icon: const Icon(Icons.tune_rounded, color: Colors.white60),
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
              color: active ? Colors.white : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: active ? const Color(0xFF1B1C1E) : Colors.white60,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('week', 'Неделя'),
        pill('month', 'Месяц'),
        pill('all', 'Всё время'),
      ],
    );
  }

  Widget _buildHeroCard(double total, Map<String, double> totalsMap) {
    final entries = totalsMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final segments = entries
        .map((e) => MapEntry(_categoryFor(e.key).color, e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                  painter: DonutPainter(segments: segments),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ПОТРАЧЕНО',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.round()}',
                      style: GoogleFonts.unbounded(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '₼',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.white38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Icon(cat.icon, size: 13, color: cat.color),
                        const SizedBox(width: 6),
                        Text(
                          '$pct%',
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
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
                  ? 'Лимит превышен'
                  : 'Осталось ${(limit - total).round()} ₼',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12),
            ),
            Text(
              'из ${limit.round()} ₼',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: Colors.white.withOpacity(0.08),
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
    final topCatName = _topCategory;
    final topCat = topCatName != null ? _categoryFor(topCatName) : null;

    Widget statCard(String label, String value, {IconData? icon, Color? color}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null)
                Icon(icon, size: 16, color: color ?? Colors.white54),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.unbounded(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.manrope(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        statCard('В среднем в день', '${avgPerDay.round()} ₼'),
        const SizedBox(width: 10),
        statCard(
          'Больше всего',
          topCat?.name ?? '—',
          icon: topCat?.icon,
          color: topCat?.color,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: Colors.white38,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
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

  Widget _categoryButton(Category cat) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 10 * 3) / 4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openAddSheet(cat),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.045),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(height: 7),
                Text(
                  cat.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                  ),
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
      width: (MediaQuery.of(context).size.width - 16 * 2 - 10 * 3) / 4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openNewCategorySheet,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white54, size: 18),
                ),
                const SizedBox(height: 7),
                Text(
                  'Своя',
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                  ),
                ),
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
      style: GoogleFonts.manrope(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Поиск по категории или комментарию',
        hintStyle: GoogleFonts.manrope(color: Colors.white30, fontSize: 13.5),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.045),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
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
            'Пока пусто — выбери категорию выше, чтобы добавить первую трату.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: list.map((e) {
        final cat = _categoryFor(e.categoryName);
        final dateStr = '${e.date.day.toString().padLeft(2, '0')}.'
            '${e.date.month.toString().padLeft(2, '0')}';
        return Dismissible(
          key: ValueKey(e.hashCode),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteExpense(e),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 18),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      if (e.note.isNotEmpty)
                        Text(
                          e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(color: Colors.white38, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${e.amount.round()} ₼',
                      style: GoogleFonts.unbounded(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.manrope(color: Colors.white30, fontSize: 11),
                    ),
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
