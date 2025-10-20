import 'dart:io';

import 'package:postgres/postgres.dart';

class DatabaseManager {
  DatabaseManager._(this._connection);

  final Connection _connection;

  static Future<DatabaseManager> connect({String? databaseUrl}) async {
    final url = databaseUrl ??
        Platform.environment['DATABASE_URL'] ??
        'postgres://dev:devpass@localhost:5432/homecare';

    final uri = Uri.parse(url);
    final host = uri.host.isNotEmpty ? uri.host : 'localhost';
    final port = uri.hasPort && uri.port != 0 ? uri.port : 5432;
    final pathSegments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final database = pathSegments.isNotEmpty ? pathSegments.first : 'postgres';

    String? username;
    String? password;
    if (uri.userInfo.isNotEmpty) {
      final parts = uri.userInfo.split(':');
      username = Uri.decodeComponent(parts.first);
      if (parts.length > 1) {
        password = Uri.decodeComponent(parts.sublist(1).join(':'));
      }
    }

    final endpoint = Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );

    final sslMode = _parseSslMode(uri.queryParameters['sslmode']);

    final connection = await Connection.open(
      endpoint,
      settings: ConnectionSettings(
        sslMode: sslMode ?? SslMode.disable,
      ),
    );

    return DatabaseManager._(connection);
  }

  Connection get conn => _connection;

  Future<void> close({bool force = false}) => _connection.close(force: force);

  static SslMode? _parseSslMode(String? value) {
    switch (value?.toLowerCase()) {
      case 'require':
        return SslMode.require;
      case 'verify-full':
      case 'verify_full':
        return SslMode.verifyFull;
      case 'disable':
        return SslMode.disable;
      default:
        return null;
    }
  }
}
