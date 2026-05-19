import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

class DatabaseConnection {
  static PostgreSQLConnection? _connection;

  static Future<PostgreSQLConnection> get connection async {
    if (_connection == null || _connection!.isClosed) {
      _connection = PostgreSQLConnection(
        dotenv.env['DATABASE_HOST'] ?? 'localhost',
        int.parse(dotenv.env['DATABASE_PORT'] ?? '5432'),
        dotenv.env['DATABASE_NAME'] ?? 'finance_sync',
        username: dotenv.env['DATABASE_USER'] ?? 'postgres',
        password: dotenv.env['DATABASE_PASSWORD'] ?? '',
      );
      await _connection!.open();
    }
    return _connection!;
  }

  static Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
    }
  }
}