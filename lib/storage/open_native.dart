import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

import 'database_handle.dart';

Future<DatabaseHandle> openStorage() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  // Sembast IO is single-process. Hold an OS lock for the entire session;
  // the operating system releases it even after a crash.
  final lock = await File(
    p.join(directory.path, 'poulpoints-v4.lock'),
  ).open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.exclusive);
    final db = await databaseFactoryIo.openDatabase(
      p.join(directory.path, 'poulpoints-v4.db'),
    );
    return DatabaseHandle(
      db,
      release: () async {
        await lock.close();
      },
    );
  } catch (_) {
    await lock.close();
    rethrow;
  }
}
