import 'dart:io';

import 'package:postgres/postgres.dart';

class DatabaseManager {
  DatabaseManager._(this._endpoint, this._settings);

  final Endpoint _endpoint;
  final ConnectionSettings _settings;
  Connection? _connection;

  static DatabaseManager? _instance;

  static DatabaseManager get instance {
    return _instance ??= _fromEnv();
  }

  static DatabaseManager _fromEnv() {
    final databaseUrl = Platform.environment['DATABASE_URL'];
    if (databaseUrl == null || databaseUrl.isEmpty) {
      throw StateError('DATABASE_URL environment variable is required.');
    }

    final uri = Uri.parse(databaseUrl);

    final databaseName = uri.pathSegments.isNotEmpty
        ? Uri.decodeComponent(uri.pathSegments.first)
        : Uri.decodeComponent(uri.path.replaceFirst('/', ''));

    if (databaseName.isEmpty) {
      throw ArgumentError('DATABASE_URL must include a database name');
    }

    String? username;
    String? password;
    if (uri.userInfo.isNotEmpty) {
      final separatorIndex = uri.userInfo.indexOf(':');
      if (separatorIndex == -1) {
        username = Uri.decodeComponent(uri.userInfo);
      } else {
        username = Uri.decodeComponent(uri.userInfo.substring(0, separatorIndex));
        password = Uri.decodeComponent(uri.userInfo.substring(separatorIndex + 1));
      }
    }

    final sslMode = _parseSslMode(uri.queryParameters['sslmode']);

    final host = uri.host.isEmpty ? 'localhost' : uri.host;

    final endpoint = Endpoint(
      host: host,
      port: uri.hasPort ? uri.port : 5432,
      database: databaseName,
      username: username,
      password: password,
    );

    final settings = ConnectionSettings(
      sslMode: sslMode,
    );

    return DatabaseManager._(endpoint, settings);
  }

  static SslMode? _parseSslMode(String? value) {
    switch (value?.toLowerCase()) {
      case 'disable':
        return SslMode.disable;
      case 'require':
        return SslMode.require;
      case 'verify-full':
        return SslMode.verifyFull;
      default:
        return null;
    }
  }

  Future<void> connect() async {
    if (_connection != null) {
      if (_connection!.isOpen) {
        return;
      }
      await _connection!.close();
      _connection = null;
    }

    _connection = await Connection.open(_endpoint, settings: _settings);
  }

  Future<void> close() async {
    final current = _connection;
    if (current != null) {
      await current.close();
      _connection = null;
    }
  }

  Connection get conn {
    final current = _connection;
    if (current == null || !current.isOpen) {
      throw StateError('Database connection is not open. Call connect() first.');
    }
    return current;
  }
}
