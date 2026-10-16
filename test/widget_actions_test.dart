import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:poulpoints/main.dart';
import 'package:poulpoints/task_actions.dart';
import 'package:poulpoints/integration/platform_bridge.dart';
import 'package:poulpoints/storage/database_handle.dart';
import 'package:poulpoints/storage/task_repository.dart';

class MemoryBridge extends PlatformBridge {
  final pending = <Map<String, dynamic>>[];
  Map<String, dynamic>? projection;
  @override
  Future<void> reportWidgetError(String message) async {}
  @override
  Future<void> publish(Map<String, dynamic> data) async {
    projection = data;
  }

  @override
  Future<List<Map<String, dynamic>>> commands() async => List.of(pending);
  @override
  Future<void> ack(String token) async {
    pending.removeWhere((c) => c['token'] == token);
  }
}

class ImmediateRepository extends TaskRepository {
  ImmediateRepository(super.handle);
  TaskSnapshot data = TaskSnapshot(
    tasks: [
      Task(
        id: 'one',
        title: 'Récurrente',
        list: 'Personnel',
        dueDate: DateTime(2027, 1, 2, 10),
        hasDueTime: true,
        recurrence: 'daily',
        reminderMinutes: 15,
        updatedAt: 42,
      ),
    ],
    projects: ['Personnel'],
    deleted: {},
  );
  @override
  Future<TaskSnapshot> load(SharedPreferences prefs) async => data;
  @override
  Future<WidgetCompletion> completeFromWidget(
    String token,
    String id,
    String revision, {
    bool snooze = false,
  }) async {
    final index = data.tasks.indexWhere(
      (t) => t.id == id && t.updatedAt.toString() == revision,
    );
    if (index < 0) {
      return WidgetCompletion(data, accepted: false, changed: false);
    }
    final tasks = data.tasks.toList();
    tasks[index] = snooze
        ? tasks[index].copyWith(
            snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
          )
        : completeTask(tasks[index], true);
    data = TaskSnapshot(
      tasks: tasks,
      projects: data.projects,
      deleted: data.deleted,
    );
    return WidgetCompletion(data, accepted: true, changed: true);
  }

  @override
  Future<void> save(TaskSnapshot snapshot) async {
    data = snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImmediateRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = ImmediateRepository(
      DatabaseHandle(
        await newDatabaseFactoryMemory().openDatabase('widget-actions'),
      ),
    );
  });
  tearDown(() => repository.close());
  testWidgets('Widget title opens details without changing the task', (
    tester,
  ) async {
    final bridge = MemoryBridge();
    await tester.pumpWidget(
      PoulpointsApp(repository: repository, integrationBridge: bridge),
    );
    await tester.pumpAndSettle();
    bridge.pending.add({
      'token': 'open',
      'action': 'open-task',
      'id': 'one',
      'revision': 'old',
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(bridge.pending, isEmpty);
    expect(repository.data.tasks.single.updatedAt, 42);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'Widget completion saves and reschedules once; stale duplicate is ignored',
    (tester) async {
      final bridge = MemoryBridge();
      await tester.pumpWidget(
        PoulpointsApp(repository: repository, integrationBridge: bridge),
      );
      await tester.pumpAndSettle();
      bridge.pending.add({
        'token': 'first',
        'action': 'complete',
        'id': 'one',
        'revision': '42',
      });
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(repository.data.tasks.single.dueDate, DateTime(2027, 1, 3, 10));
      expect(bridge.pending, isEmpty);
      expect(
        bridge.projection!['tasks'][0]['remindAt'],
        DateTime(2027, 1, 3, 9, 45).millisecondsSinceEpoch,
      );
      bridge.pending.add({
        'token': 'duplicate',
        'action': 'complete',
        'id': 'one',
        'revision': '42',
      });
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(repository.data.tasks.single.dueDate, DateTime(2027, 1, 3, 10));
      expect(bridge.pending, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
