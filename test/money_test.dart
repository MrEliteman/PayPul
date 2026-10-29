import 'package:flutter_test/flutter_test.dart';
import 'package:where_is_my_money/money.dart';

void main() {
  test('parseMinor accepts valid input', () {
    expect(parseMinor('12'), 1200);
    expect(parseMinor('12.5'), 1250);
    expect(parseMinor('12,05'), 1205);
    expect(parseMinor(' 0.01 '), 1);
    expect(parseMinor('1 234.56'), 123456);
  });

  test('parseMinor rejects invalid input', () {
    for (final s in ['', 'abc', '0', '0.00', '-5', '1.234', '1e5', '1.', '.5']) {
      expect(parseMinor(s), isNull, reason: s);
    }
  });

  test('no floating point drift', () {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += parseMinor('0.10')!;
    }
    expect(sum, 100);
  });

  test('formatMinor', () {
    expect(formatMinor(0), '0.00');
    expect(formatMinor(5), '0.05');
    expect(formatMinor(123456), '1\u00A0234.56');
    expect(formatMinor(-250), '-2.50');
    expect(minorToInput(1205), '12.05');
  });
}
