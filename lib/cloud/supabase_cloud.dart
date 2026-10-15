import 'dart:convert';

import 'session_store.dart';

import 'package:http/http.dart' as http;

/// Supabase Auth + PostgREST client. No service_role key, PostgreSQL password,
/// user password is saved to preferences. Refresh tokens use an injected OS vault.
class SupabaseCloud {
  SupabaseCloud({
    required String url,
    required this.publicKey,
    http.Client? httpClient,
    this.sessionStore,
  }) : url = url.replaceFirst(RegExp(r'/+$'), ''),
       _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null {
    final uri = Uri.tryParse(this.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        publicKey.trim().isEmpty ||
        _isSecretKey(publicKey)) {
      throw const FormatException(
        'Adresse Supabase HTTPS et clé publique requises.',
      );
    }
  }

  static bool _isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is Map &&
          ['service_role', 'supabase_admin'].contains(claims['role'])) {
        return true;
      }
    } catch (_) {
      // A malformed JWT will be rejected by Supabase itself.
    }
    return false;
  }

  final SessionStore? sessionStore;
  bool _remember = false;
  bool _sessionDirty = false;
  int _generation = 0;
  Future<void>? _refreshing;
  final String url;
  final String publicKey;
  final http.Client _client;
  final bool _ownsClient;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  String? userId;
  bool get signedIn => userId != null && _refreshToken != null;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$url$path').replace(queryParameters: query);

  Map<String, String> _headers({bool authenticated = true}) => {
    'apikey': publicKey,
    'Content-Type': 'application/json',
    if (authenticated && _accessToken != null)
      'Authorization': 'Bearer $_accessToken',
  };

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Don't echo server bodies: they may contain identifiers or sensitive data.
      throw CloudException(
        'Réponse du serveur HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    return response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<void> signIn(String email, String password) async {
    final response = await _client
        .post(
          _uri('/auth/v1/token', {'grant_type': 'password'}),
          headers: _headers(authenticated: false),
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response) as Map<String, dynamic>;
    _acceptTokens(decoded);
    try {
      await checkAccess();
    } catch (_) {
      signOut();
      rethrow;
    }
  }

  void _acceptTokens(Map<String, dynamic> data) {
    _sessionDirty = true;
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    userId = (data['user'] as Map<String, dynamic>)['id'] as String;
    _expiresAt = DateTime.now().toUtc().add(
      Duration(seconds: ((data['expires_in'] as num?)?.toInt() ?? 3600) - 60),
    );
  }

  Future<void> rememberSession() async {
    if (!signedIn || sessionStore == null) return;
    _remember = true;
    try {
      await _persist();
    } catch (_) {
      _remember = false;
      rethrow;
    }
  }

  Future<void> _persist() async {
    if (!_remember || !signedIn) return;
    await sessionStore?.write({
      'url': url,
      'publicKey': publicKey,
      'userId': userId,
      'refreshToken': _refreshToken,
    });
    _sessionDirty = false;
  }

  void restoreSession(Map<String, dynamic> session) {
    if (session['url'] != url ||
        session['publicKey'] != publicKey ||
        session['userId'] is! String ||
        session['refreshToken'] is! String ||
        (session['refreshToken'] as String).isEmpty) {
      throw const FormatException('Session enregistrée incompatible');
    }
    userId = session['userId'] as String;
    _refreshToken = session['refreshToken'] as String;
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    _remember = true;
  }

  Future<void> forgetSession() async {
    // Invalidate any HTTP response before deleting the vault entry.
    _generation++;
    _remember = false;
    await sessionStore?.delete();
    signOut();
  }

  Future<void> _ensureToken() async {
    if (!signedIn) {
      throw const CloudException(
        'Connecte-toi à ton compte Poulapp.',
        statusCode: 401,
      );
    }
    if (_accessToken != null && DateTime.now().toUtc().isBefore(_expiresAt!)) {
      if (_sessionDirty) await _persist();
      return;
    }
    if (_refreshing != null) return _refreshing!;
    final job = _refreshTokenNow();
    _refreshing = job;
    try {
      await job;
    } finally {
      if (identical(_refreshing, job)) _refreshing = null;
    }
  }

  Future<void> _refreshTokenNow() async {
    final generation = _generation;
    final response = await _client
        .post(
          _uri('/auth/v1/token', {'grant_type': 'refresh_token'}),
          headers: _headers(authenticated: false),
          body: jsonEncode({'refresh_token': _refreshToken}),
        )
        .timeout(const Duration(seconds: 20));
    if (generation != _generation) {
      throw const CloudException('Session fermée.', statusCode: 401);
    }
    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      await forgetSession();
      throw const CloudException(
        'Session expirée : reconnectez-vous.',
        statusCode: 401,
      );
    }
    final decoded = _decode(response) as Map<String, dynamic>;
    if ((decoded['user'] as Map)['id'] != userId) {
      await forgetSession();
      throw const CloudException(
        'Identité de session inattendue.',
        statusCode: 401,
      );
    }
    _acceptTokens(decoded);
    // Persist each rotated refresh token before any further server request.
    await _persist();
  }

  Future<void> checkAccess() async {
    await _ensureToken();
    final response = await _client
        .get(
          _uri('/rest/v1/poulapp_access', {
            'select': 'app_id',
            'app_id': 'eq.poulpoints',
            'user_id': 'eq.$userId',
          }),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final entries = _decode(response) as List<dynamic>;
    if (entries.length != 1) {
      throw const CloudException(
        'Compte non autorisé sur Poulpoints Cloud. Contacte l’administrateur.',
        statusCode: 403,
      );
    }
  }

  Future<List<Map<String, dynamic>>> readRows(String table) =>
      _readRows(table, '*');
  Future<List<Map<String, dynamic>>> readVersions(String table) => _readRows(
    table,
    table == 'poulpoints_task_records'
        ? 'task_id,revision,deleted'
        : 'project_name,revision,deleted',
  );
  Future<List<Map<String, dynamic>>> _readRows(
    String table,
    String selection,
  ) async {
    await _ensureToken();
    final results = <Map<String, dynamic>>[];
    final orderBy = table == 'poulpoints_task_records'
        ? 'task_id.asc'
        : 'project_name.asc';
    const pageSize = 100;
    for (var offset = 0; ; offset += pageSize) {
      final response = await _client
          .get(
            _uri('/rest/v1/$table', {
              'select': selection,
              'user_id': 'eq.$userId',
              'limit': '$pageSize',
              'offset': '$offset',
              'order': orderBy,
            }),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 20));
      final page = (_decode(response) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      results.addAll(page);
      if (page.length < pageSize) break;
      if (offset > 100000) {
        throw const CloudException('Trop d’enregistrements.');
      }
    }
    return results;
  }

  /// Conditional update: a change based on stale revision cannot overwrite
  /// another device's recent edit. Unconditional UPSERT is intentionally banned.
  Future<void> writeRecord({
    required String table,
    required String idColumn,
    required String id,
    required Map<String, dynamic> values,
    int? expectedRevision,
  }) async {
    await _ensureToken();
    final headers = {..._headers(), 'Prefer': 'return=representation'};
    final response = expectedRevision == null
        ? await _client
              .post(
                _uri('/rest/v1/$table'),
                headers: headers,
                body: jsonEncode({'user_id': userId, idColumn: id, ...values}),
              )
              .timeout(const Duration(seconds: 20))
        : await _client
              .patch(
                _uri('/rest/v1/$table', {
                  'user_id': 'eq.$userId',
                  idColumn: 'eq.$id',
                  'revision': 'eq.$expectedRevision',
                }),
                headers: headers,
                body: jsonEncode(values),
              )
              .timeout(const Duration(seconds: 20));
    if (response.statusCode == 409 || response.statusCode == 412) {
      throw const CloudException(
        'Conflit cloud : une autre modification existe.',
      );
    }
    final rows = _decode(response) as List<dynamic>;
    if (rows.length != 1) {
      throw const CloudException('Conflit cloud : version distante modifiée.');
    }
  }

  void signOut() {
    _generation++;
    _remember = false;
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    userId = null;
  }

  void dispose() {
    signOut();
    if (_ownsClient) _client.close();
  }
}

class CloudException implements Exception {
  const CloudException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
