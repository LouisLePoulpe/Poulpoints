import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poulpoints/cloud/cloud_sync.dart';
import 'package:poulpoints/cloud/supabase_cloud.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/task_actions.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';

import 'cloud_resilience_test.dart' show FakeServer;

Task withSubs(List<String> titles, {Set<String> done = const {}}) => Task(
  id: 't',
  title: 'Valise',
  list: 'Personnel',
  updatedAt: 1,
  subtasks: [
    for (final title in titles)
      Subtask(id: 'id-$title', title: title, done: done.contains(title)),
  ],
);
List<String> titles(Task task) => task.subtasks.map((s) => s.title).toList();
TaskSnapshot snap(List<Task> tasks) =>
    TaskSnapshot(tasks: tasks, projects: ['Personnel'], deleted: {});

class MemoryRepository extends TaskRepository {
  MemoryRepository(super.handle, this.state);
  TaskSnapshot state;
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async => state;
  @override
  Future<void> save(TaskSnapshot snapshot) async => state = snapshot;
}

void main() {
  group('Réordonnancement', () {
    final task = withSubs(['A', 'B', 'C', 'D'], done: {'B'});
    test('vers le début', () {
      expect(titles(moveSubtask(task, 2, 0)), ['C', 'A', 'B', 'D']);
    });
    test('au milieu', () {
      expect(titles(moveSubtask(task, 0, 2)), ['B', 'C', 'A', 'D']);
    });
    test('vers la fin', () {
      expect(titles(moveSubtask(task, 1, 3)), ['A', 'C', 'D', 'B']);
    });
    test('garde identité et état, et date la modification', () {
      final moved = moveSubtask(task, 1, 0);
      expect(moved.subtasks.first.id, 'id-B');
      expect(moved.subtasks.first.done, isTrue);
      expect(moved.updatedAt, greaterThan(task.updatedAt));
    });
    test('sans effet : un seul élément, même place, hors limites', () {
      final single = withSubs(['Seule']);
      expect(identical(moveSubtask(single, 0, 0), single), isTrue);
      expect(identical(moveSubtask(task, 2, 2), task), isTrue);
      expect(identical(moveSubtask(task, -1, 0), task), isTrue);
      expect(identical(moveSubtask(task, 0, 4), task), isTrue);
    });
  });

  group('Renommage', () {
    final task = withSubs(['A', 'B'], done: {'B'});
    test('valide : nettoyé, même id, état conservé', () {
      final renamed = renameSubtask(task, 'id-B', '  Bouée  ');
      expect(titles(renamed), ['A', 'Bouée']);
      expect(renamed.subtasks[1].id, 'id-B');
      expect(renamed.subtasks[1].done, isTrue);
      expect(renamed.updatedAt, greaterThan(task.updatedAt));
    });
    test('vide ou espaces seuls : refusé, ancien intitulé gardé', () {
      expect(cleanSubtaskTitle(''), isNull);
      expect(cleanSubtaskTitle(' \t\n '), isNull);
      expect(identical(renameSubtask(task, 'id-A', ''), task), isTrue);
      expect(identical(renameSubtask(task, 'id-A', '   '), task), isTrue);
    });
    test('inchangé ou inconnu : aucune modification à synchroniser', () {
      expect(identical(renameSubtask(task, 'id-A', ' A '), task), isTrue);
      expect(identical(renameSubtask(task, 'absente', 'X'), task), isTrue);
    });
  });

  group('Persistance et format', () {
    test('le JSON d’une sous-tâche garde le format lu par la 0.8.6', () {
      // A new key would be dropped by older clients and break their
      // post-sync signature check, so the shape must stay exactly this.
      expect(withSubs(['A']).subtasks.single.toJson().keys, [
        'id',
        'title',
        'done',
      ]);
    });
    test('export puis import conservent l’ordre choisi', () {
      final reordered = moveSubtask(withSubs(['A', 'B', 'C']), 2, 0);
      final exported = jsonEncode(snap([reordered]).toJson());
      final imported = TaskSnapshot.fromJson(
        jsonDecode(exported) as Map<String, dynamic>,
      );
      expect(titles(imported.tasks.single), ['C', 'A', 'B']);
    });
    test('une ancienne sauvegarde s’importe dans son ordre d’origine', () {
      const legacy = '''
{"schemaVersion":3,"projects":["Personnel"],"deleted":{},"tasks":[
 {"id":"t","title":"Valise","list":"Personnel","done":false,
  "subtasks":[{"id":"9","title":"Z"},{"id":"1","title":"A","done":true}]}]}''';
      final task = TaskSnapshot.fromJson(
        jsonDecode(legacy) as Map<String, dynamic>,
      ).tasks.single;
      expect(titles(task), ['Z', 'A']);
      expect(task.subtasks.last.done, isTrue);
    });
    test('l’ordre change l’empreinte cloud, donc la tâche est envoyée', () {
      final task = withSubs(['A', 'B']);
      final moved = moveSubtask(task, 1, 0);
      expect(
        canonicalJson(moved.toJson()),
        isNot(canonicalJson(task.copyWith().toJson())),
      );
    });
    test('la régénération récurrente garde intitulés et ordre', () {
      var task = withSubs(
        ['A', 'B', 'C'],
        done: {'A', 'C'},
      ).copyWith(recurrence: 'daily', dueDate: DateTime(2027, 3, 1, 9));
      task = renameSubtask(moveSubtask(task, 2, 0), 'id-A', 'Passeport');
      final next = completeTask(task, true);
      expect(titles(next), ['C', 'Passeport', 'B']);
      expect(next.subtasks.map((s) => s.id), ['id-C', 'id-A', 'id-B']);
      expect(next.subtasks.every((s) => !s.done), isTrue);
      expect(next.dueDate, DateTime(2027, 3, 2, 9));
    });
  });

  group('Synchronisation', () {
    test(
      'un réordonnancement hors ligne se propage à l’autre appareil',
      () async {
        final cloud = FakeServer();
        final android = await CloudSync.synchronize(
          cloud: cloud,
          local: snap([
            withSubs(['A', 'B', 'C']),
          ]),
          baseline: null,
        );
        final linux = await CloudSync.synchronize(
          cloud: cloud,
          local: snap([]),
          baseline: null,
        );
        final reordered = moveSubtask(android.snapshot.tasks.single, 0, 2);
        final renamed = renameSubtask(reordered, 'id-B', 'Brosse');
        await CloudSync.synchronize(
          cloud: cloud,
          local: snap([renamed]),
          baseline: android.baseline,
        );
        final received = await CloudSync.synchronize(
          cloud: cloud,
          local: linux.snapshot,
          baseline: linux.baseline,
        );
        expect(titles(received.snapshot.tasks.single), ['Brosse', 'C', 'A']);
        expect(received.snapshot.tasks.single.subtasks.first.id, 'id-B');
      },
    );

    test(
      'deux appareils modifient la même tâche : conflit, rien d’écrasé',
      () async {
        final cloud = FakeServer();
        final base = await CloudSync.synchronize(
          cloud: cloud,
          local: snap([
            withSubs(['A', 'B', 'C']),
          ]),
          baseline: null,
        );
        final original = base.snapshot.tasks.single;
        await CloudSync.synchronize(
          cloud: cloud,
          local: snap([moveSubtask(original, 0, 2)]),
          baseline: base.baseline,
        );
        final writes = cloud.writes;
        for (final concurrent in [
          moveSubtask(original, 2, 0),
          renameSubtask(original, 'id-A', 'Autre'),
        ]) {
          await expectLater(
            CloudSync.synchronize(
              cloud: cloud,
              local: snap([concurrent]),
              baseline: base.baseline,
            ),
            throwsA(isA<CloudException>()),
          );
        }
        expect(cloud.writes, writes);
        // The user's explicit choice in the conflict dialog is then applied.
        final kept = await CloudSync.synchronize(
          cloud: cloud,
          local: snap([moveSubtask(original, 2, 0)]),
          baseline: base.baseline,
          resolve: (_) async => CloudDecision.push,
        );
        expect(titles(kept.snapshot.tasks.single), ['C', 'A', 'B']);
      },
    );

    test('un renommage pendant une synchro en cours est conservé', () {
      final started = snap([
        withSubs(['A', 'B']),
      ]);
      final current = snap([
        moveSubtask(renameSubtask(started.tasks.single, 'id-A', 'A2'), 0, 1),
      ]);
      final merged = rebaseLocalEdits(started, current, started);
      expect(titles(merged.tasks.single), ['B', 'A2']);
    });
  });

  group('Widgets', () {
    late TaskRepository repo;
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = TaskRepository(
        DatabaseHandle(await newDatabaseFactoryMemory().openDatabase('order')),
      );
      await repo.load(prefs);
      await repo.save(
        snap([
          withSubs(['A', 'B', 'C']),
        ]),
      );
    });

    test('action du widget puis réordonnancement : pas de conflit', () async {
      final shown = (await repo.load(prefs)).tasks.single;
      final completed = await repo.completeFromWidget(
        'jeton',
        't',
        shown.updatedAt.toString(),
      );
      expect(completed.accepted, isTrue);
      final latest = completed.snapshot.tasks.single;
      await repo.save(snap([moveSubtask(latest, 2, 0)]));
      final saved = (await repo.load(prefs)).tasks.single;
      expect(saved.done, isTrue);
      expect(titles(saved), ['C', 'A', 'B']);
    });

    test('un widget périmé n’écrase pas un renommage', () async {
      final shown = (await repo.load(prefs)).tasks.single;
      await repo.save(snap([renameSubtask(shown, 'id-B', 'Bouée')]));
      final stale = await repo.completeFromWidget(
        'jeton',
        't',
        shown.updatedAt.toString(),
      );
      expect(stale.accepted, isFalse);
      final saved = (await repo.load(prefs)).tasks.single;
      expect(saved.done, isFalse);
      expect(titles(saved), ['A', 'Bouée', 'C']);
    });
  });

  testWidgets('Renommer et réordonner depuis le panneau de détail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final repository = MemoryRepository(
      DatabaseHandle(await newDatabaseFactoryMemory().openDatabase('ui')),
      snap([
        withSubs(['Alpha', 'Beta', 'Gamma'], done: {'Beta'}),
      ]),
    );
    List<String> stored() => titles(repository.state.tasks.single);
    await tester.pumpWidget(PoulpointsApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valise'));
    await tester.pumpAndSettle();

    // Blank title is refused inside the dialog; Escape cancels untouched.
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('Renommer la sous-tâche'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(find.text('Renommer'));
    await tester.pumpAndSettle();
    expect(find.text('L’intitulé ne peut pas être vide.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Renommer la sous-tâche'), findsNothing);
    expect(stored(), ['Alpha', 'Beta', 'Gamma']);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '  Bouée ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(stored(), ['Alpha', 'Bouée', 'Gamma']);
    expect(repository.state.tasks.single.subtasks[1].id, 'id-Beta');
    expect(repository.state.tasks.single.subtasks[1].done, isTrue);

    // Keyboard/mouse alternative to dragging.
    await tester.tap(find.byTooltip('Options de la sous-tâche').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descendre'));
    await tester.pumpAndSettle();
    expect(stored(), ['Bouée', 'Alpha', 'Gamma']);

    // Drag the last handle above the first row.
    final handle = find.byIcon(Icons.drag_handle).last;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(stored(), ['Gamma', 'Bouée', 'Alpha']);

    // Adding uses the same dialog: blank refused, new subtask goes last.
    await tester.tap(find.byTooltip('Ajouter une sous-tâche'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('L’intitulé ne peut pas être vide.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, ' Delta ');
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();
    expect(stored(), ['Gamma', 'Bouée', 'Alpha', 'Delta']);
    expect(tester.takeException(), isNull);
  });
}
