import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';

class DatabaseConnection {
  static Connection? _connection;

  static Future<Connection> get connection async {
    if (_connection == null) {
      // Load dotenv before accessing env
      final env = DotEnv(includePlatformEnvironment: true)..load();
      
      // Get values using Map accessor
      final host = env.containsKey('DATABASE_HOST') 
          ? env['DATABASE_HOST']! 
          : 'localhost';
      final port = env.containsKey('DATABASE_PORT')
          ? int.parse(env['DATABASE_PORT']!)
          : 5432;
      final database = env.containsKey('DATABASE_NAME')
          ? env['DATABASE_NAME']!
          : 'finance_sync';
      final username = env.containsKey('DATABASE_USER')
          ? env['DATABASE_USER']!
          : 'postgres';
      final password = env.containsKey('DATABASE_PASSWORD')
          ? env['DATABASE_PASSWORD']!
          : '';
      
      _connection = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: database,
        ),
        username: username,
        password: password,
      );
    }
    return _connection!;
  }

  static Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
    }
  }
}