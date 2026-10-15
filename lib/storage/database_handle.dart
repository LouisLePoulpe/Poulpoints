import 'package:sembast/sembast.dart';

class DatabaseHandle {
  DatabaseHandle(this.db, {this.release});
  final Database db;
  final Future<void> Function()? release;
  Future<void> close() async {
    try {
      await db.close();
    } finally {
      await release?.call();
    }
  }
}
