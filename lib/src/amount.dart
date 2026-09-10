const int qtcDecimals = 12;
final BigInt plancksPerQtc = BigInt.from(10).pow(qtcDecimals);

BigInt parseQtc(String input) {
  final value = input.trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,12}))?$').firstMatch(value);
  if (match == null) {
    throw const FormatException('请输入有效金额，最多 12 位小数');
  }

  final whole = BigInt.parse(match.group(1)!);
  final fractionText = (match.group(2) ?? '').padRight(qtcDecimals, '0');
  final fraction = fractionText.isEmpty ? BigInt.zero : BigInt.parse(fractionText);
  final result = whole * plancksPerQtc + fraction;
  if (result <= BigInt.zero) throw const FormatException('金额必须大于 0');
  return result;
}

String formatQtc(BigInt plancks, {int maxFractionDigits = qtcDecimals}) {
  final negative = plancks.isNegative;
  final absolute = plancks.abs();
  final whole = absolute ~/ plancksPerQtc;
  final remainder = absolute.remainder(plancksPerQtc);
  var fraction = remainder.toString().padLeft(qtcDecimals, '0');
  if (maxFractionDigits < qtcDecimals) fraction = fraction.substring(0, maxFractionDigits);
  fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  return '${negative ? '-' : ''}$whole${fraction.isEmpty ? '' : '.$fraction'}';
}
