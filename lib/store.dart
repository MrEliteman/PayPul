import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  List<Expense> _expenses = [];
  int? _limit;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  int? get monthlyLimit => _limit;

  void _load() {
    final raw = _prefs.getString('expenses');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _expenses = list
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _expenses = [];
      }
    }
    final lim = _prefs.getInt('limit');
    _limit = (lim != null && lim > 0) ? lim : null;
  }

  Future<void> _save() => _prefs.setString(
      'expenses', jsonEncode(_expenses.map((e) => e.toJson()).toList()));

  Future<void> add(Expense e) async {
    _expenses.add(e);
    notifyListeners();
    await _save();
  }

  Future<void> update(Expense e) async {
    final i = _expenses.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    _expenses[i] = e;
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _expenses.removeWhere((x) => x.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> setLimit(int? v) async {
    _limit = v;
    if (v == null) {
      await _prefs.remove('limit');
    } else {
      await _prefs.setInt('limit', v);
    }
    notifyListeners();
  }

  List<Expense> forMonth(int year, int month, {String? category}) {
    final l = _expenses
        .where((e) =>
            e.date.year == year &&
            e.date.month == month &&
            (category == null || e.category == category))
        .toList();
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  int totalForMonth(int year, int month) =>
      forMonth(year, month).fold(0, (s, e) => s + e.amount);
}
