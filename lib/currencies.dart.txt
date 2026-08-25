/// Одна валюта, привязанная к конкретному языку/региону приложения.
/// id совпадает с кодом соответствующего языка (AppLanguage) —
/// так каждый язык в приложении имеет свою "родную" валюту.
class Currency {
  final String id;
  final String code;
  final String symbol;
  final String flag;
  const Currency({
    required this.id,
    required this.code,
    required this.symbol,
    required this.flag,
  });
}

/// 10 валют — ровно по одной на каждый из 10 языков приложения.
const List<Currency> currencies = [
  Currency(id: 'ru', code: 'RUB', symbol: '₽', flag: '🇷🇺'),
  Currency(id: 'en', code: 'USD', symbol: '\$', flag: '🇺🇸'),
  Currency(id: 'az', code: 'AZN', symbol: '₼', flag: '🇦🇿'),
  Currency(id: 'tr', code: 'TRY', symbol: '₺', flag: '🇹🇷'),
  Currency(id: 'es', code: 'EUR', symbol: '€', flag: '🇪🇸'),
  Currency(id: 'fr', code: 'EUR', symbol: '€', flag: '🇫🇷'),
  Currency(id: 'de', code: 'EUR', symbol: '€', flag: '🇩🇪'),
  Currency(id: 'ar', code: 'SAR', symbol: '﷼', flag: '🇸🇦'),
  Currency(id: 'zh', code: 'CNY', symbol: '¥', flag: '🇨🇳'),
  Currency(id: 'pt', code: 'BRL', symbol: 'R\$', flag: '🇧🇷'),
];

Currency currencyById(String id) {
  return currencies.firstWhere(
    (c) => c.id == id,
    orElse: () => currencies.firstWhere((c) => c.id == 'az'),
  );
}
