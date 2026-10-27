import 'dart:convert';
import 'prepare_vault_stub.dart'
    if (dart.library.io) 'prepare_vault_native.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> session);
  Future<void> delete();
}

// All native secret operations use the OS-backed vault, never preferences.
// No persistent browser session is claimed until its threat model is validated.
class SecureSessionStore implements SessionStore {
  static const _key = 'poulpoints_cloud_session_v1';
  static const _vault = FlutterSecureStorage();
  Future<void> _queue = Future.value();
  Future<T> _run<T>(Future<T> Function() action) {
    final job = _queue.then((_) => action());
    _queue = job.then((_) {}, onError: (Object _, StackTrace __) {});
    return job;
  }

  @override
  Future<Map<String, dynamic>?> read() => _run(() async {
    if (kIsWeb) return null;
    await prepareVault();
    final raw = await _vault.read(key: _key);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  });
  @override
  Future<void> write(Map<String, dynamic> session) => _run(() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Session navigateur conservée uniquement pendant cette ouverture.',
      );
    }
    await prepareVault();
    await _vault.write(key: _key, value: jsonEncode(session));
  });
  @override
  Future<void> delete() => _run(() async {
    if (!kIsWeb) {
      await prepareVault();
      await _vault.delete(key: _key);
    }
  });
}
