import 'package:flutter/material.dart';

/// Одна категория трат.
/// Для встроенных категорий name/hint — это ключи перевода (nameKey/hintKey).
/// Для категорий, созданных пользователем, isCustom = true,
/// а название и подсказка хранятся напрямую в customName/customHint.
class Category {
  final String id;
  final IconData icon;
  final Color color;
  final bool isCustom;
  final String? nameKey;
  final String? hintKey;
  final String? customName;
  final String? customHint;

  const Category({
    required this.id,
    required this.icon,
    required this.color,
    this.isCustom = false,
    this.nameKey,
    this.hintKey,
    this.customName,
    this.customHint,
  });
}

/// Базовый набор категорий — рассчитан на разные возрасты и ситуации.
final List<Category> defaultCategories = [
  const Category(
    id: 'food',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFE0A458),
    nameKey: 'cat_food',
    hintKey: 'hint_food',
  ),
  const Category(
    id: 'transport',
    icon: Icons.directions_car_filled_rounded,
    color: Color(0xFF5C8DAE),
    nameKey: 'cat_transport',
    hintKey: 'hint_transport',
  ),
  const Category(
    id: 'fun',
    icon: Icons.local_movies_rounded,
    color: Color(0xFF9B7EDE),
    nameKey: 'cat_fun',
    hintKey: 'hint_fun',
  ),
  const Category(
    id: 'clothes',
    icon: Icons.checkroom_rounded,
    color: Color(0xFFD98E73),
    nameKey: 'cat_clothes',
    hintKey: 'hint_clothes',
  ),
  const Category(
    id: 'home',
    icon: Icons.home_rounded,
    color: Color(0xFF7C9885),
    nameKey: 'cat_home',
    hintKey: 'hint_home',
  ),
  const Category(
    id: 'health',
    icon: Icons.favorite_rounded,
    color: Color(0xFFD97DA0),
    nameKey: 'cat_health',
    hintKey: 'hint_health',
  ),
  const Category(
    id: 'subs',
    icon: Icons.subscriptions_rounded,
    color: Color(0xFF4FB0A5),
    nameKey: 'cat_subs',
    hintKey: 'hint_subs',
  ),
  const Category(
    id: 'beauty',
    icon: Icons.face_retouching_natural_rounded,
    color: Color(0xFFC98BAE),
    nameKey: 'cat_beauty',
    hintKey: 'hint_beauty',
  ),
  const Category(
    id: 'study',
    icon: Icons.school_rounded,
    color: Color(0xFFCBB26A),
    nameKey: 'cat_study',
    hintKey: 'hint_study',
  ),
  const Category(
    id: 'gifts',
    icon: Icons.card_giftcard_rounded,
    color: Color(0xFFD3705A),
    nameKey: 'cat_gifts',
    hintKey: 'hint_gifts',
  ),
  const Category(
    id: 'pets',
    icon: Icons.pets_rounded,
    color: Color(0xFF8CA3A6),
    nameKey: 'cat_pets',
    hintKey: 'hint_pets',
  ),
  const Category(
    id: 'other',
    icon: Icons.category_rounded,
    color: Color(0xFF9A9A94),
    nameKey: 'cat_other',
    hintKey: 'hint_other',
  ),
];

/// Иконки, доступные при создании своей категории.
const List<IconData> customCategoryIcons = [
  Icons.local_cafe_rounded,
  Icons.sports_soccer_rounded,
  Icons.menu_book_rounded,
  Icons.flight_rounded,
  Icons.music_note_rounded,
  Icons.brush_rounded,
  Icons.build_rounded,
  Icons.child_care_rounded,
  Icons.local_hospital_rounded,
  Icons.savings_rounded,
  Icons.sports_esports_rounded,
  Icons.spa_rounded,
];

/// Цвета, доступные при создании своей категории.
const List<Color> customCategoryColors = [
  Color(0xFFE0A458),
  Color(0xFF5C8DAE),
  Color(0xFF9B7EDE),
  Color(0xFFD98E73),
  Color(0xFF7C9885),
  Color(0xFFD97DA0),
  Color(0xFF4FB0A5),
  Color(0xFFC98BAE),
  Color(0xFFCBB26A),
  Color(0xFFD3705A),
  Color(0xFF8CA3A6),
  Color(0xFF9A9A94),
];

/// Одна запись о трате.
class Expense {
  final double amount;
  final DateTime date;
  final String categoryId;
  final String note;

  Expense({
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.note,
  });
}

/// Цель накопления (копилка). В приложении одна активная цель за раз.
class SavingsGoal {
  final String name;
  final double targetAmount;
  final DateTime createdAt;

  SavingsGoal({
    required this.name,
    required this.targetAmount,
    required this.createdAt,
  });
}

/// Один взнос в копилку.
class SavingsContribution {
  final double amount;
  final DateTime date;
  final String note;

  SavingsContribution({
    required this.amount,
    required this.date,
    required this.note,
  });
}

/// Запись долга. isOwedToMe=true — "мне должны", false — "я должен".
class Debt {
  final String personName;
  final double amount;
  final DateTime date;
  final String note;
  final bool isOwedToMe;

  Debt({
    required this.personName,
    required this.amount,
    required this.date,
    required this.note,
    required this.isOwedToMe,
  });
}
