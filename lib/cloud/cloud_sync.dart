import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../storage/task_repository.dart';
import 'supabase_cloud.dart';

/// Deterministic canonical encoding: PostgreSQL jsonb does not preserve the
/// field insertion order from Dart maps.
String canonicalJson(Object? value) {
  Object? normalize(Object? source) {
    if (source is Map) {
      final keys = source.keys.map((e) => e.toString()).toList()..sort();
      return {for (final key in keys) key: normalize(source[key])};
    }
    if (source is List) return source.map(normalize).toList();
    return source;
  }

  return jsonEncode(normalize(value));
}

class CloudBaselineEntry {
  CloudBaselineEntry(this.signature, this.revision);
  final String signature;
  final int revision;
  Map<String, Object> toJson() => {
    'signature': signature,
    'revision': revision,
  };
  factory CloudBaselineEntry.fromJson(Map<String, dynamic> data) =>
      CloudBaselineEntry(
        data['signature'] as String,
        (data['revision'] as num).toInt(),
      );
}

class CloudBaseline {
  CloudBaseline({
    required this.identity,
    required this.tasks,
    required this.projects,
  });
  final String identity;
  final Map<String, CloudBaselineEntry> tasks;
  final Map<String, CloudBaselineEntry> projects;
  Map<String, Object> toJson() => {
    'identity': identity,
    'tasks': tasks.map((k, v) => MapEntry(k, v.toJson())),
    'projects': projects.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory CloudBaseline.fromJson(Map<String, dynamic> data) {
    Map<String, CloudBaselineEntry> read(String key) =>
        (data[key] as Map<String, dynamic>).map(
          (k, v) => MapEntry(
            k,
            CloudBaselineEntry.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        );
    return CloudBaseline(
      identity: data['identity'] as String,
      tasks: read('tasks'),
      projects: read('projects'),
    );
  }
}

class CloudSyncResult {
  CloudSyncResult(this.snapshot, this.baseline);
  final TaskSnapshot snapshot;
  final CloudBaseline baseline;
}

class _CloudRow {
  _CloudRow(this.id, this.deleted, this.payload, this.revision);
  final String id;
  final bool deleted;
  final Map<String, dynamic> payload;
  final int revision;
  String get taskSignature => deleted ? '#deleted' : canonicalJson(payload);
  String get projectSignature => deleted ? '#deleted' : '#active';
}

class _CloudWrite {
  _CloudWrite(this.id, this.deleted, this.payload, this.previousRevision);
  final String id;
  final bool deleted;
  final Map<String, dynamic> payload;
  final int? previousRevision;
}

class CloudConflict {
  const CloudConflict(this.label, this.local, this.remote);
  final String label;
  // Null denotes deletion/absence; both versions are shown before choosing.
  final Map<String, dynamic>? local;
  final Map<String, dynamic>? remote;
}

class CloudSync {
  static const baselineKey = 'poulpoints_cloud_baseline_v1';
  static const identityKey = 'poulpoints_cloud_bound_identity_v1';

  /// Produces an authenticated namespace. Changing the account while keeping
  /// this device's local snapshot is blocked to prevent cross-user data leaks.
  static String identity(SupabaseCloud cloud) => '${cloud.url}|${cloud.userId}';

  static CloudBaseline? loadBaseline(
    SharedPreferences prefs,
    SupabaseCloud cloud,
  ) {
    final wanted = identity(cloud);
    final bound = prefs.getString(identityKey);
    if (bound != null && bound != wanted) {
      throw const CloudException(
        'Cet appareil est associé à un autre compte ou serveur cloud. '
        'Exportez vos tâches et utilisez un profil local séparé avant de changer de compte.',
      );
    }
    final json = prefs.getString(baselineKey);
    if (json == null) return null;
    final baseline = CloudBaseline.fromJson(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
    if (baseline.identity != wanted) {
      throw const CloudException(
        'La configuration cloud ne correspond pas à la sauvegarde locale.',
      );
    }
    return baseline;
  }

  static Future<void> saveBaseline(
    SharedPreferences prefs,
    CloudBaseline baseline,
  ) async {
    // Persist binding first: a failed baseline save must never enable a switch
    // to a different account with the same local data.
    if (!await prefs.setString(identityKey, baseline.identity)) {
      throw const CloudException(
        'Impossible de conserver l’association du compte.',
      );
    }
    final saved = await prefs.setString(
      baselineKey,
      jsonEncode(baseline.toJson()),
    );
    if (!saved) {
      throw const CloudException('Impossible de conserver les versions cloud.');
    }
  }

  /// Reads both collections, computes a complete three-way plan *before* any
  /// write, rejects all unresolved concurrent modifications, then applies
  /// conditional updates using revision CAS. Returns a local snapshot, but
  /// caller must save it transactionally before persisting `baseline`.
  static Future<CloudSyncResult> synchronize({
    required SupabaseCloud cloud,
    required TaskSnapshot local,
    required CloudBaseline? baseline,
    Future<CloudDecision> Function(CloudConflict)? resolve,
  }) async {
    await cloud.checkAccess();
    if (baseline != null && _localMatches(local, baseline)) {
      final taskVersions = await cloud.readVersions('poulpoints_task_records');
      final projectVersions = await cloud.readVersions(
        'poulpoints_project_records',
      );
      if (_versionsMatch(taskVersions, 'task_id', baseline.tasks) &&
          _versionsMatch(projectVersions, 'project_name', baseline.projects)) {
        return CloudSyncResult(local, baseline);
      }
    }
    final remoteTasks = await _loadRemote(
      cloud,
      'poulpoints_task_records',
      'task_id',
    );
    final remoteProjects = await _loadRemote(
      cloud,
      'poulpoints_project_records',
      'project_name',
    );
    final localTasks = {for (final t in local.tasks) t.id: t};
    if (localTasks.keys.any(local.deleted.containsKey)) {
      throw const CloudException(
        'Sauvegarde locale incohérente : tâche à la fois active et supprimée.',
      );
    }
    final localDeleted = Map<String, int>.of(local.deleted);
    final localProjects = local.projects.toSet();
    final conflicts = <String>[];
    final taskWrites = <_CloudWrite>[];
    final projectWrites = <_CloudWrite>[];

    final taskIds = <String>{
      ...localTasks.keys,
      ...localDeleted.keys,
      ...remoteTasks.keys,
      ...?baseline?.tasks.keys,
    }.toList()..sort();
    for (final id in taskIds) {
      final task = localTasks[id];
      final localSig = localDeleted.containsKey(id)
          ? '#deleted'
          : task == null
          ? null
          : canonicalJson(task.toJson());
      final remote = remoteTasks[id];
      final remoteSig = remote?.taskSignature;
      final baseSig = baseline?.tasks[id]?.signature;
      var action = decideChange(localSig, remoteSig, baseSig);
      if (action == CloudDecision.conflict && resolve != null) {
        action = await resolve(
          CloudConflict(
            'Tâche $id',
            localSig == '#deleted' ? null : task?.toJson(),
            remote == null || remote.deleted ? null : remote.payload,
          ),
        );
        if (action != CloudDecision.push && action != CloudDecision.pull) {
          throw const CloudException(
            'Résolution des modifications concurrentes annulée.',
          );
        }
      }
      switch (action) {
        case CloudDecision.conflict:
          conflicts.add('Tâche $id');
        case CloudDecision.push:
          if (localSig != null) {
            taskWrites.add(
              _CloudWrite(
                id,
                localSig == '#deleted',
                task?.toJson() ?? {'id': id},
                remote?.revision,
              ),
            );
          }
        case CloudDecision.pull:
          if (remote != null && remote.deleted) {
            localTasks.remove(id);
            localDeleted[id] = DateTime.now().toUtc().microsecondsSinceEpoch;
          } else if (remote != null) {
            final downloaded = Task.fromJson(remote.payload);
            localTasks[id] = downloaded;
            localDeleted.remove(id);
          } else {
            // A server-side physical deletion is not part of our protocol.
            conflicts.add('Tâche disparue du serveur $id');
          }
        case CloudDecision.unchanged:
          break;
      }
    }

    final projectIds = <String>{
      ...localProjects,
      ...remoteProjects.keys,
      ...?baseline?.projects.keys,
    }.toList()..sort();
    for (final id in projectIds) {
      final localSig = localProjects.contains(id)
          ? '#active'
          : baseline?.projects.containsKey(id) == true
          ? '#deleted'
          : null;
      final remote = remoteProjects[id];
      final remoteSig = remote?.projectSignature;
      final baseSig = baseline?.projects[id]?.signature;
      var action = decideChange(localSig, remoteSig, baseSig);
      if (action == CloudDecision.conflict && resolve != null) {
        action = await resolve(
          CloudConflict(
            'Projet $id',
            localSig == '#active' ? {'Projet': id} : null,
            remoteSig == '#active' ? {'Projet': id} : null,
          ),
        );
        if (action != CloudDecision.push && action != CloudDecision.pull) {
          throw const CloudException(
            'Résolution des modifications concurrentes annulée.',
          );
        }
      }
      switch (action) {
        case CloudDecision.conflict:
          conflicts.add('Projet $id');
        case CloudDecision.push:
          if (localSig != null) {
            projectWrites.add(
              _CloudWrite(
                id,
                localSig == '#deleted',
                const {},
                remote?.revision,
              ),
            );
          }
        case CloudDecision.pull:
          if (remote?.deleted == false) {
            localProjects.add(id);
          } else if (remote?.deleted == true) {
            localProjects.remove(id);
          } else {
            conflicts.add('Projet disparu du serveur $id');
          }
        case CloudDecision.unchanged:
          break;
      }
    }
    if (conflicts.isNotEmpty) {
      throw CloudException(
        'Modifications concurrentes détectées (${conflicts.take(3).join(', ')}). '
        'Aucune donnée locale n’a été écrasée. Exportez une sauvegarde JSON avant de résoudre le conflit.',
      );
    }

    // Local validation before remote write. May add project names referenced
    // by downloaded tasks. Never silently discard imported data.
    final candidate = TaskSnapshot.fromJson({
      'schemaVersion': 3,
      'tasks': localTasks.values.map((t) => t.toJson()).toList(),
      'projects': localProjects.toList(),
      'deleted': localDeleted,
    });
    for (final project in candidate.projects) {
      if (!localProjects.contains(project)) {
        final existing = remoteProjects[project];
        if (existing == null) {
          projectWrites.add(_CloudWrite(project, false, const {}, null));
        } else if (existing.deleted) {
          throw CloudException(
            'Le projet $project a été supprimé dans le cloud.',
          );
        }
      }
    }

    // Partial server commits are possible on network errors; we never update
    // local snapshot or checkpoint in that case. Retrying may require manual
    // conflict resolution rather than destructive automatic merging.
    for (final change in projectWrites) {
      await cloud.writeRecord(
        table: 'poulpoints_project_records',
        idColumn: 'project_name',
        id: change.id,
        values: {'deleted': change.deleted},
        expectedRevision: change.previousRevision,
      );
    }
    for (final change in taskWrites) {
      await cloud.writeRecord(
        table: 'poulpoints_task_records',
        idColumn: 'task_id',
        id: change.id,
        values: {'deleted': change.deleted, 'payload': change.payload},
        expectedRevision: change.previousRevision,
      );
    }

    final verifiedTasks = await _loadRemote(
      cloud,
      'poulpoints_task_records',
      'task_id',
    );
    final verifiedProjects = await _loadRemote(
      cloud,
      'poulpoints_project_records',
      'project_name',
    );
    final allLocal = {for (final t in candidate.tasks) t.id: t};
    if ({
      ...allLocal.keys,
      ...candidate.deleted.keys,
    }.any((id) => !verifiedTasks.containsKey(id))) {
      throw const CloudException(
        'Conflit cloud : enregistrement disparu pendant la vérification.',
      );
    }
    for (final entry in verifiedTasks.entries) {
      final want = candidate.deleted.containsKey(entry.key)
          ? '#deleted'
          : allLocal[entry.key] == null
          ? null
          : canonicalJson(allLocal[entry.key]!.toJson());
      if (want != entry.value.taskSignature) {
        throw CloudException(
          'Modification distante apparue pendant la synchronisation (${entry.key}).',
        );
      }
    }
    for (final entry in verifiedProjects.entries) {
      final want = candidate.projects.contains(entry.key)
          ? '#active'
          : '#deleted';
      if (want != entry.value.projectSignature) {
        throw CloudException('Modification distante du projet ${entry.key}.');
      }
    }
    final next = CloudBaseline(
      identity: identity(cloud),
      tasks: verifiedTasks.map(
        (id, row) =>
            MapEntry(id, CloudBaselineEntry(row.taskSignature, row.revision)),
      ),
      projects: verifiedProjects.map(
        (id, row) => MapEntry(
          id,
          CloudBaselineEntry(row.projectSignature, row.revision),
        ),
      ),
    );
    return CloudSyncResult(candidate, next);
  }

  static bool _localMatches(TaskSnapshot local, CloudBaseline base) {
    final signatures = {
      for (final t in local.tasks) t.id: canonicalJson(t.toJson()),
      for (final id in local.deleted.keys) id: '#deleted',
    };
    if (signatures.length != base.tasks.length ||
        signatures.entries.any(
          (e) => base.tasks[e.key]?.signature != e.value,
        )) {
      return false;
    }
    if (local.projects.any((p) => !base.projects.containsKey(p))) return false;
    return base.projects.entries.every(
      (e) =>
          e.value.signature ==
          (local.projects.contains(e.key) ? '#active' : '#deleted'),
    );
  }

  static bool _versionsMatch(
    List<Map<String, dynamic>> rows,
    String idKey,
    Map<String, CloudBaselineEntry> base,
  ) {
    if (rows.length != base.length ||
        rows.map((r) => r[idKey]).toSet().length != rows.length) {
      return false;
    }
    return rows.every(
      (r) =>
          base[r[idKey]]?.revision == r['revision'] &&
          (base[r[idKey]]?.signature == '#deleted') == r['deleted'],
    );
  }

  static Future<Map<String, _CloudRow>> _loadRemote(
    SupabaseCloud cloud,
    String table,
    String idColumn,
  ) async {
    final records = await cloud.readRows(table);
    final result = <String, _CloudRow>{};
    for (final row in records) {
      final id = row[idColumn] as String;
      final deleted = row['deleted'] as bool;
      if (result.containsKey(id)) {
        throw const CloudException('Conflit cloud : pagination instable.');
      }
      if (table == 'poulpoints_task_records' && !deleted) {
        final payload = Map<String, dynamic>.from(row['payload'] as Map);
        if (payload['id'] != id) {
          throw const CloudException('Identifiant distant incohérent.');
        }
        TaskSnapshot.fromJson({
          'schemaVersion': 3,
          'tasks': [payload],
          'projects': <String>[],
          'deleted': <String, int>{},
        });
      }
      result[id] = _CloudRow(
        id,
        deleted,
        table == 'poulpoints_task_records'
            ? Map<String, dynamic>.from(row['payload'] as Map)
            : <String, dynamic>{},
        (row['revision'] as num).toInt(),
      );
    }
    return result;
  }
}

enum CloudDecision { unchanged, push, pull, conflict }

/// Same logic for records, tombstones and project state.
/// `null` means absent (as opposed to '#deleted').
CloudDecision decideChange(String? local, String? remote, String? base) {
  if (local == remote) return CloudDecision.unchanged;
  if (base == null) {
    if (local == null) return CloudDecision.pull;
    if (remote == null) return CloudDecision.push;
    return CloudDecision.conflict;
  }
  if (local == base) return CloudDecision.pull;
  if (remote == base) return CloudDecision.push;
  return CloudDecision.conflict;
}

/// Keep edits made while HTTP requests were in flight. The remote checkpoint
/// still describes the synchronized snapshot, so these edits are pushed next.
TaskSnapshot rebaseLocalEdits(
  TaskSnapshot started,
  TaskSnapshot current,
  TaskSnapshot synchronized,
) {
  Map<String, Task> tasks(TaskSnapshot s) => {for (final t in s.tasks) t.id: t};
  final before = tasks(started),
      now = tasks(current),
      remote = tasks(synchronized);
  String? signature(TaskSnapshot s, Map<String, Task> map, String id) =>
      s.deleted.containsKey(id)
      ? '#deleted'
      : map[id] == null
      ? null
      : canonicalJson(map[id]!.toJson());
  final merged = Map<String, Task>.of(remote);
  final deleted = Map<String, int>.of(synchronized.deleted);
  for (final id in {
    ...before.keys,
    ...now.keys,
    ...remote.keys,
    ...started.deleted.keys,
    ...current.deleted.keys,
    ...synchronized.deleted.keys,
  }) {
    final base = signature(started, before, id);
    final local = signature(current, now, id);
    final server = signature(synchronized, remote, id);
    final decision = decideChange(local, server, base);
    if (decision == CloudDecision.conflict) {
      throw CloudException(
        'Modifications concurrentes détectées pour la tâche $id.',
      );
    }
    if (decision == CloudDecision.push) {
      if (current.deleted.containsKey(id)) {
        merged.remove(id);
        deleted[id] = current.deleted[id]!;
      } else if (now.containsKey(id)) {
        merged[id] = now[id]!;
        deleted.remove(id);
      }
    }
  }
  final projects = synchronized.projects.toSet();
  projects.addAll(current.projects.where((p) => !started.projects.contains(p)));
  projects.removeAll(
    started.projects.where((p) => !current.projects.contains(p)),
  );
  return TaskSnapshot.fromJson({
    'schemaVersion': 3,
    'tasks': merged.values.map((t) => t.toJson()).toList(),
    'projects': projects.toList(),
    'deleted': deleted,
  });
}
