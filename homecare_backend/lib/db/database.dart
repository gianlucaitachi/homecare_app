import 'dart:io';

import 'package:postgres/postgres.dart';

class DatabaseManager {
  DatabaseManager._(this._endpoint, this._settings);

  final Endpoint _endpoint;
  final ConnectionSettings _settings;
  Connection? _connection;

  static DatabaseManager fromEnv() {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl != null && databaseUrl.isNotEmpty) {
      final uri = Uri.parse(databaseUrl);
      final username = uri.userInfo.isNotEmpty
          ? Uri.decodeComponent(uri.userInfo.split(':').first)
          : null;
      final password = uri.userInfo.contains(':')
          ? Uri.decodeComponent(uri.userInfo.split(':').last)
          : null;

      final pathSegments = uri.pathSegments.where((segment) => segment.isNotEmpty);
      final databaseName = pathSegments.isNotEmpty
          ? Uri.decodeComponent(pathSegments.first)
          : Uri.decodeComponent(uri.path.replaceFirst('/', ''));

      if (databaseName.isEmpty) {
        throw ArgumentError('DATABASE_URL must include a database name');
      }

      final sslMode = _parseSslMode(uri.queryParameters['sslmode']);

      final endpoint = Endpoint(
        host: uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: databaseName,
        username: username?.isEmpty == true ? null : username,
        password: password?.isEmpty == true ? null : password,
      );

      return DatabaseManager._(
        endpoint,
        ConnectionSettings(sslMode: sslMode),
      );
    }

    final host = Platform.environment['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(Platform.environment['DB_PORT'] ?? '') ?? 5432;
    final database = Platform.environment['DB_NAME'] ?? 'homecare';
    final username = Platform.environment['DB_USER'] ?? 'dev';
    final password = Platform.environment['DB_PASS'] ?? 'devpass';
    final sslMode = _parseSslMode(
      Platform.environment['DB_SSLMODE'] ?? Platform.environment['DB_SSL'],
    );

    final endpoint = Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );

    return DatabaseManager._(
      endpoint,
      ConnectionSettings(sslMode: sslMode),
    );
  }

  Future<void> open() async {
    if (_connection != null) {
      return;
    }

    _connection = await Connection.open(_endpoint, settings: _settings);
  }

  Connection get conn {
    final connection = _connection;
    if (connection == null) {
      throw StateError('Database connection has not been opened');
    }
    return connection;
  }

  Future<void> close() async {
    final connection = _connection;
    if (connection != null) {
      await connection.close();
      _connection = null;
    }
  }

  static SslMode _parseSslMode(String? value) {
    switch (value?.toLowerCase()) {
      case 'require':
      case 'true':
        return SslMode.require;
      case 'verify-full':
      case 'verify_full':
        return SslMode.verifyFull;
      case 'disable':
      case 'false':
      case null:
        return SslMode.disable;
      default:
        return SslMode.disable;
    }
  }
}
