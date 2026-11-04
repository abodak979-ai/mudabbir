import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

const _western = '0123456789';
const _eastern = '٠١٢٣٤٥٦٧٨٩';

String localizeDigits(String s, bool arabicDigits) {
  if (!arabicDigits) return s;
  final b = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    final i = _western.indexOf(c);
    b.write(i >= 0 ? _eastern[i] : c);
  }
  return b.toString();
}

/// Formats numbers, money and dates according to the user's language/numeral choice.
class Fmt {
  final bool ar;
  final bool arabicDigits;
  final bool hidden;
  const Fmt({required this.ar, required this.arabicDigits, this.hidden = false});

  String get currency => ar ? 'ريال' : 'SAR';

  String n(num v, {int decimals = 0}) {
    final f = NumberFormat.decimalPatternDigits(locale: 'en', decimalDigits: decimals);
    return localizeDigits(f.format(v), arabicDigits);
  }

  String money(num v, {bool withCurrency = true}) {
    if (hidden) return '••••';
    final s = n(v);
    return withCurrency ? '$s $currency' : s;
  }

  String pct(double ratio) => '${n(ratio * 100)}%';

  String date(DateTime d, {String pattern = 'd MMM'}) =>
      localizeDigits(DateFormat(pattern, ar ? 'ar' : 'en').format(d), arabicDigits);

  String hijri(DateTime d) {
    HijriCalendar.setLocal(ar ? 'ar' : 'en');
    final h = HijriCalendar.fromDate(d);
    return localizeDigits('${h.hDay} ${h.longMonthName} ${h.hYear}', arabicDigits);
  }
}
