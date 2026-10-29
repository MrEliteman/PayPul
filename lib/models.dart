const categoryKeys = ['food', 'transport', 'home', 'health', 'fun', 'other'];

class Expense {
  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
  });

  final String id;
  final int amount; // minor units
  final String description;
  final String category;
  final DateTime date;

  Expense copyWith({
    int? amount,
    String? description,
    String? category,
    DateTime? date,
  }) =>
      Expense(
        id: id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        date: date ?? this.date,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'description': description,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: j['amount'] as int,
        description: (j['description'] as String?) ?? '',
        category: categoryKeys.contains(j['category']) ? j['category'] as String : 'other',
        date: DateTime.parse(j['date'] as String),
      );
}
