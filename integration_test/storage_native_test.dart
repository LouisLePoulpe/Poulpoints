// Run only on a disposable profile or emulator: this fixture replaces the app's test data.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/recurrence.dart';
import 'package:poulpoints/storage/task_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native migration, UI save and database reopen', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final old = Task(
      id: 'android-fixture',
      title: 'Migration Android',
      list: 'Personnel',
      dueDate: DateTime(2026, 11, 7, 14, 30),
      hasDueTime: true,
      recurrence: 'custom',
      recurrenceRule: const RecurrenceRule(
        unit: 'monthly',
        monthMode: 'ordinal',
      ),
      location: 'Paris',
      subtasks: const [Subtask(id: 'a', title: 'Étape', done: true)],
    );
    await prefs.setString('poulpoints_tasks_v1', jsonEncode([old.toJson()]));
    await prefs.setStringList('poulpoints_projects_v2', ['Personnel']);
    final repository = await TaskRepository.open();
    final initial = await repository.load(prefs);
    expect(initial.tasks.single.toJson(), old.toJson());
    await tester.pumpWidget(PoulpointsApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Migration Android'), findsOneWidget);
    await tester.tap(find.text('Nouvelle tâche'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Que faut-il faire ?'),
      'Créée sur Android',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    // The native transaction can finish after the last rendered frame.
    final saved = await repository.load(prefs);
    expect(saved.tasks.map((t) => t.title), contains('Créée sur Android'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await repository.close();
    final reopened = await TaskRepository.open();
    final loaded = await reopened.load(prefs);
    expect(loaded.tasks.length, 2);
    expect(loaded.tasks.first.location, 'Paris');
    expect(loaded.tasks.first.recurrenceRule!.weekday, 6);
    expect(prefs.getString('poulpoints_tasks_v1'), jsonEncode([old.toJson()]));
    await reopened.close();
  });
}
