import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor connectToDatabase() {
  return WebDatabase('finance.db');
}