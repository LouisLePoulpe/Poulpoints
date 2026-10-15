import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/recurrence.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';

TaskSnapshot sample(String title) => TaskSnapshot(
  tasks: [
    Task(
      id: 'one',
      title: title,
      list: 'Personnel',
      dueDate: DateTime(2026, 11, 7, 14, 30),
      hasDueTime: true,
      location: 'Paris',
      recurrence: 'custom',
      recurrenceRule: const RecurrenceRule(
        unit: 'monthly',
        monthMode: 'ordinal',
      ),
      subtasks: const [Subtask(id: 'sub', title: 'Préparer', done: true)],
    ),
  ],
  projects: ['Personnel'],
  deleted: {'old': 3},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late TaskRepository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = TaskRepository(
      DatabaseHandle(await newDatabaseFactoryMemory().openDatabase('test')),
    );
  });
  tearDown(() async {
    await repo.close();
  });

  test(
    'Migration keeps complete legacy data and never rewrites original keys',
    () async {
      final initial = sample('Ancienne');
      final raw = jsonEncode(initial.tasks.map((t) => t.toJson()).toList());
      await prefs.setString('poulpoints_tasks_v1', raw);
      await prefs.setStringList('poulpoints_projects_v2', initial.projects);
      await prefs.setString(
        'poulpoints_deletions_v3',
        jsonEncode(initial.deleted),
      );
      expect((await repo.load(prefs)).toJson(), initial.toJson());
      await repo.save(sample('Nouvelle'));
      expect((await repo.load(prefs)).tasks.single.title, 'Nouvelle');
      expect(prefs.getString('poulpoints_tasks_v1'), raw);
      expect((await repo.previous())!.tasks.single.title, 'Ancienne');
    },
  );

  test(
    'Malformed legacy data aborts migration without partial state',
    () async {
      await prefs.setString('poulpoints_tasks_v1', '{broken');
      await expectLater(repo.load(prefs), throwsFormatException);
      final records = stringMapStoreFactory.store('poulpoints');
      expect(await records.record('current').get(repo.handle.db), isNull);
      expect(await records.record('migration').get(repo.handle.db), isNull);
      expect(prefs.getString('poulpoints_tasks_v1'), '{broken');
      await prefs.setString('poulpoints_tasks_v1', '[]');
      expect((await repo.load(prefs)).tasks, isEmpty);
    },
  );

  test(
    'Queued writes keep order and previous snapshot; invalid import leaves data',
    () async {
      await repo.load(prefs);
      await Future.wait(
        List.generate(20, (i) => repo.save(sample('Version $i'))),
      );
      expect((await repo.load(prefs)).tasks.single.title, 'Version 19');
      expect((await repo.previous())!.tasks.single.title, 'Version 18');
      expect(
        () => TaskSnapshot.fromJson({
          ...sample('Bad').toJson(),
          'schemaVersion': 99,
        }),
        throwsFormatException,
      );
      expect((await repo.load(prefs)).tasks.single.title, 'Version 19');
      await repo.save((await repo.previous())!);
      expect((await repo.load(prefs)).tasks.single.title, 'Version 18');
    },
  );

  test('Transaction failure rolls back current and backup together', () async {
    await repo.load(prefs);
    await repo.save(sample('Stable'));
    final store = stringMapStoreFactory.store('poulpoints');
    await expectLater(
      repo.handle.db.transaction((txn) async {
        await store.record('current').put(txn, {'broken': true});
        await store.record('previous').delete(txn);
        throw StateError('simulated write failure');
      }),
      throwsStateError,
    );
    expect((await repo.load(prefs)).tasks.single.title, 'Stable');
    expect(await repo.previous(), isNotNull);
  });

  test(
    'Cloud checkpoint commits with tasks and survives subsequent local edits',
    () async {
      await repo.load(prefs);
      final checkpoint = <String, dynamic>{
        'identity': 'test',
        'tasks': {'one': 'signature'},
      };
      await repo.saveCloud(sample('Cloud'), checkpoint);
      expect(await repo.readCloudCheckpoint(), checkpoint);
      await repo.save(sample('Local'));
      expect(await repo.readCloudCheckpoint(), checkpoint);
      final stale = TaskRepository(repo.handle);
      await stale.load(prefs);
      await repo.save(sample('Latest'));
      await expectLater(
        stale.saveCloud(sample('Stale'), {'identity': 'wrong'}),
        throwsStateError,
      );
      expect((await repo.load(prefs)).tasks.single.title, 'Latest');
      expect(await repo.readCloudCheckpoint(), checkpoint);
    },
  );

  test('Invalid dates, unknown recurrence and duplicate IDs are rejected', () {
    final data = sample('Valide').toJson();
    for (final field in [
      {'dueDate': 'not a date'},
      {'recurrence': 'unsupported'},
    ]) {
      final task = {...sample('Valide').tasks.single.toJson(), ...field};
      expect(
        () => TaskSnapshot.fromJson({
          ...data,
          'tasks': [task],
        }),
        throwsFormatException,
      );
    }
    final task = sample('Valide').tasks.single.toJson();
    expect(
      () => TaskSnapshot.fromJson({
        ...data,
        'tasks': [task, task],
      }),
      throwsFormatException,
    );
  });

  test(
    'Stale client cannot overwrite changes made by another repository',
    () async {
      await repo.load(prefs);
      final other = TaskRepository(repo.handle);
      await other.load(prefs);
      await repo.save(sample('Plus récente'));
      await expectLater(other.save(sample('Périmée')), throwsStateError);
      expect((await repo.load(prefs)).tasks.single.title, 'Plus récente');
      await other.load(prefs);
      await other.save(sample('Rechargée'));
      expect((await repo.load(prefs)).tasks.single.title, 'Rechargée');
    },
  );

  test(
    'Real file database survives close and reopen with custom recurrence',
    () async {
      final dir = await Directory.systemTemp.createTemp('poulpoints-test-');
      try {
        final file = '${dir.path}/tasks.db';
        final first = TaskRepository(
          DatabaseHandle(await databaseFactoryIo.openDatabase(file)),
        );
        await first.load(prefs);
        await first.save(sample('Persistante'));
        await first.close();
        final reopened = TaskRepository(
          DatabaseHandle(await databaseFactoryIo.openDatabase(file)),
        );
        expect(
          (await reopened.load(prefs)).toJson(),
          sample('Persistante').toJson(),
        );
        await reopened.close();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'Load failure blocks editing instead of replacing unreadable data',
    (tester) async {
      await prefs.setString('poulpoints_tasks_v1', 'invalid');
      final viewRepo = LoadFailureRepository(repo.handle);
      await tester.pumpWidget(PoulpointsApp(repository: viewRepo));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Vos données ne seront pas remplacées'),
        findsOneWidget,
      );
      expect(find.text('Nouvelle tâche'), findsNothing);
      expect(prefs.getString('poulpoints_tasks_v1'), 'invalid');
      await prefs.setString('poulpoints_tasks_v1', '[]');
      viewRepo.fail = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle tâche'), findsOneWidget);
    },
  );
}

class LoadFailureRepository extends TaskRepository {
  LoadFailureRepository(super.handle);
  bool fail = true;
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async {
    if (fail) throw const FormatException('unreadable storage');
    return TaskSnapshot(tasks: [], projects: ['Personnel'], deleted: {});
  }
}
