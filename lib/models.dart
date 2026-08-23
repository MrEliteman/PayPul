import 'package:flutter/material.dart';

/// Одна категория трат: имя, иконка, цвет и подсказка для поля "комментарий".
class Category {
  final String name;
  final IconData icon;
  final Color color;
  final String hint;
  final bool isCustom;

  const Category({
    required this.name,
    required this.icon,
    required this.color,
    required this.hint,
    this.isCustom = false,
  });
}

/// Базовый набор категорий — рассчитан на разные возрасты и ситуации,
/// не только на молодёжные траты.
final List<Category> defaultCategories = [
  const Category(
    name: 'Еда',
    icon: Icons.restaurant_rounded,
    color: Color(0xFFE0A458),
    hint: 'например: шаурма, кофе, продукты',
  ),
  const Category(
    name: 'Транспорт',
    icon: Icons.directions_car_filled_rounded,
    color: Color(0xFF5C8DAE),
    hint: 'например: такси, бензин, автобус',
  ),
  const Category(
    name: 'Развлечения',
    icon: Icons.local_movies_rounded,
    color: Color(0xFF9B7EDE),
    hint: 'например: кино, игра, концерт',
  ),
  const Category(
    name: 'Одежда',
    icon: Icons.checkroom_rounded,
    color: Color(0xFFD98E73),
    hint: 'например: кроссовки, куртка',
  ),
  const Category(
    name: 'Жильё',
    icon: Icons.home_rounded,
    color: Color(0xFF7C9885),
    hint: 'например: аренда, коммуналка',
  ),
  const Category(
    name: 'Здоровье',
    icon: Icons.favorite_rounded,
    color: Color(0xFFD97DA0),
    hint: 'например: аптека, врач',
  ),
  const Category(
    name: 'Подписки',
    icon: Icons.subscriptions_rounded,
    color: Color(0xFF4FB0A5),
    hint: 'например: музыка, стриминг',
  ),
  const Category(
    name: 'Красота',
    icon: Icons.face_retouching_natural_rounded,
    color: Color(0xFFC98BAE),
    hint: 'например: стрижка, косметика',
  ),
  const Category(
    name: 'Учёба',
    icon: Icons.school_rounded,
    color: Color(0xFFCBB26A),
    hint: 'например: курсы, книги',
  ),
  const Category(
    name: 'Подарки',
    icon: Icons.card_giftcard_rounded,
    color: Color(0xFFD3705A),
    hint: 'например: другу, родным',
  ),
  const Category(
    name: 'Питомцы',
    icon: Icons.pets_rounded,
    color: Color(0xFF8CA3A6),
    hint: 'например: корм, ветеринар',
  ),
  const Category(
    name: 'Прочее',
    icon: Icons.category_rounded,
    color: Color(0xFF9A9A94),
    hint: 'что угодно ещё',
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

/// Цвета, доступные при создании своей категории (в тон общей палитре).
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
  final String categoryName;
  final String note;

  Expense({
    required this.amount,
    required this.date,
    required this.categoryName,
    required this.note,
  });
}
