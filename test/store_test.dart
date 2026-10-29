import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:where_is_my_money/models.dart';
import 'package:where_is_my_money/store.dart';

Expense ex(String id, int amount, DateTime d, [String cat = 'food']) =>
    Expense(id: id, amount: amount, description: id, category: cat, date: d);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('add, update, delete and monthly totals', () async {
    final s = AppStore(await SharedPreferences.getInstance());
    await s.add(ex('a', 1000, DateTime(2026, 10, 5)));
    await s.add(ex('b', 550, DateTime(2026, 10, 20), 'fun'));
    await s.add(ex('c', 999, DateTime(2026, 9, 30)));

    expect(s.totalForMonth(2026, 10), 1550);
    expect(s.forMonth(2026, 10, category: 'fun').length, 1);
    expect(s.forMonth(2026, 10).first.id, 'b'); // newest first

    await s.update(ex('a', 2000, DateTime(2026, 10, 5)));
    expect(s.totalForMonth(2026, 10), 2550);

    await s.delete('b');
    expect(s.totalForMonth(2026, 10), 2000);
    expect(s.totalForMonth(2026, 11), 0);
  });

  test('data and limit survive restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final s1 = AppStore(prefs);
    await s1.add(ex('a', 1234, DateTime(2026, 10, 5)));
    await s1.setLimit(50000);

    final s2 = AppStore(prefs);
    expect(s2.expenses.single.amount, 1234);
    expect(s2.monthlyLimit, 50000);

    await s2.setLimit(null);
    expect(AppStore(prefs).monthlyLimit, isNull);
  });

  test('corrupt storage does not crash', () async {
    SharedPreferences.setMockInitialValues({'expenses': 'not json'});
    final s = AppStore(await SharedPreferences.getInstance());
    expect(s.expenses, isEmpty);
  });
}
