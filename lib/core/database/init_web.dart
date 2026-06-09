import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void initDatabaseFactory() {
  sqflite.databaseFactory = createDatabaseFactoryFfiWeb(noWebWorker: true);
}
