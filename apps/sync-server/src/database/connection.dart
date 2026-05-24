import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

class DatabaseConnection {
  static Connection? _connection;

  static Future<Connection> get connection async {
    if (_connection == null) {
      // Load dotenv before accessing env
      dotenv.load();
      
      // Get values using Map accessor
      final host = dotenv.env.containsKey('DATABASE_HOST') 
          ? dotenv.env['DATABASE_HOST']! 
          : 'localhost';
      final port = dotenv.env.containsKey('DATABASE_PORT')
          ? int.parse(dotenv.env['DATABASE_PORT']!)
          : 5432;
      final database = dotenv.env.containsKey('DATABASE_NAME')
          ? dotenv.env['DATABASE_NAME']!
          : 'finance_sync';
      final username = dotenv.env.containsKey('DATABASE_USER')
          ? dotenv.env['DATABASE_USER']!
          : 'postgres';
      final password = dotenv.env.containsKey('DATABASE_PASSWORD')
          ? dotenv.env['DATABASE_PASSWORD']!
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