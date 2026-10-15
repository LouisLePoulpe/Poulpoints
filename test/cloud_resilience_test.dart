import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poulpoints/cloud/cloud_sync.dart';
import 'package:poulpoints/cloud/supabase_cloud.dart';
import 'package:poulpoints/cloud/session_store.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/storage/task_repository.dart';

TaskSnapshot snapshot([
  List<Task> tasks = const [],
  Map<String, int> deleted = const {},
]) => TaskSnapshot(tasks: tasks, projects: ['Personnel'], deleted: deleted);
Task task(String id, String title) =>
    Task(id: id, title: title, list: 'Personnel', updatedAt: 1);

class MemoryVault implements SessionStore {
  Map<String, dynamic>? value;
  bool failWrites = false;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> session) async {
    if (failWrites) throw StateError("Vault locked");
    value = Map.of(session);
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class FakeServer extends SupabaseCloud {
  FakeServer()
    : super(
        url: 'https://test.supabase.co',
        publicKey: 'public',
        httpClient: MockClient((_) async => http.Response('', 500)),
      ) {
    userId = 'user';
  }
  final rows = <String, Map<String, Map<String, dynamic>>>{};
  int writes = 0;
  int? failAt;
  @override
  Future<void> checkAccess() async {}
  @override
  Future<List<Map<String, dynamic>>> readVersions(String table) =>
      readRows(table);
  @override
  Future<List<Map<String, dynamic>>> readRows(String table) async =>
      (jsonDecode(jsonEncode((rows[table] ?? {}).values.toList())) as List)
          .cast<Map<String, dynamic>>();
  @override
  Future<void> writeRecord({
    required String table,
    required String idColumn,
    required String id,
    required Map<String, dynamic> values,
    int? expectedRevision,
  }) async {
    writes++;
    if (writes == failAt) throw TimeoutException('Network interrupted');
    final records = rows.putIfAbsent(table, () => {});
    if (records[id]?['revision'] != expectedRevision) {
      throw const CloudException('Conflit cloud');
    }
    records[id] = {
      idColumn: id,
      ...values,
      'revision': (expectedRevision ?? 0) + 1,
    };
  }
}

void main() {
  test(
    'Two devices exchange edits and deletions without resurrection',
    () async {
      final cloud = FakeServer();
      final a = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('a', 'A')]),
        baseline: null,
      );
      final b = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot(),
        baseline: null,
      );
      expect(b.snapshot.tasks.single.title, 'A');
      final edited = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('a', 'B')]),
        baseline: b.baseline,
      );
      final received = await CloudSync.synchronize(
        cloud: cloud,
        local: a.snapshot,
        baseline: a.baseline,
      );
      expect(received.snapshot.tasks.single.title, 'B');
      await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([], {'a': 3}),
        baseline: edited.baseline,
      );
      final deleted = await CloudSync.synchronize(
        cloud: cloud,
        local: received.snapshot,
        baseline: received.baseline,
      );
      expect(deleted.snapshot.tasks, isEmpty);
      expect(deleted.snapshot.deleted, contains('a'));
    },
  );
  test(
    'Independent offline edits merge and conflicting edits stop before writes',
    () async {
      final cloud = FakeServer();
      final base = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('a', 'A'), task('b', 'B')]),
        baseline: null,
      );
      await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('a', 'A2'), task('b', 'B')]),
        baseline: base.baseline,
      );
      final second = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('a', 'A'), task('b', 'B2')]),
        baseline: base.baseline,
      );
      expect(
        second.snapshot.tasks.map((t) => t.title),
        containsAll(['A2', 'B2']),
      );
      final writes = cloud.writes;
      await expectLater(
        CloudSync.synchronize(
          cloud: cloud,
          local: snapshot([task('a', 'Conflict'), task('b', 'B')]),
          baseline: base.baseline,
        ),
        throwsA(isA<CloudException>()),
      );
      expect(cloud.writes, writes);
    },
  );
  test(
    'Retry after partial remote write converges without duplicate tasks',
    () async {
      final cloud = FakeServer()..failAt = 3;
      final local = snapshot([task('a', 'A'), task('b', 'B')]);
      await expectLater(
        CloudSync.synchronize(cloud: cloud, local: local, baseline: null),
        throwsA(isA<TimeoutException>()),
      );
      cloud.failAt = null;
      final retried = await CloudSync.synchronize(
        cloud: cloud,
        local: local,
        baseline: null,
      );
      expect(retried.snapshot.tasks.length, 2);
      expect(cloud.rows['poulpoints_task_records']!.length, 2);
    },
  );
  test('Edit during upload is rebased and pushed at the next cycle', () async {
    final cloud = FakeServer();
    final started = snapshot([task('a', 'First edit')]);
    final synced = await CloudSync.synchronize(
      cloud: cloud,
      local: started,
      baseline: null,
    );
    final current = snapshot([task('a', 'Second edit')]);
    final rebased = rebaseLocalEdits(started, current, synced.snapshot);
    expect(rebased.tasks.single.title, 'Second edit');
    final next = await CloudSync.synchronize(
      cloud: cloud,
      local: rebased,
      baseline: synced.baseline,
    );
    expect(next.snapshot.tasks.single.title, 'Second edit');
  });
  test(
    'Concurrent local and remote edits during download remain a conflict',
    () {
      expect(
        () => rebaseLocalEdits(
          snapshot([task('a', 'Base')]),
          snapshot([task('a', 'Local')]),
          snapshot([task('a', 'Remote')]),
        ),
        throwsA(isA<CloudException>()),
      );
    },
  );
  test(
    'Session restore, refresh rotation, single refresh and disconnect',
    () async {
      final vault = MemoryVault();
      var refreshes = 0;
      final client = MockClient((r) async {
        if (r.url.path == '/auth/v1/token') {
          if (r.url.queryParameters['grant_type'] == 'refresh_token') {
            refreshes++;
          }
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh-$refreshes',
              'expires_in': 3600,
              'user': {'id': 'user'},
            }),
            200,
          );
        }
        return http.Response('[{"app_id":"poulpoints"}]', 200);
      });
      final first = SupabaseCloud(
        url: 'https://test.supabase.co',
        publicKey: 'public',
        httpClient: client,
        sessionStore: vault,
      );
      await first.signIn('test@example.org', 'password-not-stored');
      await first.rememberSession();
      expect(vault.value!.containsKey('password'), false);
      first.dispose();
      final restored = SupabaseCloud(
        url: 'https://test.supabase.co',
        publicKey: 'public',
        httpClient: client,
        sessionStore: vault,
      );
      restored.restoreSession((await vault.read())!);
      await Future.wait([restored.checkAccess(), restored.checkAccess()]);
      expect(refreshes, 1);
      expect(vault.value!['refreshToken'], 'refresh-1');
      await restored.forgetSession();
      expect(vault.value, isNull);
      expect(restored.signedIn, false);
    },
  );
  test(
    'Failed vault write is retried before further authenticated requests',
    () async {
      final vault = MemoryVault();
      final session = <String, dynamic>{
        'url': 'https://test.supabase.co',
        'publicKey': 'public',
        'userId': 'user',
        'refreshToken': 'old',
      };
      await vault.write(session);
      var refreshes = 0;
      var reads = 0;
      final cloud = SupabaseCloud(
        url: session['url'],
        publicKey: 'public',
        sessionStore: vault,
        httpClient: MockClient((r) async {
          if (r.url.path == '/auth/v1/token') {
            refreshes++;
            return http.Response(
              jsonEncode({
                'access_token': 'a',
                'refresh_token': 'rotated',
                'expires_in': 3600,
                'user': {'id': 'user'},
              }),
              200,
            );
          }
          reads++;
          return http.Response('[{"app_id":"poulpoints"}]', 200);
        }),
      );
      cloud.restoreSession(session);
      vault.failWrites = true;
      await expectLater(cloud.checkAccess(), throwsStateError);
      expect(reads, 0);
      vault.failWrites = false;
      await cloud.checkAccess();
      expect(refreshes, 1);
      expect(reads, 1);
      expect(vault.value!['refreshToken'], 'rotated');
    },
  );

  test(
    'Network error keeps refresh token; invalid session deletes it',
    () async {
      final vault = MemoryVault();
      final session = {
        'url': 'https://test.supabase.co',
        'publicKey': 'public',
        'userId': 'user',
        'refreshToken': 'r',
      };
      await vault.write(session);
      var response = 503;
      final cloud = SupabaseCloud(
        url: 'https://test.supabase.co',
        publicKey: 'public',
        httpClient: MockClient((_) async => http.Response('{}', response)),
        sessionStore: vault,
      );
      cloud.restoreSession(session);
      await expectLater(cloud.checkAccess(), throwsA(isA<CloudException>()));
      expect(vault.value, isNotNull);
      response = 401;
      await expectLater(cloud.checkAccess(), throwsA(isA<CloudException>()));
      expect(vault.value, isNull);
      expect(cloud.signedIn, false);
    },
  );
}
