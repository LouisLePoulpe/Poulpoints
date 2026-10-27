import 'attachments.dart';
import 'calendar_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';
import 'dart:async';

import 'cloud/supabase_cloud.dart';
import 'cloud/cloud_login_dialog.dart';
import 'cloud/cloud_sync.dart';
import 'cloud/session_store.dart';

import 'task_editor.dart';
import 'task_actions.dart' show moveOccurrence;
import 'models.dart';
import 'deadline_status.dart';
import 'app_metadata.dart';
import 'default_project.dart';
import 'integration/platform_bridge.dart';
import 'integration/projection.dart';
import 'integration/runtime.dart';
export 'models.dart' show Task, Subtask;
import 'storage/task_repository.dart';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conservative network retry: at most one periodic check per minute while
/// the application is in the foreground, and exponential backoff on errors.
Duration cloudRetryDelay(int failures) {
  final capped = failures < 1 ? 1 : (failures > 5 ? 5 : failures);
  final seconds = 15 * (1 << (capped - 1));
  return Duration(seconds: seconds > 240 ? 240 : seconds);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IntegrationRuntime.instance.start();
  runApp(const PoulpointsApp());
}

class PoulpointsApp extends StatefulWidget {
  const PoulpointsApp({super.key, this.repository, this.integrationBridge});
  final TaskRepository? repository;
  final PlatformBridge? integrationBridge;
  @override
  State<PoulpointsApp> createState() => _PoulpointsAppState();
}

class _PoulpointsAppState extends State<PoulpointsApp> {
  ThemeMode themeMode = ThemeMode.system;
  bool monday = true;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => monday = prefs.getBool('calendar_monday') ?? true);
      }
    });
  }

  Future<void> changeFirstDay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calendar_monday', value);
    if (mounted) setState(() => monday = value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Poulpoints',
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: [
      PoulpointsCalendarDelegate(monday),
      ...GlobalMaterialLocalizations.delegates,
    ],
    debugShowCheckedModeBanner: false,
    themeMode: themeMode,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: TasksPage(
      repository: widget.repository,
      integrationBridge: widget.integrationBridge,
      monday: monday,
      onFirstDayChanged: changeFirstDay,
      themeMode: themeMode,
      onThemeModeChanged: (mode) => setState(() => themeMode = mode),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0878F9),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF5F8FC)
          : const Color(0xFF101A28),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    this.repository,
    this.integrationBridge,
    this.monday = true,
    this.onFirstDayChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });
  final TaskRepository? repository;
  final PlatformBridge? integrationBridge;
  final bool monday;
  final ValueChanged<bool>? onFirstDayChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with WidgetsBindingObserver {
  static const _cloudUrlKey = 'poulpoints_supabase_url_v1';
  static const _cloudPublicKeyKey = 'poulpoints_supabase_public_key_v1';
  SupabaseCloud? _cloud;
  final SessionStore _sessionStore = SecureSessionStore();
  Timer? _cloudTimer;
  Timer? _cloudPeriodicTimer;
  bool _cloudSyncing = false;
  bool _cloudReadyForAuto = false;
  bool _cloudInForeground = true;
  bool get _desktopResident =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  bool _cloudSyncQueued = false;
  bool _cloudApplying = false;
  int _cloudFailureCount = 0;
  DateTime? _cloudRetryAfter;
  int _localEditRevision = 0;
  String _cloudUrl = '';
  String _cloudPublicKey = '';
  String _cloudStatus = 'Non connecté';
  static const _defaultProjectKey = 'poulpoints_default_project_v1';
  String? _defaultProject;
  static const _syncUrlKey = 'poulpoints_sync_url_v3';
  static const _syncTokenKey = 'poulpoints_sync_token_v3';
  final Map<String, int> _deletions = {};
  String _syncUrl = '';
  String _syncToken = '';
  bool _syncing = false;
  final List<Task> _tasks = [];
  final List<String> _projects = ['Personnel', 'Travail'];
  Task? _selectedTask;
  bool _showStats = false;
  bool _showSettings = false;
  String _selection = 'Toutes';
  String _search = '';
  bool _loaded = false;
  late final _bridge = widget.integrationBridge ?? PlatformBridge();
  Timer? _bridgeTimer;
  bool _readingCommands = false;
  bool _editorOpen = false;
  bool _widgetApplying = false;
  Future<void> _bridgeWrites = Future.value();
  String _integrationStatus = 'Rappels locaux et widgets Android / KDE Plasma';

  Future<bool> _publishIntegration(TaskSnapshot snapshot) async {
    if (widget.repository != null && widget.integrationBridge == null) {
      return true;
    }
    var succeeded = true;
    final data = projectTasks(snapshot.tasks);
    _bridgeWrites = _bridgeWrites.then((_) => _bridge.publish(data)).catchError((
      Object error,
    ) {
      succeeded = false;
      if (mounted) {
        setState(
          () => _integrationStatus =
              'Actualisation des rappels/widgets impossible. Réessayez depuis les paramètres.',
        );
      }
    });
    await _bridgeWrites;
    return succeeded;
  }

  Future<void> _readWidgetCommands() async {
    if ((widget.repository != null && widget.integrationBridge == null) ||
        _readingCommands ||
        _cloudSyncing ||
        !_canEdit ||
        _saving > 0 ||
        _editorOpen ||
        _saveError != null) {
      return;
    }
    _readingCommands = true;
    try {
      for (final command in await _bridge.commands()) {
        if (!mounted || !_canEdit || _saving > 0 || _editorOpen) return;
        final token = command['token'] as String;
        if (command['action'] == 'open-task') {
          await _bridge.ack(token);
          if (!mounted) return;
          final matches = _tasks.where((task) => task.id == command['id']);
          if (matches.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cette tâche n’est plus disponible.'),
              ),
            );
          } else if (MediaQuery.sizeOf(context).width >= 850) {
            setState(() => _selectedTask = matches.first);
          } else {
            await _showTaskDetails(matches.first);
          }
          continue;
        }
        if (command['action'] == 'new') {
          await _bridge.ack(token);
          await _openEditor();
          continue;
        }
        if (['complete', 'snooze'].contains(command['action'])) {
          _widgetApplying = true;
          _saving++;
          try {
            final result = await _repository!.completeFromWidget(
              token,
              command['id'] as String,
              command['revision'] as String,
              snooze: command['action'] == 'snooze',
            );
            if (!mounted) return;
            setState(() => _apply(result.snapshot));
            if (result.changed) {
              _localEditRevision++;
              _scheduleCloudSync();
            }
            if (!await _publishIntegration(result.snapshot)) return;
            if (!result.accepted) {
              await _bridge.reportWidgetError(
                'Tâche déjà modifiée. Le widget a été actualisé.',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cette tâche a changé depuis l’affichage du widget. Vérifiez sa nouvelle version.',
                    ),
                  ),
                );
              }
            }
          } finally {
            _widgetApplying = false;
            if (mounted) setState(() => _saving--);
          }
        }
        await _bridge.ack(token);
      }
    } catch (_) {
      await _bridge.reportWidgetError(
        'Validation en attente. Ouvrez Poulpoints pour vérifier vos données.',
      );
      if (mounted) {
        setState(
          () => _integrationStatus =
              'Lecture des actions du widget impossible. Relancez Poulpoints.',
        );
      }
    } finally {
      _readingCommands = false;
    }
  }

  Future<void> _configureReminders({bool exact = false}) async {
    try {
      final status = await _bridge.permissions(request: !exact, exact: exact);
      await _publishIntegration(_snapshot);
      if (mounted) setState(() => _integrationStatus = status);
    } catch (_) {
      if (mounted) {
        setState(
          () => _integrationStatus =
              'Permissions indisponibles sur cet appareil.',
        );
      }
    }
  }

  TaskRepository? _repository;
  String? _loadError;
  String? _saveError;
  int _saving = 0;
  // A slow cloud request should not prevent working offline.
  bool get _canEdit =>
      _loaded && !_syncing && !_cloudApplying && !_widgetApplying;
  TaskSnapshot get _snapshot =>
      TaskSnapshot(tasks: _tasks, projects: _projects, deleted: _deletions);
  void _apply(TaskSnapshot data) {
    _tasks
      ..clear()
      ..addAll(data.tasks);
    _projects
      ..clear()
      ..addAll(data.projects);
    _deletions
      ..clear()
      ..addAll(data.deleted);
    _selectedTask = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cloudTimer?.cancel();
    _bridgeTimer?.cancel();
    _cloudPeriodicTimer?.cancel();
    _cloud?.dispose();
    if (widget.repository == null) {
      if (IntegrationRuntime.instance.shared) {
        IntegrationRuntime.instance.uiProcessor = null;
        IntegrationRuntime.instance.uiSync = null;
      } else {
        _repository?.close();
      }
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudInForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (widget.repository == null && IntegrationRuntime.instance.shared) {
      IntegrationRuntime.instance.uiProcessor = _readWidgetCommands;
      IntegrationRuntime.instance.uiSync = () async {
        if (!_loaded ||
            _saving > 0 ||
            _readingCommands ||
            _cloudSyncing ||
            _editorOpen) {
          throw StateError('Application occupée, réessayer plus tard.');
        }
        await _syncCloud(silent: true);
      };
    }
    // The Linux resident remains active while its window is hidden.
    // Local edits are pushed much sooner (debounced in _save).
    _cloudPeriodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Ensure an open task list crosses its due time without user input.
      if (mounted &&
          _cloudInForeground &&
          _loaded &&
          _tasks.any((task) => !task.done && task.dueDate != null)) {
        setState(() {});
      }
      if (_desktopResident && _loaded && _cloud == null) {
        // The session vault may only become available after desktop login.
        _restoreCloudSession();
      } else {
        _scheduleCloudSync(delay: Duration.zero);
      }
    });
    if (widget.repository == null || widget.integrationBridge != null) {
      _bridgeTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _readWidgetCommands(),
      );
    }
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cloudInForeground = true;
      if (_loaded && _cloud == null) unawaited(_restoreCloudSession());
      _readWidgetCommands();
      _scheduleCloudSync(delay: const Duration(milliseconds: 600));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _cloudInForeground = false;
      // Keep a durable network attempt when the user leaves before debounce.
      unawaited(_bridge.scheduleSync().catchError((Object _) {}));
      if (!_desktopResident) _cloudTimer?.cancel();
    }
  }

  /// Coalesces edits, foreground refreshes and retries to protect the free
  /// Supabase quota. A failed network request is retried while the app is open.
  void _scheduleCloudSync({Duration delay = const Duration(seconds: 2)}) {
    if (_cloud?.signedIn != true ||
        !_cloudReadyForAuto ||
        (!_cloudInForeground && !_desktopResident) ||
        !_loaded ||
        _syncing) {
      return;
    }
    if (_cloudSyncing) {
      _cloudSyncQueued = true;
      return;
    }
    final waitUntil = _cloudRetryAfter;
    if (waitUntil != null) {
      final remaining = waitUntil.difference(DateTime.now());
      if (remaining > delay) delay = remaining;
    }
    _cloudTimer?.cancel();
    _cloudTimer = Timer(delay, () {
      if (!mounted) return;
      if (_saving > 0) {
        _scheduleCloudSync(delay: const Duration(seconds: 1));
      } else {
        _syncCloud(silent: true);
      }
    });
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (widget.repository == null && IntegrationRuntime.instance.shared) {
        await IntegrationRuntime.instance.waitUntilIdle();
      }
      _repository ??=
          widget.repository ??
          await (IntegrationRuntime.instance.shared
              ? IntegrationRuntime.instance.repository()
              : TaskRepository.open());
      final data = await _repository!.load(prefs);
      if (!mounted) return;
      setState(() {
        _apply(data);
        _defaultProject = prefs.getString(_defaultProjectKey);
        _syncUrl = prefs.getString(_syncUrlKey) ?? '';
        _syncToken = prefs.getString(_syncTokenKey) ?? '';
        _cloudUrl = prefs.getString(_cloudUrlKey) ?? '';
        _cloudPublicKey = prefs.getString(_cloudPublicKeyKey) ?? '';
        _loaded = true;
        _loadError = null;
      });
      await _publishIntegration(data);
      await _readWidgetCommands();
      await _restoreCloudSession();
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError =
              'Chargement impossible. Vos données ne seront pas remplacées. Fermez toute autre fenêtre Poulpoints puis réessayez. Détail : $error',
        );
      }
    }
  }

  Future<bool> _save({bool forCloud = false}) async {
    if (!_loaded || _repository == null) return false;
    if (!forCloud) _localEditRevision++;
    final snapshot = _snapshot;
    setState(() => _saving++);
    try {
      await _repository!.save(snapshot);
      await _publishIntegration(snapshot);
      if (mounted) setState(() => _saveError = null);
      if (!forCloud) _scheduleCloudSync();
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = 'Modifications non sauvegardées : $error');
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving--);
    }
  }

  Future<void> _restorePrevious() async {
    if (!_canEdit || _saving > 0) return;
    try {
      final previous = await _repository!.previous();
      if (!mounted) return;
      if (previous == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune version précédente disponible.'),
          ),
        );
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurer la sauvegarde précédente ?'),
          content: Text(
            'Cette version contient ${previous.tasks.length} tâche(s). Elle remplacera les données affichées. L’état actuel sera conservé comme version précédente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurer'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      await _repository!.save(previous);
      await _publishIntegration(previous);
      if (mounted) {
        setState(() {
          _apply(previous);
          _saveError = null;
          _localEditRevision++;
        });
        _scheduleCloudSync();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restauration impossible : $error')),
        );
      }
    }
  }

  void _change(Task changed) {
    if (!_canEdit) return;
    setState(() {
      final i = _tasks.indexWhere((task) => task.id == changed.id);
      if (i >= 0) _tasks[i] = changed;
    });
    if (_selectedTask?.id == changed.id) _selectedTask = changed;
    _save();
  }

  void _delete(Task task) {
    if (!_canEdit) return;
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
      _deletions[task.id] = DateTime.now().toUtc().microsecondsSinceEpoch;
      if (_selectedTask?.id == task.id) _selectedTask = null;
    });
    _save();
  }

  Future<CloudBaseline?> _readCloudBaseline(
    SharedPreferences prefs,
    SupabaseCloud cloud,
  ) async {
    final legacy = CloudSync.loadBaseline(prefs, cloud);
    final data = await _repository!.readCloudCheckpoint();
    if (data == null) return legacy;
    final checkpoint = CloudBaseline.fromJson(data);
    if (checkpoint.identity != CloudSync.identity(cloud)) {
      throw const CloudException(
        'Ce stockage appartient à un autre compte cloud.',
      );
    }
    return checkpoint;
  }

  bool _restoringCloudSession = false;
  Future<void> _restoreCloudSession() async {
    if (_cloudUrl.isEmpty ||
        _cloudPublicKey.isEmpty ||
        _cloud != null ||
        _restoringCloudSession) {
      return;
    }
    _restoringCloudSession = true;
    SupabaseCloud? restored;
    try {
      final saved = await _sessionStore.read();
      if (saved == null || !mounted || _cloud != null) return;
      restored = SupabaseCloud(
        url: _cloudUrl,
        publicKey: _cloudPublicKey,
        sessionStore: _sessionStore,
      );
      restored.restoreSession(saved);
      await _readCloudBaseline(await SharedPreferences.getInstance(), restored);
      if (!mounted || _cloud != null) {
        restored.dispose();
        return;
      }
      setState(() {
        _cloud = restored;
        _cloudReadyForAuto = true;
        _cloudStatus = 'Session restaurée — synchronisation en attente';
      });
      _scheduleCloudSync(delay: const Duration(milliseconds: 400));
    } catch (_) {
      restored?.dispose();
      if (mounted && _cloud == null) {
        setState(
          () => _cloudStatus = _desktopResident
              ? 'Connexion en attente du coffre-fort Linux. Activez et déverrouillez KWallet ; Poulpoints réessaiera automatiquement.'
              : 'Coffre-fort indisponible. La connexion sera restaurée dès son déverrouillage.',
        );
      }
    } finally {
      _restoringCloudSession = false;
    }
  }

  Future<void> _connectCloud() async {
    if (!_loaded || _cloudSyncing) return;
    // The dialog owns and disposes its text controllers when its route
    // actually unmounts, not when showDialog returns at Navigator.pop.
    final details = await showDialog<CloudLoginDetails>(
      context: context,
      builder: (_) => CloudLoginDialog(
        initialUrl: _cloudUrl,
        initialPublicKey: _cloudPublicKey,
      ),
    );
    if (details == null || !mounted) return;
    SupabaseCloud? newCloud;
    try {
      newCloud = SupabaseCloud(
        url: details.url,
        publicKey: details.publicKey,
        sessionStore: _sessionStore,
      );
      await newCloud.signIn(details.email, details.password);
      final prefs = await SharedPreferences.getInstance();
      final existingBaseline = await _readCloudBaseline(prefs, newCloud);
      if (!await prefs.setString(
        CloudSync.identityKey,
        CloudSync.identity(newCloud),
      )) {
        throw const CloudException(
          'Impossible d’associer ce compte au stockage local.',
        );
      }
      var remembered = true;
      try {
        await newCloud.rememberSession();
      } catch (_) {
        remembered = false;
      }
      await prefs.setString(_cloudUrlKey, newCloud.url);
      await prefs.setString(_cloudPublicKeyKey, newCloud.publicKey);
      if (!mounted) {
        newCloud.dispose();
        return;
      }
      _cloudTimer?.cancel();
      _cloud?.dispose();
      setState(() {
        _cloud = newCloud;
        _cloudUrl = newCloud!.url;
        _cloudPublicKey = newCloud.publicKey;
        // A first sync is safe to attempt: the 3-way merge refuses divergent
        // copies with the same ID instead of overwriting them.
        _cloudReadyForAuto = true;
        _cloudFailureCount = 0;
        _cloudRetryAfter = null;
        _cloudSyncQueued = false;
        _cloudStatus = !remembered
            ? 'Coffre-fort indisponible : conservation de la connexion en attente, nouvelle tentative automatique.'
            : existingBaseline == null
            ? 'Connecté — première synchronisation automatique…'
            : 'Connecté — synchronisation automatique active';
      });
      // No manual action required after login. On failure, keep local data
      // intact and retry later; manual sync remains available in Settings.
      _scheduleCloudSync(delay: const Duration(milliseconds: 400));
    } catch (error) {
      newCloud?.dispose();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connexion refusée : $error')));
      }
    }
  }

  Future<void> _disconnectCloud() async {
    _cloudTimer?.cancel();
    final old = _cloud;
    try {
      await old?.forgetSession();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d’effacer la session du coffre-fort. Déverrouillez-le puis réessayez.',
            ),
          ),
        );
      }
      return;
    }
    old?.dispose();
    if (!mounted) return;
    setState(() {
      _cloud = null;
      _cloudStatus = 'Déconnecté — tâches locales conservées';
      _cloudReadyForAuto = false;
      _cloudSyncing = false;
      _cloudSyncQueued = false;
      _cloudRetryAfter = null;
      _cloudFailureCount = 0;
    });
  }

  Future<CloudDecision> _resolveCloudConflict(CloudConflict conflict) async {
    if (!mounted) return CloudDecision.conflict;
    String describe(Map<String, dynamic>? data) {
      if (data == null) return 'Supprimé ou absent';
      if (!data.containsKey('id')) return data.values.join(' · ');
      final t = Task.fromJson(data);
      return [
        t.title,
        'Projet : ${t.list}',
        'Terminée : ${t.done ? "oui" : "non"}',
        'Priorité : ${t.priority ? "importante" : "normale"}',
        'Échéance : ${t.dueDate == null ? "aucune" : formatDeadline(t.dueDate!, t.hasDueTime)}',
        'Lieu : ${t.location}',
        'Étiquettes : ${t.tags.join(", ")}',
        'Répétition : ${t.recurrenceRule?.label ?? recurrenceLabels[t.recurrence]}',
        'Rappels : ${t.reminders.join(", ")} minutes avant',
        'Rappel reporté : ${t.snoozedUntil ?? "aucun"}',
        'Occurrence initiale : ${t.occurrenceAnchor ?? "aucune"}',
        'Sous-tâches : ${t.subtasks.map((s) => "${s.done ? "✓" : "○"} ${s.title}").join(" ; ")}',
        'Notes : ${t.notes}',
      ].join('\n');
    }

    return await showDialog<CloudDecision>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Choisir la version à conserver'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cette donnée a changé sur plusieurs appareils. Le choix s’applique à cet élément entier. Annuler ne remplace aucune version.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sur cet appareil',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(describe(conflict.local)),
                    const Divider(),
                    const Text(
                      'Dans le cloud',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(describe(conflict.remote)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, CloudDecision.pull),
                child: const Text('Conserver le cloud'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, CloudDecision.push),
                child: const Text('Conserver cet appareil'),
              ),
            ],
          ),
        ) ??
        CloudDecision.conflict;
  }

  Future<void> _syncCloud({bool silent = false}) async {
    final cloud = _cloud;
    if (cloud == null ||
        !cloud.signedIn ||
        _cloudSyncing ||
        _syncing ||
        !_loaded ||
        _repository == null ||
        _saving > 0) {
      return;
    }
    _cloudTimer?.cancel();
    setState(() => _cloudSyncing = true);
    var succeeded = false;
    try {
      // The local Sembast snapshot is durable before any remote write.
      if (!await _save(forCloud: true)) {
        throw StateError('Sauvegarde locale impossible.');
      }
      final localVersion = _localEditRevision;
      final localCopy = TaskSnapshot(
        tasks: List<Task>.of(_tasks),
        projects: List<String>.of(_projects),
        deleted: Map<String, int>.of(_deletions),
      );
      final prefs = await SharedPreferences.getInstance();
      final previous = await _readCloudBaseline(prefs, cloud);
      final result = await CloudSync.synchronize(
        cloud: cloud,
        local: localCopy,
        baseline: previous,
        resolve: silent ? null : _resolveCloudConflict,
      );
      if (!mounted || _cloud != cloud) return;
      final changedWhileSending =
          _localEditRevision != localVersion || _saving > 0;
      final nextSnapshot = changedWhileSending
          ? rebaseLocalEdits(localCopy, _snapshot, result.snapshot)
          : result.snapshot;
      _cloudSyncQueued = _cloudSyncQueued || changedWhileSending;
      _cloudApplying = true;
      try {
        await _repository!.saveCloud(nextSnapshot, result.baseline.toJson());
        await _publishIntegration(nextSnapshot);
        if (!mounted || _cloud != cloud) return;
        setState(() {
          _apply(nextSnapshot);
          _saveError = null;
        });
      } finally {
        _cloudApplying = false;
      }
      _cloudFailureCount = 0;
      _cloudRetryAfter = null;
      _cloudReadyForAuto = true;
      succeeded = true;
      if (mounted) {
        setState(() {
          _cloudStatus = 'Synchronisé à ${TimeOfDay.now().format(context)}';
        });
      }
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud Poulapp synchronisé.')),
        );
      }
    } catch (error) {
      final isConflict =
          error is CloudException &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.message.contains('concurrentes') ||
              error.message.contains('Conflit cloud') ||
              error.message.contains('version distante modifiée'));
      if (isConflict) {
        // A human must resolve this safely; never poll on an unresolved
        // conflict or silently choose a winning copy.
        _cloudReadyForAuto = false;
        _cloudRetryAfter = null;
      } else if (_cloudSyncQueued) {
        _cloudFailureCount = 0;
        _cloudRetryAfter = null;
      } else {
        _cloudFailureCount++;
        _cloudRetryAfter = DateTime.now().add(
          cloudRetryDelay(_cloudFailureCount),
        );
      }
      if (mounted && _cloud == cloud) {
        setState(
          () => _cloudStatus = isConflict
              ? 'Intervention nécessaire : synchronisation automatique suspendue. '
                    'Sauvegardez vos tâches avant de le résoudre.'
              : (_cloudSyncQueued
                    ? 'Nouvelle modification : synchronisation en attente…'
                    : 'En attente de connexion : $error'),
        );
        if (!silent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Cloud : $error')));
        }
      }
    } finally {
      if (mounted && _cloud == cloud) {
        setState(() => _cloudSyncing = false);
        if (_cloudSyncQueued || !succeeded) {
          _cloudSyncQueued = false;
          _scheduleCloudSync();
        }
      }
    }
  }

  Future<void> _syncSettings() async {
    final url = TextEditingController(text: _syncUrl);
    final token = TextEditingController(text: _syncToken);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Synchronisation expérimentale'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Utilisez un serveur Poulpoints auto-hébergé accessible en HTTPS. Le jeton est enregistré sur cet appareil ; ne l’utilisez pas sur un ordinateur partagé.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'Adresse HTTPS du serveur',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: token,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Jeton secret'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      _syncUrl = url.text.trim().replaceAll(RegExp(r'/+$'), '');
      _syncToken = token.text.trim();
      if (_syncUrl.isNotEmpty &&
          (!_syncUrl.startsWith('https://') || _syncToken.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adresse HTTPS et jeton obligatoires.'),
            ),
          );
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncUrlKey, _syncUrl);
      await prefs.setString(_syncTokenKey, _syncToken);
      if (mounted) setState(() {});
    }
    url.dispose();
    token.dispose();
  }

  Future<void> _syncNow() async {
    if (_syncing || !_loaded) return;
    if (_syncUrl.isEmpty || _syncToken.isEmpty) {
      await _syncSettings();
      return;
    }
    setState(() => _syncing = true);
    try {
      // Save first so the outgoing snapshot includes all changes on this device.
      if (!await _save()) {
        throw StateError(
          'La sauvegarde locale doit réussir avant la synchronisation.',
        );
      }
      final response = await http
          .post(
            Uri.parse('$_syncUrl/sync'),
            headers: {
              'Authorization': 'Bearer $_syncToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'tasks': _tasks.map((t) => t.toJson()).toList(),
              'deleted': _deletions,
              'projects': _projects,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Serveur HTTP ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final received = TaskSnapshot.fromJson({'schemaVersion': 3, ...data});
      await _repository!.save(received);
      await _publishIntegration(received);
      if (!mounted) return;
      setState(() => _apply(received));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation terminée.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synchronisation impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _exportBackup() async {
    if (!_loaded) return;
    final payload = jsonEncode({
      'schemaVersion': 3,
      'tasks': _tasks.map((t) => t.toJson()).toList(),
      'projects': _projects,
      'deleted': _deletions,
    });
    await Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sauvegarde JSON copiée dans le presse-papiers.'),
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    if (!_canEdit) return;
    final pasted = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer une sauvegarde JSON'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: pasted,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Collez votre sauvegarde ici',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        final parsed = jsonDecode(pasted.text) as Map<String, dynamic>;
        final imported = TaskSnapshot.fromJson(parsed);
        await _repository!.save(imported);
        await _publishIntegration(imported);
        if (!mounted) return;
        setState(() {
          _apply(imported);
          _saveError = null;
          _localEditRevision++;
        });
        _scheduleCloudSync();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sauvegarde importée.')));
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Import refusé : $error')));
        }
      }
    }
    pasted.dispose();
  }

  Future<void> _openEditor([Task? existing]) async {
    if (!_canEdit) return;
    final lists = {
      ..._projects,
      if (_projects.isEmpty) 'Personnel',
      if (existing != null) existing.list,
    }.toList()..sort();
    final useFullScreen = MediaQuery.sizeOf(context).width < 600;
    final editor = TaskEditor(
      existing: existing,
      lists: lists,
      initialList: resolveInitialProject(
        lists,
        selectedProject: _projects.contains(_selection) ? _selection : null,
        preferredProject: _defaultProject,
      ),
      fullScreen: useFullScreen,
    );
    _editorOpen = true;
    final result = useFullScreen
        ? await Navigator.of(context).push<Task>(
            MaterialPageRoute<Task>(
              fullscreenDialog: true,
              builder: (_) => editor,
            ),
          )
        : await showDialog<Task>(context: context, builder: (_) => editor);
    if (!mounted) return;
    _editorOpen = false;
    if (result == null) return;
    if (existing == null) {
      setState(() => _tasks.add(result.copyWith()));
      _save();
    } else {
      _change(result.copyWith());
    }
  }

  bool _isToday(DateTime? date) {
    final now = DateTime.now();
    return date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  List<Task> get _visibleTasks {
    final filtered = _tasks.where((task) {
      if (_search.isNotEmpty &&
          ![
            task.title,
            ...task.tags,
          ].join(' ').toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      switch (_selection) {
        case 'Aujourd’hui':
          return _isToday(task.dueDate) && !task.done;
        case 'Importantes':
          return task.priority && !task.done;
        case 'Terminées':
          return task.done;
        case 'Toutes':
          return !task.done;
        default:
          return task.list == _selection && !task.done;
      }
    }).toList();
    filtered.sort((a, b) {
      final priorityCompare = (b.priority ? 1 : 0).compareTo(
        a.priority ? 1 : 0,
      );
      if (priorityCompare != 0) return priorityCompare;
      if (a.dueDate == null && b.dueDate != null) return 1;
      if (b.dueDate == null && a.dueDate != null) return -1;
      return a.dueDate?.compareTo(b.dueDate!) ?? 0;
    });
    return filtered;
  }

  Future<void> _deleteProject(String name) async {
    if (!_canEdit || _cloudSyncing) return;
    final targets = _projects.where((p) => p != name).toList();
    if (targets.isEmpty) {
      targets.add(name == 'Sans projet' ? 'Personnel' : 'Sans projet');
    }
    var target = targets.first;
    final count = _tasks.where((t) => t.list == name).length;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Supprimer « $name » ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count tâche(s), y compris les tâches terminées, seront conservées dans la liste choisie.',
              ),
              DropdownButton<String>(
                value: target,
                isExpanded: true,
                items: targets
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => update(() => target = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Déplacer et supprimer le projet'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted || !_canEdit) return;
    setState(() {
      for (var i = 0; i < _tasks.length; i++) {
        if (_tasks[i].list == name) {
          _tasks[i] = _tasks[i].copyWith(list: target);
        }
      }
      _projects.remove(name);
      if (!_projects.contains(target)) _projects.add(target);
      if (_selection == name) _selection = target;
      if (_defaultProject == name) _defaultProject = target;
    });
    final saved = await _save();
    if (saved && _defaultProject == target) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultProjectKey, target);
    }
  }

  Future<void> _moveOccurrence(Task task) async {
    final initial = task.dueDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    if (!_tasks.any((t) => t.id == task.id && t.updatedAt == task.updatedAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cette tâche a changé. Rouvrez-la avant de déplacer son occurrence.',
          ),
        ),
      );
      return;
    }
    _change(
      moveOccurrence(
        task,
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ),
    );
  }

  Future<void> _createProject() async {
    if (!_canEdit) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau projet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom du projet'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null ||
        name.isEmpty ||
        _projects.contains(name) ||
        ['Toutes', 'Aujourd’hui', 'Importantes', 'Terminées'].contains(name)) {
      return;
    }
    setState(() {
      _projects.add(name);
      _selection = name;
      _showStats = false;
      _showSettings = false;
    });
    _save();
  }

  Future<void> _showTaskDetails(Task task) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (ctx, update) => FractionallySizedBox(
        heightFactor: 0.82,
        child: _details(
          _tasks.firstWhere((t) => t.id == task.id, orElse: () => task),
          refresh: () {
            if (ctx.mounted) update(() {});
          },
        ),
      ),
    ),
  );

  Widget _details(Task task, {VoidCallback? refresh}) {
    final colors = Theme.of(context).colorScheme;
    final completed = task.subtasks.where((s) => s.done).length;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () async {
                await _openEditor(task);
                if (mounted) refresh?.call();
              },
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () {
                if (refresh != null) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _selectedTask = null);
                }
              },
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text(task.list)),
            Chip(
              label: Text(
                task.priority ? 'Priorité : importante' : 'Priorité : normale',
              ),
            ),
            Chip(
              label: Text(
                'Répétition : ${task.recurrence == 'custom' ? task.recurrenceRule?.label ?? 'Personnalisée' : recurrenceLabels[task.recurrence]}',
              ),
            ),
            for (final minutes in task.reminders)
              Chip(
                label: Text(
                  minutes == 0
                      ? 'Rappel à l’échéance'
                      : 'Rappel : ${reminderLabel(minutes)}',
                ),
              ),
            for (final tag in task.tags)
              ActionChip(
                label: Text('#$tag'),
                onPressed: () => setState(() => _search = tag),
              ),
            if (task.snoozedUntil != null)
              Chip(
                label: Text(
                  'Rappel reporté : ${formatDeadline(task.snoozedUntil!, true)}',
                ),
              ),
            if (task.location.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                label: Text(task.location),
              ),
            if (task.dueDate != null)
              Chip(label: Text(formatDeadline(task.dueDate!, task.hasDueTime))),
            if (overdueLabel(task, DateTime.now()) case final label?)
              Chip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                label: Text('En retard : $label'),
                backgroundColor: colors.errorContainer,
                labelStyle: TextStyle(color: colors.onErrorContainer),
              ),
          ],
        ),
        if (!task.done)
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.snooze),
                label: const Text('Me rappeler dans 10 minutes'),
                onPressed: () {
                  _change(
                    task.copyWith(
                      snoozedUntil: DateTime.now().add(
                        const Duration(minutes: 10),
                      ),
                    ),
                  );
                  refresh?.call();
                },
              ),
              if (task.recurrence != 'none') ...[
                TextButton(
                  onPressed: () {
                    _change(completeTask(task, true));
                    refresh?.call();
                  },
                  child: const Text('Ignorer cette occurrence'),
                ),
                TextButton(
                  onPressed: () async {
                    await _moveOccurrence(task);
                    refresh?.call();
                  },
                  child: const Text('Déplacer cette occurrence'),
                ),
              ],
            ],
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('Sous-tâches', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '$completed/${task.subtasks.length}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            IconButton(
              tooltip: 'Ajouter une sous-tâche',
              onPressed: () => _addSubtask(task, refresh),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        ...task.subtasks.map(
          (sub) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              sub.title,
              style: TextStyle(
                decoration: sub.done ? TextDecoration.lineThrough : null,
              ),
            ),
            value: sub.done,
            onChanged: (value) {
              final changed = task.copyWith(
                subtasks: task.subtasks
                    .map(
                      (s) => s.id == sub.id
                          ? Subtask(
                              id: s.id,
                              title: s.title,
                              done: value ?? false,
                            )
                          : s,
                    )
                    .toList(),
              );
              _change(changed);
              refresh?.call();
            },
            secondary: IconButton(
              tooltip: 'Supprimer la sous-tâche',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _change(
                  task.copyWith(
                    subtasks: task.subtasks
                        .where((s) => s.id != sub.id)
                        .toList(),
                  ),
                );
                refresh?.call();
              },
            ),
          ),
        ),
        if (task.subtasks.isEmpty)
          Text(
            'Aucune sous-tâche pour le moment.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        const SizedBox(height: 18),
        Text('Notes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('notes_${task.id}'),
          initialValue: task.notes,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Ajouter des notes…'),
          onChanged: (value) => _change(
            _tasks.firstWhere((t) => t.id == task.id).copyWith(notes: value),
          ),
        ),
        Attachments(
          key: ValueKey('${task.id}-${task.attachmentCycle}'),
          taskId: task.id,
          cloud: _cloud,
          synchronize: () => _syncCloud(),
          done: task.done,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await _openEditor(task);
            if (mounted) refresh?.call();
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier la tâche'),
        ),
      ],
    );
  }

  Future<void> _addSubtask(Task task, VoidCallback? refresh) async {
    if (!_canEdit) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une sous-tâche'),
        content: TextField(
          autofocus: true,
          controller: controller,
          decoration: const InputDecoration(labelText: 'Sous-tâche'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    final latest = _tasks.firstWhere((t) => t.id == task.id);
    _change(
      latest.copyWith(
        subtasks: [
          ...latest.subtasks,
          Subtask(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
          ),
        ],
      ),
    );
    refresh?.call();
  }

  Widget _statistics() {
    final total = _tasks.length;
    final done = _tasks.where((t) => t.done).length;
    final progress = total == 0 ? 0.0 : done / total;
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$done tâches terminées sur $total',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).round()} % de progression'),
              ],
            ),
          ),
        ),
        ..._projects.map((p) {
          final projectTasks = _tasks.where((t) => t.list == p).toList();
          return Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(p),
              subtitle: Text(
                '${projectTasks.where((t) => t.done).length}/${projectTasks.length} terminées',
              ),
            ),
          );
        }),
      ],
    );
  }

  // Every navigation item shares the same icon width, left inset and
  // selection appearance (projects used to have different indentation).
  Widget _navigationItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: const VisualDensity(vertical: 1),
        leading: SizedBox(width: 24, child: Icon(icon, size: 23)),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        selected: selected,
        selectedTileColor: colors.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }

  Widget _settingsGroup(String heading, List<Widget> items) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Text(
                heading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...items,
          ],
        ),
      ),
    );
  }

  Future<void> _changeDefaultProject(String project) async {
    if (!_projects.contains(project)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(_defaultProjectKey, project);
      if (mounted && saved) setState(() => _defaultProject = project);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Projet par défaut non enregistré : $error')),
        );
      }
    }
  }

  Future<void> _chooseDefaultProject() async {
    if (_projects.isEmpty) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choisir le projet par défaut'),
        children: [
          for (final project in _projects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, project),
              child: Row(
                children: [
                  Icon(
                    resolveInitialProject(
                              _projects,
                              preferredProject: _defaultProject,
                            ) ==
                            project
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(project)),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) await _changeDefaultProject(chosen);
  }

  Widget _settingsContent() {
    final connected = _cloud?.signedIn == true;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      children: [
        _settingsGroup('À propos', [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Poulpoints'),
            subtitle: const Text(
              'Version $poulpointsVersion (build $poulpointsBuild)',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Poulapp · logiciel libre'),
            subtitle: Text('Licence MIT'),
          ),
        ]),
        _settingsGroup('Poulapp Cloud', [
          ListTile(
            leading: Icon(
              connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            ),
            title: Text(connected ? 'Compte connecté' : 'Compte non connecté'),
            subtitle: Text(_cloudStatus),
          ),
          if (!connected)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Se connecter'),
              subtitle: const Text(
                'Cloud Poulapp privé ou instance personnelle',
              ),
              onTap: _connectCloud,
            ),
          if (connected) ...[
            const ListTile(
              leading: Icon(Icons.autorenew),
              title: Text('Synchronisation automatique'),
              subtitle: Text(
                'Après chaque modification, à la reprise de '
                'l’application et environ chaque minute quand elle est ouverte.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(
                _cloudSyncing
                    ? 'Synchronisation en cours…'
                    : 'Synchroniser maintenant',
              ),
              subtitle: const Text('Action manuelle facultative'),
              onTap: _cloudSyncing ? null : () => _syncCloud(),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Déconnecter Poulapp Cloud'),
              onTap: _disconnectCloud,
            ),
          ],
        ]),
        _settingsGroup('Rappels et widgets', [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Activer les notifications'),
            subtitle: Text(_integrationStatus),
            onTap: _configureReminders,
          ),
          ListTile(
            title: const Text('Autoriser les horaires précis sur Android'),
            subtitle: const Text(
              'Sans cette autorisation, Android peut retarder les rappels pour économiser la batterie.',
            ),
            onTap: () => _configureReminders(exact: true),
          ),
          const ListTile(
            title: Text('Widgets Android et bureau KDE'),
            subtitle: Text(
              'Ajoutez Poulpoints dans les widgets du téléphone ou du bureau. Sur Android, cocher valide sans ouvrir Poulpoints. Sur KDE, l’application enregistre la validation. Les données cloud sont actualisées lorsque l’application est ouverte.',
            ),
          ),
        ]),
        _settingsGroup('Sauvegardes', [
          ListTile(
            leading: const Icon(Icons.content_copy_outlined),
            title: const Text('Copier une sauvegarde JSON'),
            onTap: _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restaurer la version précédente'),
            onTap: _restorePrevious,
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Importer une sauvegarde JSON'),
            onTap: _importBackup,
          ),
        ]),
        _settingsGroup('Ancien serveur expérimental', [
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Synchroniser avec l’ancien serveur'),
            enabled: !connected && !_syncing,
            onTap: connected || _syncing ? null : _syncNow,
          ),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('Configurer l’ancien serveur'),
            enabled: !connected,
            onTap: connected ? null : _syncSettings,
          ),
        ]),
        _settingsGroup('Organisation', [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Projet par défaut'),
            subtitle: Text(
              'Actuel : ${resolveInitialProject(_projects, preferredProject: _defaultProject)}. '
              'Utilisé pour les tâches créées depuis les vues générales.',
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: _projects.isNotEmpty,
            onTap: _projects.isEmpty ? null : _chooseDefaultProject,
          ),
        ]),
        _settingsGroup('Apparence', [
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Premier jour de la semaine'),
            trailing: DropdownButton<bool>(
              value: widget.monday,
              items: const [
                DropdownMenuItem(value: true, child: Text('Lundi')),
                DropdownMenuItem(value: false, child: Text('Dimanche')),
              ],
              onChanged: (value) {
                if (value != null) widget.onFirstDayChanged?.call(value);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Thème'),
            trailing: DropdownButton<ThemeMode>(
              value: widget.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Système'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
              ],
              onChanged: (value) {
                if (value != null) widget.onThemeModeChanged(value);
              },
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'La synchronisation est active uniquement lorsque '
            'Poulpoints est ouvert et que le compte est connecté. '
            'Les données restent disponibles hors ligne.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 850;
    final colors = Theme.of(context).colorScheme;
    final listNames = [..._projects]..sort();
    final navItems = <String>[
      'Toutes',
      'Aujourd’hui',
      'Importantes',
      'Terminées',
      ...listNames,
    ];
    final countPending = _tasks.where((t) => !t.done).length;
    final navigation = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 20),
          child: Row(
            children: [
              Image.asset('assets/poulpoints_logo.png', width: 44, height: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Poulpoints',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une tâche'),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: [
              ...navItems.map((name) {
                final icon = switch (name) {
                  'Toutes' => Icons.inbox_outlined,
                  'Aujourd’hui' => Icons.today_outlined,
                  'Importantes' => Icons.star_outline,
                  'Terminées' => Icons.check_circle_outline,
                  _ => Icons.folder_outlined,
                };
                return _navigationItem(
                  icon: icon,
                  label: name,
                  trailing: listNames.contains(name)
                      ? IconButton(
                          tooltip: 'Supprimer ce projet',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteProject(name),
                        )
                      : null,
                  selected: !_showStats && !_showSettings && name == _selection,
                  onTap: () {
                    setState(() {
                      _selection = name;
                      _showStats = false;
                      _showSettings = false;
                      _selectedTask = null;
                    });
                    if (!isWide) Navigator.maybePop(context);
                  },
                );
              }),
              _navigationItem(
                icon: Icons.add_circle_outline,
                label: 'Nouveau projet',
                onTap: () {
                  if (!isWide) Navigator.maybePop(context);
                  _createProject();
                },
              ),
              _navigationItem(
                icon: Icons.bar_chart_rounded,
                label: 'Statistiques',
                selected: _showStats && !_showSettings,
                onTap: () {
                  setState(() {
                    _showStats = true;
                    _showSettings = false;
                    _selectedTask = null;
                  });
                  if (!isWide) Navigator.maybePop(context);
                },
              ),
            ],
          ),
        ),
        const Divider(indent: 18, endIndent: 18, height: 12),
        _navigationItem(
          icon: Icons.settings_outlined,
          label: 'Paramètres',
          selected: _showSettings,
          onTap: () {
            setState(() {
              _showSettings = true;
              _showStats = false;
              _selectedTask = null;
            });
            if (!isWide) Navigator.maybePop(context);
          },
        ),
        const SizedBox(height: 12),
      ],
    );

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isWide ? 32 : 18,
            24,
            isWide ? 32 : 18,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _showSettings
                    ? 'Paramètres'
                    : (_showStats ? 'Statistiques' : _selection),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _showSettings
                    ? 'Cloud, sauvegardes et préférences'
                    : (_showStats
                          ? 'Votre progression en un coup d’œil'
                          : '$countPending tâche${countPending > 1 ? 's' : ''} à accomplir'),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              if (!_showStats && !_showSettings)
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher une tâche…',
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              const SizedBox(height: 14),
              Expanded(
                child: _showSettings
                    ? _settingsContent()
                    : _showStats
                    ? _statistics()
                    : !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : _visibleTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.task_alt,
                              size: 72,
                              color: colors.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Rien à afficher ici',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ajoute une tâche avec le bouton +',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _visibleTasks.length,
                        itemBuilder: (context, index) {
                          final task = _visibleTasks[index];
                          final due = task.dueDate;
                          final overdue = overdueLabel(task, DateTime.now());
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            clipBehavior: Clip.antiAlias,
                            child: Row(
                              children: [
                                if (overdue != null)
                                  Container(
                                    width: 4,
                                    height: 72,
                                    color: colors.error,
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: task.done,
                                          onChanged: (v) => _change(
                                            completeTask(task, v ?? false),
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: () => isWide
                                                ? setState(
                                                    () => _selectedTask = task,
                                                  )
                                                : _showTaskDetails(task),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                    horizontal: 4,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          task.title,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            decoration:
                                                                task.done
                                                                ? TextDecoration
                                                                      .lineThrough
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                      if (overdue != null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 6,
                                                              ),
                                                          child: Tooltip(
                                                            message:
                                                                'Échéance dépassée',
                                                            child: Text(
                                                              overdue,
                                                              key: ValueKey(
                                                                'overdue-${task.id}',
                                                              ),
                                                              style: TextStyle(
                                                                color: colors
                                                                    .error,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${task.list}${due == null ? '' : '  •  ${formatDeadline(due, task.hasDueTime)}'}${task.subtasks.isEmpty ? '' : '  •  ${task.subtasks.where((s) => s.done).length}/${task.subtasks.length} sous-tâches'}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: overdue != null
                                                          ? colors.error
                                                          : colors
                                                                .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Marquer comme importante',
                                          icon: Icon(
                                            task.priority
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: task.priority
                                                ? colors.primary
                                                : null,
                                          ),
                                          onPressed: () => _change(
                                            task.copyWith(
                                              priority: !task.priority,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Options',
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _openEditor(task);
                                            }
                                            if (value == 'delete') {
                                              _delete(task);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Modifier'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Supprimer'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Poulpoints')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _loadError == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    return Scaffold(
      bottomNavigationBar: _saveError == null && _saving == 0 && !_syncing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _saveError ??
                          (_syncing
                              ? 'Synchronisation en cours…'
                              : 'Enregistrement en cours…'),
                    ),
                    if (_saveError != null)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _save,
                            child: const Text('Réessayer la sauvegarde'),
                          ),
                          TextButton(
                            onPressed: _exportBackup,
                            child: const Text('Copier une sauvegarde'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      appBar: isWide
          ? null
          : AppBar(
              title: Row(
                children: [
                  Image.asset(
                    'assets/poulpoints_logo.png',
                    width: 34,
                    height: 34,
                  ),
                  const SizedBox(width: 8),
                  const Text('Poulpoints'),
                ],
              ),
            ),
      drawer: isWide ? null : Drawer(child: SafeArea(child: navigation)),
      body: AbsorbPointer(
        absorbing: _syncing,
        child: Row(
          children: [
            if (isWide)
              SizedBox(width: 280, child: SafeArea(child: navigation)),
            if (isWide) const VerticalDivider(width: 1),
            Expanded(child: SafeArea(child: content)),
            if (isWide &&
                _selectedTask != null &&
                !_showStats &&
                !_showSettings) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 360,
                child: SafeArea(child: _details(_selectedTask!)),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: _showSettings
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle tâche'),
            ),
    );
  }
}
