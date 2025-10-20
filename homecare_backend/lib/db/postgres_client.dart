// lib/db/postgres_client.dart
import 'dart:io';

import 'package:postgres/postgres.dart';

class PostgresClient {
  late final PostgreSQLConnection _connection;

  PostgresClient._(this._connection);

  static PostgresClient fromEnv() {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl != null && databaseUrl.isNotEmpty) {
      final uri = Uri.parse(databaseUrl);

      final userInfo = uri.userInfo;
      String? username;
      String? password;
      if (userInfo.isNotEmpty) {
        final separatorIndex = userInfo.indexOf(':');
        if (separatorIndex == -1) {
          username = Uri.decodeComponent(userInfo);
        } else {
          username =
              Uri.decodeComponent(userInfo.substring(0, separatorIndex));
          password = Uri.decodeComponent(userInfo.substring(separatorIndex + 1));
        }
      }

      final databaseName = uri.pathSegments.isNotEmpty
          ? Uri.decodeComponent(uri.pathSegments.first)
          : Uri.decodeComponent(uri.path.replaceFirst('/', ''));

      if (databaseName.isEmpty) {
        throw ArgumentError('DATABASE_URL must include a database name');
      }

      final sslMode = uri.queryParameters['sslmode']?.toLowerCase();
      final useSSL = sslMode == 'require' || sslMode == 'verify-full';

      final conn = PostgreSQLConnection(
        uri.host,
        uri.hasPort ? uri.port : 5432,
        databaseName,
        username: username,
        password: password,
        useSSL: useSSL,
      );
      return PostgresClient._(conn);
    }

    final host = Platform.environment['DB_HOST'] ?? 'localhost';
    final port = int.parse(Platform.environment['DB_PORT'] ?? '5432');
    final db = Platform.environment['DB_NAME'] ?? 'homecare';
    final user = Platform.environment['DB_USER'] ?? 'dev';
    final pass = Platform.environment['DB_PASS'] ?? 'devpass';

    final conn =
        PostgreSQLConnection(host, port, db, username: user, password: pass);
    return PostgresClient._(conn);
  }

  Future<void> connect() async {
    await _connection.open();
  }

  Future<void> close() async => await _connection.close();

  PostgreSQLConnection get raw => _connection;
}
