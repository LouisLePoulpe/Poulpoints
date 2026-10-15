import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class PlatformBridge {
  bool get usesSharedRuntime => Platform.isAndroid;
  static const channel = MethodChannel('org.poulapp.poulpoints/integration');
  Directory get folder => Directory(
    '${Platform.environment['XDG_DATA_HOME'] ?? '${Platform.environment['HOME']}/.local/share'}/poulpoints-desktop',
  );
  Future<void> publish(Map<String, dynamic> data) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod('publish', jsonEncode(data));
    } else if (Platform.isLinux) {
      await folder.create(recursive: true);
      await Process.run('chmod', ['700', folder.path]);
      final file = File('${folder.path}/snapshot.tmp');
      await file.writeAsString(jsonEncode(data), flush: true);
      await file.rename('${folder.path}/snapshot.json');
    }
  }

  Future<List<Map<String, dynamic>>> commands() async {
    if (Platform.isAndroid) {
      return (jsonDecode(await channel.invokeMethod<String>('commands') ?? '[]')
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (!Platform.isLinux) return [];
    final queue = Directory('${folder.path}/commands');
    if (!await queue.exists()) return [];
    final result = <Map<String, dynamic>>[];
    await for (final file in queue.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map,
        );
        final token = file.uri.pathSegments.last.replaceFirst('.json', '');
        result.add({...data, 'token': token});
      } on FormatException {
        /* Incomplete/invalid commands are never applied. */
      }
    }
    return result;
  }

  void setCommandHandler(
    Future<void> Function() action, {
    Future<void> Function()? sync,
  }) {
    if (Platform.isAndroid) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'processWidgetCommands') await action();
        if (call.method == 'syncCloud') await sync?.call();
      });
    }
  }

  Future<void> scheduleSync() async {
    if (Platform.isAndroid) await channel.invokeMethod('scheduleSync');
  }

  Future<void> ready() async {
    if (Platform.isAndroid) await channel.invokeMethod('ready');
  }

  Future<void> reportWidgetError(String message) async {
    if (Platform.isAndroid) await channel.invokeMethod('widgetError', message);
  }

  Future<void> ack(String token) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod('ack', token);
    } else if (Platform.isLinux && RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(token)) {
      final file = File('${folder.path}/commands/$token.json');
      if (await file.exists()) await file.delete();
    }
  }

  Future<String> permissions({bool request = false, bool exact = false}) async {
    if (Platform.isAndroid) {
      return await channel.invokeMethod<String>('permissions', {
            'request': request,
            'exact': exact,
          }) ??
          'Indisponible';
    }
    if (Platform.isLinux) {
      return 'KDE Plasma : installez le compagnon Bureau fourni. Les rappels fonctionnent pendant votre session, même après fermeture de Poulpoints.';
    }
    return 'Rappels natifs non disponibles sur cette plateforme.';
  }
}
