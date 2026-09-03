import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'localization.dart';

/// Обёртка над shared_preferences — сохраняет настройки и данные
/// прямо на устройстве, чтобы при следующем запуске ничего не пришлось
/// настраивать заново.
class AppStorage {
  static const _kLang = 'app_lang';
  static const _kThemeMode = 'app_theme_mode'; // 'system' | 'light' | 'dark'
  static const _kCurrency = 'app_currency';
  static const _kLimit = 'app_limit';
  static const _kCustomCats = 'app_custom_categories';
  static const _kExpenses = 'app_expenses';
  static const _kFontScale = 'app_font_scale';
  static const _kSavingsGoal = 'app_savings_goal';
  static const _kSavingsContributions = 'app_savings_contributions';
  static const _kDebts = 'app_debts';

  // ---------- Сохранение ----------

  static Future<void> saveLang(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLang, lang.index);
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode);
  }

  static Future<void> saveCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, code);
  }

  static Future<void> saveLimit(double? limit) async {
    final prefs = await SharedPreferences.getInstance();
    if (limit != null) {
      await prefs.setDouble(_kLimit, limit);
    } else {
      await prefs.remove(_kLimit);
    }
  }

  static Future<void> saveFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScale, scale);
  }

  static Future<void> saveCustomCategories(List<Category> allCategories) async {
    final prefs = await SharedPreferences.getInstance();
    final customOnly = allCategories.where((c) => c.isCustom).toList();
    final list = customOnly
        .map((c) => {
              'id': c.id,
              'icon': c.icon.codePoint,
              'color': c.color.value,
              'name': c.customName,
            })
        .toList();
    await prefs.setString(_kCustomCats, jsonEncode(list));
  }

  static Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final list = expenses
        .map((e) => {
              'amount': e.amount,
              'date': e.date.toIso8601String(),
              'categoryId': e.categoryId,
              'note': e.note,
            })
        .toList();
    await prefs.setString(_kExpenses, jsonEncode(list));
  }

  static Future<void> saveSavingsGoal(SavingsGoal? goal) async {
    final prefs = await SharedPreferences.getInstance();
    if (goal == null) {
      await prefs.remove(_kSavingsGoal);
      return;
    }
    final map = {
      'name': goal.name,
      'target': goal.targetAmount,
      'createdAt': goal.createdAt.toIso8601String(),
    };
    await prefs.setString(_kSavingsGoal, jsonEncode(map));
  }

  static Future<void> saveSavingsContributions(List<SavingsContribution> list) async {
    final prefs = await SharedPreferences.getInstance();
    final data = list
        .map((c) => {
              'amount': c.amount,
              'date': c.date.toIso8601String(),
              'note': c.note,
            })
        .toList();
    await prefs.setString(_kSavingsContributions, jsonEncode(data));
  }

  static Future<void> saveDebts(List<Debt> debts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = debts
        .map((d) => {
              'personName': d.personName,
              'amount': d.amount,
              'date': d.date.toIso8601String(),
              'note': d.note,
              'isOwedToMe': d.isOwedToMe,
            })
        .toList();
    await prefs.setString(_kDebts, jsonEncode(list));
  }

  // ---------- Загрузка ----------

  static Future<AppLanguage> loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kLang);
    if (idx == null || idx < 0 || idx >= AppLanguage.values.length) {
      return AppLanguage.ru;
    }
    return AppLanguage.values[idx];
  }

  static Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kThemeMode) ?? 'system';
  }

  static Future<String> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrency) ?? 'az';
  }

  static Future<double?> loadLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kLimit);
  }

  static Future<double> loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kFontScale) ?? 1.0;
  }

  static Future<List<Category>> loadCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCustomCats);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Category(
          id: map['id'] as String,
          icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
          color: Color(map['color'] as int),
          isCustom: true,
          customName: map['name'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Expense>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kExpenses);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Expense(
          amount: (map['amount'] as num).toDouble(),
          date: DateTime.parse(map['date'] as String),
          categoryId: map['categoryId'] as String,
          note: map['note'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<SavingsGoal?> loadSavingsGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavingsGoal);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SavingsGoal(
        name: map['name'] as String,
        targetAmount: (map['target'] as num).toDouble(),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<SavingsContribution>> loadSavingsContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavingsContributions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return SavingsContribution(
          amount: (map['amount'] as num).toDouble(),
          date: DateTime.parse(map['date'] as String),
          note: map['note'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Debt>> loadDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDebts);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return Debt(
          personName: map['personName'] as String,
          amount: (map['amount'] as num).toDouble(),
          date: DateTime.parse(map['date'] as String),
          note: map['note'] as String? ?? '',
          isOwedToMe: map['isOwedToMe'] as bool,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
