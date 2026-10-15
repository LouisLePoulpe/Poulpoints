import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/task_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UiTestRepository repository;
  setUp(() async {
    repository = UiTestRepository(
      DatabaseHandle(await newDatabaseFactoryMemory().openDatabase('ui')),
    );
  });
  tearDown(() async {
    await repository.close();
  });
  test('Old JSON keeps priority, subtasks and date-only semantics', () {
    final task = Task.fromJson({
      'id': 'old',
      'title': 'Ancienne',
      'priority': true,
      'dueDate': '2026-10-13T00:00:00.000',
      'subtasks': [
        {'id': 's', 'title': 'Étape', 'done': true},
      ],
    });
    expect(task.priority, true);
    expect(task.location, '');
    expect(task.recurrence, 'none');
    expect(task.hasDueTime, false);
    expect(task.subtasks.single.done, true);
  });

  test('JSON and copyWith retain all new fields, including midnight', () {
    final task = Task(
      id: 't',
      title: 'RDV',
      list: 'Personnel',
      priority: true,
      dueDate: DateTime(2026, 10, 15, 0, 0),
      hasDueTime: true,
      location: 'Paris',
      recurrence: 'weekly',
      notes: 'Note',
      subtasks: const [Subtask(id: 's', title: 'Préparer', done: true)],
    );
    final decoded = Task.fromJson(
      jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), task.toJson());
    final edited = decoded.copyWith(title: 'RDV modifié');
    expect(edited.location, 'Paris');
    expect(edited.recurrence, 'weekly');
    expect(edited.hasDueTime, true);
    expect(edited.subtasks.single.done, true);
    expect(edited.updatedAt, greaterThan(0));
    expect(edited.copyWith(removeDueDate: true).hasDueTime, false);
    expect(formatDeadline(task.dueDate!, true), '15/10/2026 à 00:00');
  });

  test('Recurrences preserve clock time and reset subtasks', () {
    for (final entry in {
      'daily': DateTime(2028, 2, 1, 14, 35),
      'weekly': DateTime(2028, 2, 7, 14, 35),
      'monthly': DateTime(2028, 2, 29, 14, 35),
    }.entries) {
      final task = Task(
        id: 't',
        title: 'Répéter',
        list: 'Personnel',
        dueDate: DateTime(2028, 1, 31, 14, 35),
        recurrence: entry.key,
        hasDueTime: true,
        location: 'Maison',
        subtasks: const [Subtask(id: 's', title: 'Étape', done: true)],
      );
      final next = completeTask(task, true);
      expect(next.dueDate, entry.value);
      expect(next.done, false);
      expect(next.subtasks.single.done, false);
      expect(next.location, 'Maison');
      expect(next.hasDueTime, true);
    }
    expect(
      completeTask(
        const Task(id: 't', title: 'Unique', list: 'Personnel'),
        true,
      ).done,
      true,
    );
  });

  testWidgets(
    'Creation, date/time, persistence, details and editing on phone',
    (tester) async {
      tester.view.physicalSize = const Size(430, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(PoulpointsApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle tâche'));
      await tester.pumpAndSettle();
      Finder field(String label) => find.widgetWithText(TextFormField, label);
      Future<void> reveal(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        field('Que faut-il faire ?'),
        'Préparer le voyage',
      );
      await tester.tap(find.text('Normale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importante').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aucune'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toutes les semaines').last);
      await tester.pumpAndSettle();
      await reveal(find.text('Définir une échéance'));
      await tester.tap(find.text('Définir une échéance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await reveal(find.text('Définir une heure'));
      await tester.tap(find.text('Définir une heure'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final timeFields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(timeFields.at(0), '14');
      await tester.enterText(timeFields.at(1), '35');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await reveal(field('Lieu'));
      await tester.enterText(field('Lieu'), 'Gare de Lyon');
      await reveal(find.text('Ajouter une sous-tâche'));
      await tester.tap(find.text('Ajouter une sous-tâche'));
      await tester.pumpAndSettle();
      await reveal(field('Sous-tâche'));
      await tester.enterText(field('Sous-tâche'), 'Billet');
      await tester.enterText(field('Sous-tâche'), 'Réserver le billet');
      await reveal(find.text('Ajouter une sous-tâche'));
      await tester.tap(find.text('Ajouter une sous-tâche'));
      await tester.pumpAndSettle();
      await reveal(find.byTooltip('Supprimer la sous-tâche').last);
      await tester.tap(find.byTooltip('Supprimer la sous-tâche').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      Future<Task> saved() async => (await repository.load(prefs)).tasks.single;
      final persisted = await saved();
      expect(persisted.location, 'Gare de Lyon');
      expect(persisted.priority, true);
      expect(persisted.recurrence, 'weekly');
      expect(persisted.subtasks.single.title, 'Réserver le billet');
      expect(persisted.hasDueTime, true);
      expect(persisted.dueDate!.hour, 14);
      expect(persisted.dueDate!.minute, 35);
      // Reload from preferences, then open and edit the mobile details sheet.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(PoulpointsApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Préparer le voyage'));
      await tester.pumpAndSettle();
      expect(find.text('Gare de Lyon'), findsOneWidget);
      expect(find.text('Répétition : Toutes les semaines'), findsOneWidget);
      expect(find.textContaining('à 14:35'), findsWidgets);
      await tester.tap(find.byTooltip('Modifier'));
      await tester.pumpAndSettle();
      await reveal(field('Lieu'));
      await tester.enterText(field('Lieu'), 'Gare du Nord');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Gare du Nord'), findsOneWidget);
      expect((await saved()).location, 'Gare du Nord');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Mobile editor uses full page and custom repeat help is optional',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(PoulpointsApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nouvelle tâche'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.getSize(find.byType(TaskEditor)).width, 393);
      expect(find.text('Enregistrer'), findsOneWidget);

      final repeat = find.text('Aucune');
      await tester.ensureVisible(repeat);
      await tester.tap(repeat);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personnalisée…').last);
      await tester.pumpAndSettle();

      final info = find.byTooltip(
        'Informations sur la répétition personnalisée',
      );
      expect(info, findsOneWidget);
      expect(
        find.textContaining('La date choisie sert de point de départ'),
        findsNothing,
      );
      expect(
        find.textContaining('Terminer une tâche récurrente fait avancer'),
        findsNothing,
      );
      await tester.ensureVisible(info);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('La date choisie sert de point de départ'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Terminer une tâche récurrente fait avancer'),
        findsOneWidget,
      );
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Closing a creation page should not save an unfinished task.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(repository.state.tasks, isEmpty);
    },
  );

  testWidgets('Save failure remains visible and retry preserves the draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    repository.failSave = true;
    await tester.pumpWidget(PoulpointsApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle tâche'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Que faut-il faire ?'),
      'À conserver',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Modifications non sauvegardées'),
      findsOneWidget,
    );
    expect(repository.state.tasks, isEmpty);
    expect(find.text('À conserver'), findsOneWidget);
    repository.failSave = false;
    await tester.tap(find.text('Réessayer la sauvegarde'));
    await tester.pumpAndSettle();
    expect(repository.state.tasks.single.title, 'À conserver');
    expect(find.textContaining('Modifications non sauvegardées'), findsNothing);
  });

  testWidgets(
    'Empty title and recurrence without date cannot be saved; cancel discards draft',
    (tester) async {
      Task? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Task>(
                    context: context,
                    builder: (_) => const TaskEditor(
                      lists: ['Personnel'],
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
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Saisissez un titre.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que faut-il faire ?'),
        'Brouillon',
      );
      await tester.ensureVisible(find.text('Aucune'));
      await tester.tap(find.text('Aucune'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous les jours').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Choisissez une date pour la répétition.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

// Widget tests isolate rendering from native database scheduling. Real migration,
// commit/rollback and file reopen are covered in storage_test.dart.
class UiTestRepository extends TaskRepository {
  UiTestRepository(super.handle);
  bool failSave = false;
  TaskSnapshot state = TaskSnapshot(
    tasks: [],
    projects: ['Personnel', 'Travail'],
    deleted: {},
  );
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async => state;
  @override
  Future<void> save(TaskSnapshot snapshot) async {
    if (failSave) throw StateError('simulated disk failure');
    state = snapshot;
  }
}
