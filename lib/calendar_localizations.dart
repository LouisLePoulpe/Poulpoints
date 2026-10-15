import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

class CalendarLocalizations extends MaterialLocalizationFr {
  CalendarLocalizations(this.monday)
    : super(
        fullYearFormat: DateFormat.y('fr'),
        compactDateFormat: DateFormat.yMd('fr'),
        shortDateFormat: DateFormat.yMMMd('fr'),
        mediumDateFormat: DateFormat.MMMEd('fr'),
        longDateFormat: DateFormat.yMMMMEEEEd('fr'),
        yearMonthFormat: DateFormat.yMMMM('fr'),
        shortMonthDayFormat: DateFormat.MMMd('fr'),
        decimalFormat: NumberFormat.decimalPattern('fr'),
        twoDigitZeroPaddedFormat: NumberFormat('00', 'fr'),
      );
  final bool monday;
  @override
  int get firstDayOfWeekIndex => monday ? 1 : 0;
}

class PoulpointsCalendarDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const PoulpointsCalendarDelegate(this.monday);
  final bool monday;
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fr';
  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('fr'));
    return CalendarLocalizations(monday);
  }

  @override
  bool shouldReload(PoulpointsCalendarDelegate old) => old.monday != monday;
}

String reminderLabel(int minutes) {
  if (minutes == 0) return 'À l’échéance';
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return '$days jour${days > 1 ? 's' : ''} avant';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return '$hours heure${hours > 1 ? 's' : ''} avant';
  }
  return '$minutes minutes avant';
}
