import 'dart:io';

// KDE's Secret Service is activatable under its KDE name on some distributions,
// even when org.freedesktop.secrets has no activation file. Do not change the
// user's wallet settings or store a plaintext fallback when it is disabled.
Future<void> prepareVault() async {
  if (!Platform.isLinux ||
      !(Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
          .toUpperCase()
          .split(':')
          .contains('KDE')) {
    return;
  }
  try {
    final check = await Process.run('gdbus', [
      'call',
      '--session',
      '--dest',
      'org.freedesktop.DBus',
      '--object-path',
      '/org/freedesktop/DBus',
      '--method',
      'org.freedesktop.DBus.NameHasOwner',
      'org.freedesktop.secrets',
    ]).timeout(const Duration(seconds: 5));
    if (check.exitCode == 0 && check.stdout.toString().contains('true')) return;
    await Process.run('gdbus', [
      'call',
      '--session',
      '--dest',
      'org.freedesktop.DBus',
      '--object-path',
      '/org/freedesktop/DBus',
      '--method',
      'org.freedesktop.DBus.StartServiceByName',
      'org.kde.secretservicecompat',
      '0',
    ]).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Let secure storage report the real failure; never erase the saved session.
  }
}
