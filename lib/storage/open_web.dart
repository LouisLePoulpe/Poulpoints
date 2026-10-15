import 'package:sembast_web/sembast_web.dart';

import 'database_handle.dart';

Future<DatabaseHandle> openStorage() async =>
    DatabaseHandle(await databaseFactoryWeb.openDatabase('poulpoints-v4'));
