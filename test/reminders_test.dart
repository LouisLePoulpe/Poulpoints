import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/task_editor.dart';
import 'package:poulpoints/integration/projection.dart';
import 'package:poulpoints/storage/task_repository.dart';

void main() {
  Task task({int? reminder = 15, bool done = false}) => Task(
    id: 'r',
    title: 'Rappel',
    list: 'Personnel',
    dueDate: DateTime(2027, 1, 2, 10),
    hasDueTime: true,
    reminderMinutes: reminder,
    done: done,
    updatedAt: 42,
  );
  test('Reminder survives storage and legacy tasks default to no reminder', () {
    final t = task();
    final loaded = TaskSnapshot.fromJson(
      TaskSnapshot(tasks: [t], projects: ['Personnel'], deleted: {}).toJson(),
    );
    expect(loaded.tasks.single.reminderMinutes, 15);
    final json = t.toJson()..remove('reminderMinutes');
    expect(Task.fromJson(json).reminderMinutes, isNull);
    expect(t.copyWith(removeDueDate: true).reminderMinutes, isNull);
    expect(t.copyWith(removeReminder: true).reminderMinutes, isNull);
  });
  test(
    'Projection schedules offset, omits completed tasks and keeps revision',
    () {
      final t = task();
      final rows = projectTasks([t, task(done: true)])['tasks'] as List;
      expect(rows.length, 1);
      expect(
        rows.single['remindAt'],
        DateTime(2027, 1, 2, 9, 45).millisecondsSinceEpoch,
      );
      expect(rows.single['revision'], '42');
      expect(
        projectTasks([task(reminder: null)])['tasks'][0]['remindAt'],
        isNull,
      );
    },
  );
  test('Completing recurring task advances reminder and clears subtasks', () {
    final t = task().copyWith(
      recurrence: 'daily',
      subtasks: [const Subtask(id: 's', title: 'Étape', done: true)],
    );
    final next = completeTask(t, true);
    expect(next.reminderMinutes, 15);
    expect(next.dueDate, DateTime(2027, 1, 3, 10));
    expect(next.subtasks.single.done, false);
    expect(
      projectTasks([next])['tasks'][0]['remindAt'],
      DateTime(2027, 1, 3, 9, 45).millisecondsSinceEpoch,
    );
  });
  test('Invalid imported reminders are refused without dropping fields', () {
    for (final reminder in [-1, '15', 525601]) {
      expect(
        () => TaskSnapshot.fromJson({
          'schemaVersion': 3,
          'tasks': [
            {...task().toJson(), 'reminderMinutes': reminder},
          ],
          'projects': ['Personnel'],
          'deleted': {},
        }),
        throwsFormatException,
      );
    }
  });
  testWidgets('Reminder can be selected, saved and disabled in editor', (
    tester,
  ) async {
    Task? saved;
    Future<void> open(Task t) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showDialog<Task>(
                    context: context,
                    builder: (_) => TaskEditor(
                      existing: t,
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
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
    }

    await open(task());
    await tester.ensureVisible(find.text('15 minutes avant'));
    await tester.tap(find.text('15 minutes avant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 heure avant').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved!.reminders, [60]);
    expect(find.text('Aucun rappel'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await open(saved!);
    final addReminder = find.ancestor(
      of: find.text('Ajouter un rappel'),
      matching: find.byType(DropdownButtonFormField<int>),
    );
    await tester.ensureVisible(addReminder);
    await tester.pumpAndSettle();
    await tester.tap(addReminder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 jour avant').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved!.reminders, [60, 1440]);
    await tester.pumpWidget(const SizedBox());
    await open(saved!);
    await tester.ensureVisible(find.byTooltip('Supprimer ce rappel').last);
    await tester.tap(find.byTooltip('Supprimer ce rappel').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Supprimer ce rappel'));
    await tester.tap(find.byTooltip('Supprimer ce rappel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved!.reminders, isEmpty);
  });
}
