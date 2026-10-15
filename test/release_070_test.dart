import 'package:flutter_test/flutter_test.dart';
import 'package:poulpoints/models.dart';
import 'package:poulpoints/task_actions.dart';
import 'package:poulpoints/integration/projection.dart';
import 'package:poulpoints/storage/task_repository.dart';
import 'package:poulpoints/cloud/cloud_sync.dart';
import 'package:poulpoints/cloud/supabase_cloud.dart';
import 'cloud_resilience_test.dart' show FakeServer, snapshot, task;

class CountingServer extends FakeServer {
  int fullReads = 0;
  int versionReads = 0;
  @override
  Future<List<Map<String, dynamic>>> readRows(String table) async {
    fullReads++;
    return super.readRows(table);
  }

  @override
  Future<List<Map<String, dynamic>>> readVersions(String table) async {
    versionReads++;
    return super.readRows(table);
  }
}

void main() {
  test(
    'Unchanged cloud checks only versions, then fetches changed content',
    () async {
      final cloud = CountingServer();
      addTearDown(cloud.dispose);
      final first = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('a', 'A')]),
        baseline: null,
      );
      cloud.fullReads = 0;
      cloud.versionReads = 0;
      final idle = await CloudSync.synchronize(
        cloud: cloud,
        local: first.snapshot,
        baseline: first.baseline,
      );
      expect(cloud.fullReads, 0);
      expect(cloud.versionReads, 2);
      expect(idle.snapshot.tasks.single.title, 'A');
      final row = cloud.rows['poulpoints_task_records']!['a']!;
      row['revision'] = (row['revision'] as int) + 1;
      row['payload'] = task('a', 'Distant').toJson();
      final changed = await CloudSync.synchronize(
        cloud: cloud,
        local: first.snapshot,
        baseline: first.baseline,
      );
      expect(cloud.fullReads, greaterThan(0));
      expect(changed.snapshot.tasks.single.title, 'Distant');
    },
  );
  test(
    'Multiple reminders, labels and snooze round trip and cancel on completion',
    () {
      final due = DateTime(2027, 1, 2, 10);
      final original = Task(
        id: 'a',
        title: 'A',
        list: 'Personnel',
        dueDate: due,
        hasDueTime: true,
        reminderOffsets: [60, 15, 0, 15],
        tags: ['maison', 'urgent'],
        snoozedUntil: due.add(const Duration(minutes: 10)),
      );
      final saved = TaskSnapshot.fromJson(
        snapshot([original]).toJson(),
      ).tasks.single;
      expect(saved.reminders, [0, 15, 60]);
      expect(saved.tags, ['maison', 'urgent']);
      expect(projectTasks([saved])['tasks'][0]['remindAts'], [
        due.subtract(const Duration(minutes: 60)).millisecondsSinceEpoch,
        due.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
        due.millisecondsSinceEpoch,
        due.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      ]);
      expect(projectTasks([completeTask(saved, true)])['tasks'], isEmpty);
    },
  );
  test(
    'Moving one occurrence retains the original cadence, skipping resets snooze',
    () {
      final original = Task(
        id: 'r',
        title: 'R',
        list: 'Personnel',
        dueDate: DateTime(2027, 1, 2, 10),
        recurrence: 'weekly',
        reminderOffsets: [0, 60],
        hasDueTime: true,
      );
      final moved = moveOccurrence(original, DateTime(2027, 1, 4, 10));
      final next = completeTask(
        moved.copyWith(snoozedUntil: DateTime(2027, 1, 4, 11)),
        true,
      );
      expect(next.dueDate, DateTime(2027, 1, 9, 10));
      expect(next.occurrenceAnchor, isNull);
      expect(next.snoozedUntil, isNull);
      expect(next.reminders, [0, 60]);
    },
  );
  for (final decision in [
    CloudDecision.push,
    CloudDecision.pull,
    CloudDecision.conflict,
  ]) {
    test(
      'Concurrent changes can be resolved or cancelled: $decision',
      () async {
        final cloud = FakeServer();
        addTearDown(cloud.dispose);
        final first = await CloudSync.synchronize(
          cloud: cloud,
          local: snapshot([task('x', 'Initial')]),
          baseline: null,
        );
        await CloudSync.synchronize(
          cloud: cloud,
          local: snapshot([task('x', 'Distant')]),
          baseline: first.baseline,
        );
        final writes = cloud.writes;
        final future = CloudSync.synchronize(
          cloud: cloud,
          local: snapshot([task('x', 'Local')]),
          baseline: first.baseline,
          resolve: (conflict) async {
            expect(conflict.local!['title'], 'Local');
            expect(conflict.remote!['title'], 'Distant');
            return decision;
          },
        );
        if (decision == CloudDecision.conflict) {
          await expectLater(future, throwsA(isA<CloudException>()));
          expect(cloud.writes, writes);
        } else {
          final result = await future;
          expect(
            result.snapshot.tasks.single.title,
            decision == CloudDecision.push ? 'Local' : 'Distant',
          );
        }
      },
    );
  }
  test(
    'A remote edit during conflict choice is protected by conditional write',
    () async {
      final cloud = FakeServer();
      addTearDown(cloud.dispose);
      final first = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('x', 'Initial')]),
        baseline: null,
      );
      await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([task('x', 'Distant')]),
        baseline: first.baseline,
      );
      await expectLater(
        CloudSync.synchronize(
          cloud: cloud,
          local: snapshot([task('x', 'Local')]),
          baseline: first.baseline,
          resolve: (conflict) async {
            cloud.rows['poulpoints_task_records']!['x']!['revision'] = 99;
            return CloudDecision.push;
          },
        ),
        throwsA(isA<CloudException>()),
      );
      expect(
        cloud.rows['poulpoints_task_records']!['x']!['payload']['title'],
        'Distant',
      );
    },
  );
  test(
    'Removing a project and moving every task propagates without resurrecting it',
    () async {
      final cloud = FakeServer();
      addTearDown(cloud.dispose);
      final first = await CloudSync.synchronize(
        cloud: cloud,
        local: TaskSnapshot(
          tasks: [task('x', 'X').copyWith(list: 'À retirer')],
          projects: ['Personnel', 'À retirer'],
          deleted: {},
        ),
        baseline: null,
      );
      final next = await CloudSync.synchronize(
        cloud: cloud,
        local: snapshot([
          first.snapshot.tasks.single.copyWith(list: 'Personnel'),
        ]),
        baseline: first.baseline,
      );
      expect(next.snapshot.projects, ['Personnel']);
      expect(
        cloud.rows['poulpoints_project_records']!['À retirer']!['deleted'],
        true,
      );
      final other = await CloudSync.synchronize(
        cloud: cloud,
        local: first.snapshot,
        baseline: first.baseline,
      );
      expect(other.snapshot.projects, ['Personnel']);
      expect(other.snapshot.tasks.single.list, 'Personnel');
    },
  );
  test('Malformed new reminder and tag fields are rejected', () {
    for (final patch in [
      {
        'reminderOffsets': [-1],
      },
      {
        'reminderOffsets': [1, 2],
      },
      {
        'tags': [''],
      },
      {'snoozedUntil': 'invalid'},
    ]) {
      expect(
        () => TaskSnapshot.fromJson({
          ...snapshot().toJson(),
          'tasks': [
            {...task('a', 'A').toJson(), ...patch},
          ],
        }),
        throwsFormatException,
      );
    }
  });
}
