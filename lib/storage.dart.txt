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
  static const _kDark = 'app_dark';
  static const _kCurrency = 'app_currency';
  static const _kLimit = 'app_limit';
  static const _kCustomCats = 'app_custom_categories';
  static const _kExpenses = 'app_expenses';

  // ---------- Сохранение ----------

  static Future<void> saveLang(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLang, lang.index);
  }

  static Future<void> saveDark(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, isDark);
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

  // ---------- Загрузка ----------

  static Future<AppLanguage> loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kLang);
    if (idx == null || idx < 0 || idx >= AppLanguage.values.length) {
      return AppLanguage.ru;
    }
    return AppLanguage.values[idx];
  }

  static Future<bool> loadDark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDark) ?? true;
  }

  static Future<String> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrency) ?? 'az';
  }

  static Future<double?> loadLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kLimit);
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
}
