import 'dart:io';
import 'package:sembast/sembast_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';
import 'package:poulpoints/integration/runtime.dart';
import 'package:poulpoints/integration/platform_bridge.dart';

class BackgroundBridge extends PlatformBridge {
  final pending = <Map<String, dynamic>>[];
  Map<String, dynamic>? projection;
  bool failPublish = false;
  @override
  bool get usesSharedRuntime => true;
  @override
  void setCommandHandler(
    Future<void> Function() handler, {
    Future<void> Function()? sync,
  }) {}
  @override
  Future<void> reportWidgetError(String message) async {}
  @override
  Future<List<Map<String, dynamic>>> commands() async => List.of(pending);
  @override
  Future<void> publish(Map<String, dynamic> data) async {
    if (failPublish) throw StateError('projection unavailable');
    projection = data;
  }

  @override
  Future<void> ack(String token) async =>
      pending.removeWhere((c) => c['token'] == token);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TaskRepository repo;
  late SharedPreferences prefs;
  late TaskSnapshot initial;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = TaskRepository(
      DatabaseHandle(await newDatabaseFactoryMemory().openDatabase('commands')),
    );
    await repo.load(prefs);
    initial = TaskSnapshot(
      tasks: [
        Task(
          id: 'a',
          title: 'Récurrente',
          list: 'Personnel',
          updatedAt: 42,
          dueDate: DateTime(2027, 1, 2, 10),
          hasDueTime: true,
          recurrence: 'daily',
          reminderMinutes: 15,
          location: 'Maison',
          subtasks: const [Subtask(id: 's', title: 'Préparer', done: true)],
        ),
        Task(id: 'b', title: 'Autre', list: 'Personnel', updatedAt: 43),
      ],
      projects: ['Personnel'],
      deleted: {'old': 4},
    );
    await repo.saveCloud(initial, {'checkpoint': 'preserved'});
  });
  tearDown(() => repo.close());
  test(
    'Snooze is durable and idempotent without completing or moving deadline',
    () async {
      final first = await repo.completeFromWidget(
        'snooze:a:42',
        'a',
        '42',
        snooze: true,
      );
      final reminder = first.snapshot.tasks.first.snoozedUntil;
      expect(reminder, isNotNull);
      expect(first.snapshot.tasks.first.dueDate, initial.tasks.first.dueDate);
      expect(first.snapshot.tasks.first.done, false);
      final retry = await repo.completeFromWidget(
        'snooze:a:42',
        'a',
        '42',
        snooze: true,
      );
      expect(retry.changed, false);
      expect(retry.snapshot.tasks.first.snoozedUntil, reminder);
    },
  );

  test(
    'Atomic completion preserves unrelated edits, tombstones, reminders and cloud checkpoint',
    () async {
      final other = TaskRepository(repo.handle);
      await other.load(prefs);
      final tasks = initial.tasks.toList();
      tasks[1] = tasks[1].copyWith(title: 'Modification récente');
      await other.save(
        TaskSnapshot(
          tasks: tasks,
          projects: initial.projects,
          deleted: initial.deleted,
        ),
      );
      final result = await repo.completeFromWidget('a:42', 'a', '42');
      expect(result.changed, isTrue);
      expect(result.snapshot.tasks[1].title, 'Modification récente');
      final next = result.snapshot.tasks.first;
      expect(next.dueDate, DateTime(2027, 1, 3, 10));
      expect(next.location, 'Maison');
      expect(next.reminderMinutes, 15);
      expect(next.subtasks.single.done, isFalse);
      expect(result.snapshot.deleted, {'old': 4});
      expect(await repo.readCloudCheckpoint(), {'checkpoint': 'preserved'});
      await repo.save(
        result.snapshot,
      ); // no false stale-revision conflict after widget
    },
  );

  test(
    'A durable receipt prevents recurrence advancing again after retry/reload',
    () async {
      final first = await repo.completeFromWidget('a:42', 'a', '42');
      await repo.load(prefs);
      final second = await repo.completeFromWidget('a:42', 'a', '42');
      expect(second.accepted, isTrue);
      expect(second.changed, isFalse);
      expect(second.snapshot.toJson(), first.snapshot.toJson());
      final stale = await repo.completeFromWidget('different-token', 'a', '42');
      expect(stale.accepted, isFalse);
      expect(stale.snapshot.toJson(), first.snapshot.toJson());
    },
  );

  test(
    'Cold execution saves without building any app and retries failed projection safely',
    () async {
      final bridge = BackgroundBridge()..failPublish = true;
      bridge.pending.add({
        'token': 'a:42',
        'action': 'complete',
        'id': 'a',
        'revision': '42',
      });
      var runtime = IntegrationRuntime(
        bridge: bridge,
        repository: Future.value(repo),
      );
      await runtime.start(); // commit succeeded, publishing failed
      expect(bridge.pending, hasLength(1));
      expect(
        (await repo.load(prefs)).tasks.first.dueDate,
        DateTime(2027, 1, 3, 10),
      );
      bridge.failPublish = false;
      runtime = IntegrationRuntime(
        bridge: bridge,
        repository: Future.value(repo),
      );
      await runtime.start();
      expect(bridge.pending, isEmpty);
      expect(
        (await repo.load(prefs)).tasks.first.dueDate,
        DateTime(2027, 1, 3, 10),
      );
      expect(
        bridge.projection!['tasks'][0]['remindAt'],
        DateTime(2027, 1, 3, 9, 45).millisecondsSinceEpoch,
      );
    },
  );

  test(
    'Concurrent duplicate completions advance recurrence exactly once',
    () async {
      final results = await Future.wait(
        List.generate(10, (_) => repo.completeFromWidget('a:42', 'a', '42')),
      );
      expect(results.where((r) => r.changed), hasLength(1));
      expect(
        (await repo.load(prefs)).tasks.first.dueDate,
        DateTime(2027, 1, 3, 10),
      );
    },
  );
  test('Receipt survives closing and reopening the on-disk database', () async {
    final dir = await Directory.systemTemp.createTemp(
      'poulpoints-widget-restart-',
    );
    TaskRepository? disk;
    try {
      final path = '${dir.path}/tasks.db';
      disk = TaskRepository(
        DatabaseHandle(await databaseFactoryIo.openDatabase(path)),
      );
      await disk.load(prefs);
      await disk.save(initial);
      await disk.completeFromWidget('a:42', 'a', '42');
      await disk.close();
      disk = TaskRepository(
        DatabaseHandle(await databaseFactoryIo.openDatabase(path)),
      );
      await disk.load(prefs);
      final retry = await disk.completeFromWidget('a:42', 'a', '42');
      expect(retry.accepted, isTrue);
      expect(retry.changed, isFalse);
      expect(retry.snapshot.tasks.first.dueDate, DateTime(2027, 1, 3, 10));
    } finally {
      await disk?.close();
      await dir.delete(recursive: true);
    }
  });
}
