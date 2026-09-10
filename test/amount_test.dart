import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_lite_wallet/src/amount.dart';

void main() {
  test('parses QTC without floating point loss', () {
    expect(parseQtc('44.81'), BigInt.parse('44810000000000'));
    expect(parseQtc('0.000000000001'), BigInt.one);
    expect(parseQtc('1'), plancksPerQtc);
  });

  test('rejects zero, negatives and excessive precision', () {
    for (final value in ['0', '-1', '1.0000000000001', 'abc']) {
      expect(() => parseQtc(value), throwsFormatException, reason: value);
    }
  });

  test('formats plancks as QTC', () {
    expect(formatQtc(BigInt.parse('44810000000000')), '44.81');
    expect(formatQtc(BigInt.one), '0.000000000001');
  });
}
