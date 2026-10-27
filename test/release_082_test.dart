import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/app_metadata.dart';
import 'package:poulpoints/deadline_status.dart';
import 'package:poulpoints/integration/projection.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/storage/task_repository.dart';
import 'package:poulpoints/task_editor.dart';

Task fixture(DateTime due, {bool done = false, bool withTime = false}) => Task(
  id: 'deadline',
  title: 'Échéance',
  list: 'Personnel',
  dueDate: due,
  hasDueTime: withTime,
  done: done,
  reminderOffsets: const [0],
);

void main() {
  test('Date-only reminder is scheduled for midnight and survives JSON', () {
    final due = DateTime(2027, 5, 2);
    final task = fixture(due);
    final projection = (projectTasks([task])['tasks'] as List).single as Map;
    expect(projection['remindAt'], due.millisecondsSinceEpoch);
    expect(projection['hasDueTime'], false);
    final saved = TaskSnapshot.fromJson(
      TaskSnapshot(tasks: [task], projects: ['Personnel'], deleted: {}).toJson(),
    );
    expect(saved.tasks.single.reminders, [0]);
    expect(saved.tasks.single.hasDueTime, false);
  });

  test('Existing date-only task with no reminder remains opted-out', () {
    final old = fixture(DateTime(2027, 5, 2)).copyWith(removeReminder: true);
    expect(old.reminders, isEmpty);
    expect((projectTasks([old])['tasks'] as List).single['remindAt'], isNull);
    expect(Task.fromJson(old.toJson()).reminders, isEmpty);
  });

  test('Overdue marks same day and calendar days across DST', () {
    final due = DateTime(2027, 3, 27, 10);
    final task = fixture(due, withTime: true);
    expect(overdueLabel(task, DateTime(2027, 3, 27, 9)), isNull);
    expect(overdueLabel(task, DateTime(2027, 3, 27, 10, 1)), 'En retard');
    // The Paris DST transition means this is not necessarily 48 elapsed hours.
    expect(overdueLabel(task, DateTime(2027, 3, 29, 11)), 'J+2');
    expect(overdueLabel(fixture(due, done: true), DateTime(2027, 3, 29)), isNull);
    expect(overdueLabel(const Task(id: 'a', title: 'Sans date', list: 'Personnel'),
        DateTime(2027, 3, 29)), isNull);
  });

  test('Version displayed in About corresponds to source release', () {
    expect(poulpointsFullVersion, '0.8.5+26');
  });

  testWidgets('New date defaults to on-time reminder even without hour', (tester) async {
    Task? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await Navigator.of(context).push<Task>(
              MaterialPageRoute(builder: (_) => const TaskEditor(
                lists: ['Personnel'],
                initialList: 'Personnel',
                fullScreen: true,
              )),
            );
          },
          child: const Text('Ouvrir'),
        ),
      )),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Que faut-il faire ?'), 'Test');
    await tester.ensureVisible(find.text('Définir une échéance'));
    await tester.tap(find.text('Définir une échéance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.text('À l’échéance'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.hasDueTime, false);
    expect(result!.dueDate!.hour, 0);
    expect(result!.dueDate!.minute, 0);
    expect(result!.reminders, [0]);
  });
}
