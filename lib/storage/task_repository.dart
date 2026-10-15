import 'dart:convert';

import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../task_actions.dart';
import 'database_handle.dart';
import 'open_native.dart' if (dart.library.js_interop) 'open_web.dart';

class TaskSnapshot {
  TaskSnapshot({
    required List<Task> tasks,
    required List<String> projects,
    required Map<String, int> deleted,
  }) : tasks = List.unmodifiable(tasks),
       projects = List.unmodifiable(projects),
       deleted = Map.unmodifiable(deleted);
  final List<Task> tasks;
  final List<String> projects;
  final Map<String, int> deleted;
  Map<String, dynamic> toJson() => {
    'schemaVersion': 3,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'projects': projects,
    'deleted': deleted,
  };
  factory TaskSnapshot.fromJson(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 3) {
      throw const FormatException('Version de sauvegarde incompatible');
    }
    for (final raw in data['tasks'] as List) {
      final item = raw as Map;
      final reminder = item['reminderMinutes'];
      if (reminder != null &&
          (reminder is! int ||
              reminder < 0 ||
              reminder > 525600 ||
              item['dueDate'] == null ||
              item['hasDueTime'] != true)) {
        throw const FormatException('Rappel invalide : date et heure requises');
      }
      final offsets = item['reminderOffsets'];
      if (offsets != null &&
          (offsets is! List ||
              offsets.length > 20 ||
              offsets.any((v) => v is! int || v < 0 || v > 525600) ||
              (offsets.isNotEmpty &&
                  (item['dueDate'] == null || item['hasDueTime'] != true)))) {
        throw const FormatException('Liste de rappels invalide');
      }
      final tags = item['tags'];
      if (tags != null &&
          (tags is! List ||
              tags.length > 50 ||
              tags.any(
                (v) => v is! String || v.trim().isEmpty || v.length > 100,
              ))) {
        throw const FormatException('Étiquettes invalides');
      }
      for (final field in ['occurrenceAnchor', 'snoozedUntil']) {
        if (item[field] != null &&
            (item[field] is! String ||
                DateTime.tryParse(item[field]) == null)) {
          throw FormatException('Date invalide : $field');
        }
      }
      final recurrence = item['recurrence'];
      if (recurrence != null && !recurrenceLabels.containsKey(recurrence)) {
        throw const FormatException('Règle de répétition inconnue');
      }
      if (item['dueDate'] != null &&
          DateTime.tryParse(item['dueDate'] as String) == null) {
        throw const FormatException('Date d’échéance invalide');
      }
    }
    final tasks = (data['tasks'] as List)
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final projects = (data['projects'] as List).cast<String>().toList();
    final deleted = (data['deleted'] as Map).map(
      (k, v) => MapEntry(k as String, v as int),
    );
    if (tasks.map((t) => t.id).toSet().length != tasks.length ||
        tasks.any(
          (t) =>
              t.id.isEmpty ||
              t.title.trim().isEmpty ||
              t.list.trim().isEmpty ||
              t.subtasks.map((s) => s.id).toSet().length != t.subtasks.length ||
              (t.recurrence == 'custom' && t.recurrenceRule == null),
        ) ||
        projects.any((p) => p.trim().isEmpty) ||
        deleted.values.any((v) => v < 0)) {
      throw const FormatException(
        'Sauvegarde invalide : tâches ou projets incohérents',
      );
    }
    for (final t in tasks) {
      if (!projects.contains(t.list)) projects.add(t.list);
    }
    return TaskSnapshot(
      tasks: tasks,
      projects: projects.toSet().toList(),
      deleted: deleted,
    );
  }
}

class TaskRepository {
  TaskRepository(this.handle);
  final DatabaseHandle handle;
  final _records = stringMapStoreFactory.store('poulpoints');
  Future<void> _pending = Future.value();
  int? _revision;
  static Future<TaskRepository> open() async =>
      TaskRepository(await openStorage());

  Future<T> _serialize<T>(Future<T> Function() action) {
    final job = _pending.then((_) => action());
    _pending = job.then((_) {}, onError: (Object _, StackTrace __) {});
    return job;
  }

  Future<TaskSnapshot> load(SharedPreferences prefs) => _serialize(() async {
    final result = await handle.db.transaction((txn) async {
      final current = await _records.record('current').get(txn);
      if (current != null) {
        if (current['storageVersion'] != 1) {
          throw const FormatException('Version de stockage incompatible');
        }
        return current;
      }
      // Parse everything before the transaction writes anything. Legacy keys
      // are deliberately retained as a pre-migration backup, never rewritten.
      final rawTasks = prefs.getString('poulpoints_tasks_v1');
      final rawDeleted = prefs.getString('poulpoints_deletions_v3');
      final snapshot = TaskSnapshot.fromJson({
        'schemaVersion': 3,
        'tasks': rawTasks == null ? <dynamic>[] : jsonDecode(rawTasks),
        'projects':
            prefs.getStringList('poulpoints_projects_v2') ??
            ['Personnel', 'Travail'],
        'deleted': rawDeleted == null
            ? <String, dynamic>{}
            : jsonDecode(rawDeleted),
      });
      final envelope = <String, Object?>{
        'storageVersion': 1,
        'revision': 0,
        'snapshot': snapshot.toJson(),
      };
      await _records.record('current').put(txn, envelope);
      await _records.record('migration').put(txn, {
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'snapshot': snapshot.toJson(),
      });
      return envelope;
    });
    final snapshot = TaskSnapshot.fromJson(
      Map<String, dynamic>.from(result['snapshot'] as Map),
    );
    _revision = result['revision'] as int;
    return snapshot;
  });

  Future<Map<String, dynamic>?> readCloudCheckpoint() async {
    await _pending;
    final current = await _records.record('current').get(handle.db);
    final value = current?['cloudBaseline'];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<void> saveCloud(
    TaskSnapshot snapshot,
    Map<String, dynamic> checkpoint,
  ) => _save(snapshot, checkpoint: checkpoint);

  Future<void> save(TaskSnapshot snapshot) => _save(snapshot);

  Future<void> _save(
    TaskSnapshot snapshot, {
    Map<String, dynamic>? checkpoint,
  }) {
    // Freeze caller-owned lists before awaiting prior writes.
    final frozen = TaskSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
    );
    final job = _pending.then((_) async {
      if (_revision == null) {
        throw StateError('Chargement requis avant sauvegarde');
      }
      final expected = _revision!;
      await handle.db.transaction((txn) async {
        final current = await _records.record('current').get(txn);
        if (current == null || current['revision'] != expected) {
          throw StateError(
            'Données modifiées dans une autre fenêtre. Exportez vos changements puis relancez Poulpoints.',
          );
        }
        // Backup and all collections commit together, or none of them do.
        await _records.record('previous').put(txn, current);
        await _records.record('current').put(txn, {
          'storageVersion': 1,
          'revision': expected + 1,
          'snapshot': frozen.toJson(),
          if (current['widgetReceipts'] != null)
            'widgetReceipts': current['widgetReceipts'],
          if (checkpoint ?? current['cloudBaseline'] case final Map value)
            'cloudBaseline': value,
        });
      });
      _revision = expected + 1;
    });
    // A failed write must not prevent a subsequent explicit retry.
    _pending = job.then((_) {}, onError: (Object _, StackTrace __) {});
    return job;
  }

  /// Read and mutate the latest durable state in one transaction. The task
  /// version and durable receipt make repeated clicks/retries idempotent.
  Future<WidgetCompletion> completeFromWidget(
    String token,
    String id,
    String expectedVersion, {
    bool snooze = false,
  }) => _serialize(() async {
    final result = await handle.db.transaction((txn) async {
      final current = await _records.record('current').get(txn);
      if (current == null) {
        throw StateError('Chargement requis avant une action du widget');
      }
      final snapshot = TaskSnapshot.fromJson(
        Map<String, dynamic>.from(current['snapshot'] as Map),
      );
      final receipts = List<String>.from(
        current['widgetReceipts'] as List? ?? [],
      );
      final revision = current['revision'] as int;
      if (receipts.contains(token)) {
        return (
          snapshot: snapshot,
          revision: revision,
          accepted: true,
          changed: false,
        );
      }
      final index = snapshot.tasks.indexWhere((t) => t.id == id);
      final accepted =
          index >= 0 &&
          !snapshot.tasks[index].done &&
          snapshot.tasks[index].updatedAt.toString() == expectedVersion;
      if (!accepted) {
        return (
          snapshot: snapshot,
          revision: revision,
          accepted: false,
          changed: false,
        );
      }
      final tasks = snapshot.tasks.toList();
      tasks[index] = snooze
          ? tasks[index].copyWith(
              snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
            )
          : completeTask(tasks[index], true);
      final next = TaskSnapshot(
        tasks: tasks,
        projects: snapshot.projects,
        deleted: snapshot.deleted,
      );
      receipts.add(token);
      if (receipts.length > 256) receipts.removeRange(0, receipts.length - 256);
      await _records.record('previous').put(txn, current);
      await _records.record('current').put(txn, {
        ...current,
        'revision': revision + 1,
        'snapshot': next.toJson(),
        'widgetReceipts': receipts,
      });
      return (
        snapshot: next,
        revision: revision + 1,
        accepted: true,
        changed: true,
      );
    });
    _revision = result.revision;
    return WidgetCompletion(
      result.snapshot,
      accepted: result.accepted,
      changed: result.changed,
    );
  });

  Future<TaskSnapshot?> previous() async {
    await _pending;
    final data = await _records.record('previous').get(handle.db);
    return data == null
        ? null
        : TaskSnapshot.fromJson(
            Map<String, dynamic>.from(data['snapshot'] as Map),
          );
  }

  Future<void> close() async {
    await _pending;
    await handle.close();
  }
}

class WidgetCompletion {
  const WidgetCompletion(
    this.snapshot, {
    required this.accepted,
    required this.changed,
  });
  final TaskSnapshot snapshot;
  final bool accepted;
  final bool changed;
}
