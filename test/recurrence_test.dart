import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/recurrence.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/task_editor.dart';

void main() {
  test('Every two days across year boundary preserves time', () {
    expect(
      const RecurrenceRule(interval: 2).next(DateTime(2026, 12, 31, 17, 45)),
      DateTime(2027, 1, 2, 17, 45),
    );
  });
  test('Monday Tuesday and every two weeks', () {
    const rule = RecurrenceRule(unit: 'weekly', days: [2, 1], interval: 2);
    expect(rule.next(DateTime(2026, 10, 12, 9)), DateTime(2026, 10, 13, 9));
    expect(rule.next(DateTime(2026, 10, 13, 9)), DateTime(2026, 10, 26, 9));
    expect(
      rule.next(DateTime(2026, 10, 12), inclusive: true),
      DateTime(2026, 10, 12),
    );
  });
  test('First Saturday and last weekday, including initial alignment', () {
    const rule = RecurrenceRule(
      unit: 'monthly',
      monthMode: 'ordinal',
      ordinal: 1,
      weekday: 6,
    );
    expect(rule.next(DateTime(2026, 10, 13, 15)), DateTime(2026, 11, 7, 15));
    expect(rule.next(DateTime(2026, 11, 7, 15)), DateTime(2026, 12, 5, 15));
    expect(
      rule.next(DateTime(2026, 11, 7), inclusive: true),
      DateTime(2026, 11, 7),
    );
    expect(
      const RecurrenceRule(
        unit: 'monthly',
        monthMode: 'ordinal',
        ordinal: -1,
        weekday: 1,
      ).next(DateTime(2026, 10, 1)),
      DateTime(2026, 10, 26),
    );
  });
  test('Monthly interval and day 31 retain original rule after February', () {
    const rule = RecurrenceRule(unit: 'monthly', monthDay: 31);
    final february = rule.next(DateTime(2028, 1, 31));
    expect(february, DateTime(2028, 2, 29));
    expect(rule.next(february), DateTime(2028, 3, 31));
    expect(
      const RecurrenceRule(
        unit: 'monthly',
        interval: 3,
        monthDay: 15,
      ).next(DateTime(2026, 11, 15)),
      DateTime(2027, 2, 15),
    );
  });
  test('Task JSON and updates retain rule and advance occurrence', () {
    const rule = RecurrenceRule(unit: 'weekly', days: [1, 2]);
    final task = Task(
      id: 'a',
      title: 'Test',
      list: 'Personnel',
      recurrence: 'custom',
      recurrenceRule: rule,
      dueDate: DateTime(2026, 10, 12, 10),
      hasDueTime: true,
    );
    final restored = Task.fromJson(
      jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
    ).copyWith(notes: 'Note');
    expect(restored.recurrenceRule!.toJson(), rule.toJson());
    expect(completeTask(restored, true).dueDate, DateTime(2026, 10, 13, 10));
    expect(
      () => RecurrenceRule.fromJson({...rule.toJson(), 'interval': 0}),
      throwsFormatException,
    );
  });
  testWidgets('Custom monthly rule saves and reopens on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Task? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Task>(
                  context: context,
                  builder: (_) => TaskEditor(
                    existing:
                        result ??
                        Task(
                          id: 'a',
                          title: 'Samedi',
                          list: 'Personnel',
                          dueDate: DateTime(2026, 10, 13),
                        ),
                    lists: const ['Personnel'],
                    initialList: 'Personnel',
                  ),
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).last);
      await tester.pumpAndSettle();
    }

    await tapText('Ouvrir');
    await tapText('Aucune');
    await tapText('Personnalisée…');
    await tapText('Jours');
    await tapText('Mois');
    final monthly = find.widgetWithText(
      DropdownButtonFormField<String>,
      'Règle mensuelle',
    );
    await tester.ensureVisible(monthly);
    await tester.pumpAndSettle();
    await tester.tap(monthly);
    await tester.pumpAndSettle();
    await tapText('Jour de la semaine');
    await tapText('Enregistrer');
    expect(result!.recurrenceRule!.label, 'Chaque mois, le premier samedi');
    expect(result!.dueDate, DateTime(2026, 11, 7));
    await tapText('Ouvrir');
    await tester.ensureVisible(find.text('Chaque mois, le premier samedi'));
    expect(find.text('Chaque mois, le premier samedi'), findsOneWidget);
    await tapText('Annuler');
    expect(tester.takeException(), isNull);
  });
}
