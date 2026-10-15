import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/calendar_localizations.dart';

void main() {
  test(
    'French calendar supports both week starts without changing language',
    () async {
      final monday = await const PoulpointsCalendarDelegate(
        true,
      ).load(const Locale('fr'));
      final sunday = await const PoulpointsCalendarDelegate(
        false,
      ).load(const Locale('fr'));
      expect(monday.firstDayOfWeekIndex, 1);
      expect(sunday.firstDayOfWeekIndex, 0);
      expect(monday.cancelButtonLabel, 'Annuler');
      expect(sunday.cancelButtonLabel, 'Annuler');
      expect(reminderLabel(1440), '1 jour avant');
      expect(reminderLabel(60), '1 heure avant');
    },
  );
}
