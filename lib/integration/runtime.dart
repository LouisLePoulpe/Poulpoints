import 'dart:async';
import '../cloud/cloud_sync.dart';
import '../cloud/supabase_cloud.dart';
import '../cloud/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/task_repository.dart';
import 'platform_bridge.dart';
import 'projection.dart';

/// One repository and one Flutter engine serve both Android UI and workers.
/// The cold path runs before runApp: it does not depend on rendering a frame.
class IntegrationRuntime {
  static final instance = IntegrationRuntime();
  IntegrationRuntime({
    PlatformBridge? bridge,
    Future<TaskRepository>? repository,
    SessionStore? sessionStore,
    this.cloudFactory,
  }) : bridge = bridge ?? PlatformBridge(),
       _repository = repository,
       sessionStore = sessionStore ?? SecureSessionStore();
  final PlatformBridge bridge;
  final SessionStore sessionStore;
  final SupabaseCloud Function(String url, String key, SessionStore store)?
  cloudFactory;
  Future<TaskRepository>? _repository;
  Future<void> Function()? uiProcessor;
  Future<void> Function()? uiSync;
  bool _working = false;
  Completer<void>? _idle;
  Future<void> waitUntilIdle() async {
    await _idle?.future;
  }

  bool get shared => bridge.usesSharedRuntime;
  Future<TaskRepository> repository() => _repository ??= TaskRepository.open();
  Future<void> start() async {
    if (!shared) return;
    bridge.setCommandHandler(process, sync: synchronize);
    await bridge.ready();
    try {
      await process();
    } catch (_) {
      await bridge.reportWidgetError(
        'Sauvegarde indisponible. Ouvrez Poulpoints pour vérifier vos données.',
      );
    }
  }

  Future<void> synchronize() async {
    // A cold worker and the first visible frame must never use stale copies.
    while (_working) {
      await waitUntilIdle();
    }
    if (uiSync != null) {
      await uiSync!();
      return;
    }
    _working = true;
    _idle = Completer<void>();
    SupabaseCloud? cloud;
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('poulpoints_supabase_url_v1') ?? '';
      final key = prefs.getString('poulpoints_supabase_public_key_v1') ?? '';
      if (url.isEmpty || key.isEmpty) return;
      final store = sessionStore;
      final session = await store.read();
      if (session == null) return;
      cloud =
          cloudFactory?.call(url, key, store) ??
          SupabaseCloud(url: url, publicKey: key, sessionStore: store);
      cloud.restoreSession(session);
      final repo = await repository();
      final local = await repo.load(prefs);
      final legacy = CloudSync.loadBaseline(prefs, cloud);
      final checkpoint = await repo.readCloudCheckpoint();
      final baseline = checkpoint == null
          ? legacy
          : CloudBaseline.fromJson(checkpoint);
      if (baseline != null && baseline.identity != CloudSync.identity(cloud)) {
        throw const CloudException(
          'Ce stockage appartient à un autre compte cloud.',
        );
      }
      final result = await CloudSync.synchronize(
        cloud: cloud,
        local: local,
        baseline: baseline,
      );
      await repo.saveCloud(result.snapshot, result.baseline.toJson());
      await bridge.publish(projectTasks(result.snapshot.tasks));
    } finally {
      cloud?.dispose();
      _idle!.complete();
      _idle = null;
      _working = false;
    }
  }

  Future<void> process() async {
    if (_working) return;
    _working = true;
    _idle = Completer<void>();
    try {
      if (uiProcessor != null) {
        await uiProcessor!();
        return;
      }
      final repo = await repository();
      await repo.load(await SharedPreferences.getInstance());
      for (final command in await bridge.commands()) {
        if (!['complete', 'snooze'].contains(command['action'])) continue;
        final result = await repo.completeFromWidget(
          command['token'] as String,
          command['id'] as String,
          command['revision'] as String,
          snooze: command['action'] == 'snooze',
        );
        // Do not acknowledge until projection/alarms are also durable. A retry
        // reads the receipt and republishes without advancing a recurrence twice.
        await bridge.publish(projectTasks(result.snapshot.tasks));
        if (!result.accepted) {
          await bridge.reportWidgetError(
            'Tâche déjà modifiée. Le widget a été actualisé.',
          );
        }
        await bridge.ack(command['token'] as String);
      }
    } catch (_) {
      await bridge.reportWidgetError(
        'Validation en attente. Ouvrez Poulpoints pour vérifier vos données.',
      );
      rethrow;
    } finally {
      _idle!.complete();
      _idle = null;
      _working = false;
    }
  }
}
