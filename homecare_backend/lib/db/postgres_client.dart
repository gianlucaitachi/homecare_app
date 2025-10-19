// lib/db/postgres_client.dart
import 'package:postgres/postgres.dart';
import 'dart:io';

class PostgresClient {
  late final PostgreSQLConnection _connection;

  PostgresClient._(this._connection);

  static PostgresClient fromEnv() {
    final host = Platform.environment['DB_HOST'] ?? 'localhost';
    final port = int.parse(Platform.environment['DB_PORT'] ?? '5432');
    final db = Platform.environment['DB_NAME'] ?? 'homecare';
    final user = Platform.environment['DB_USER'] ?? 'dev';
    final pass = Platform.environment['DB_PASS'] ?? 'devpass';

    final conn = PostgreSQLConnection(host, port, db, username: user, password: pass);
    return PostgresClient._(conn);
  }

  Future<void> connect() async {
    await _connection.open();
  }

  Future<void> close() async => await _connection.close();

  PostgreSQLConnection get raw => _connection;
}
