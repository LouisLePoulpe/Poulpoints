import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:poulpoints/cloud/session_store.dart';
import 'package:poulpoints/cloud/supabase_cloud.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/integration/runtime.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';
import 'widget_storage_test.dart' show BackgroundBridge;

class Vault extends SessionStore {
  @override
  Future<Map<String, dynamic>?> read() async => {
    'url': 'https://example.org',
    'publicKey': 'public',
    'userId': 'tester',
    'refreshToken': 'token',
  };
  @override
  Future<void> write(Map<String, dynamic> session) async {}
  @override
  Future<void> delete() async {}
}

class Remote extends SupabaseCloud {
  Remote() : super(url: 'https://example.org', publicKey: 'public');
  Completer<void>? gate;
  bool offline = false;
  final task = Task(
    id: 'remote',
    title: 'Créée sur un autre appareil',
    list: 'Personnel',
    updatedAt: 1,
  );
  @override
  Future<void> checkAccess() async {
    await gate?.future;
    if (offline) throw StateError('offline');
  }

  @override
  Future<List<Map<String, dynamic>>> readVersions(String table) =>
      readRows(table);
  @override
  Future<List<Map<String, dynamic>>> readRows(String table) async =>
      table == 'poulpoints_task_records'
      ? [
          {
            'task_id': task.id,
            'deleted': false,
            'payload': task.toJson(),
            'revision': 1,
          },
        ]
      : [
          {'project_name': 'Personnel', 'deleted': false, 'revision': 1},
        ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TaskRepository repo;
  late SharedPreferences prefs;
  late BackgroundBridge bridge;
  late Remote remote;
  late IntegrationRuntime runtime;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'poulpoints_supabase_url_v1': 'https://example.org',
      'poulpoints_supabase_public_key_v1': 'public',
    });
    prefs = await SharedPreferences.getInstance();
    repo = TaskRepository(
      DatabaseHandle(
        await newDatabaseFactoryMemory().openDatabase('background'),
      ),
    );
    await repo.load(prefs);
    await repo.save(
      TaskSnapshot(tasks: [], projects: ['Personnel'], deleted: {}),
    );
    bridge = BackgroundBridge();
    remote = Remote();
    runtime = IntegrationRuntime(
      bridge: bridge,
      repository: Future.value(repo),
      sessionStore: Vault(),
      cloudFactory: (_, _, _) => remote,
    );
  });
  tearDown(() => repo.close());
  test(
    'Cold sync persists remote tasks, checkpoint and widget without a UI',
    () async {
      await runtime.synchronize();
      expect((await repo.load(prefs)).tasks.single.id, 'remote');
      expect(await repo.readCloudCheckpoint(), isNotNull);
      expect(
        (bridge.projection!['tasks'] as List).single['title'],
        remote.task.title,
      );
    },
  );
  test('Offline sync preserves local data and permits a later retry', () async {
    remote.offline = true;
    await expectLater(runtime.synchronize(), throwsStateError);
    expect((await repo.load(prefs)).tasks, isEmpty);
    expect(await repo.readCloudCheckpoint(), isNull);
    remote.offline = false;
    await runtime.synchronize();
    expect((await repo.load(prefs)).tasks.single.id, 'remote');
  });
  test(
    'UI handoff waits for cold sync and future work delegates to the UI',
    () async {
      remote.gate = Completer<void>();
      final job = runtime.synchronize();
      await Future<void>.delayed(Duration.zero);
      var idle = false;
      final waiting = runtime.waitUntilIdle().then((_) => idle = true);
      expect(idle, isFalse);
      remote.gate!.complete();
      await job;
      await waiting;
      expect(idle, isTrue);
      var called = false;
      runtime.uiSync = () async {
        called = true;
      };
      await runtime.synchronize();
      expect(called, isTrue);
    },
  );
}
