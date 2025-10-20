import 'dart:io';

import 'package:homecare_backend/db/database.dart';

Future<void> main(List<String> args) async {
  final migrationsDir = Directory('migrations');
  if (!await migrationsDir.exists()) {
    stderr.writeln('Migrations directory not found at ${migrationsDir.path}');
    exit(1);
  }

  final db = DatabaseManager.fromEnv();
  var exitCodeValue = 0;

  try {
    await db.open();

    final migrationFiles = await migrationsDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.sql'))
        .cast<File>()
        .toList();

    migrationFiles.sort((a, b) => a.path.compareTo(b.path));

    for (final file in migrationFiles) {
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path;
      stdout.writeln('Running migration: $fileName');

      final sql = await file.readAsString();
      final statements = _splitSqlStatements(sql);

      for (final statement in statements) {
        if (statement.trim().isEmpty) {
          continue;
        }
        await db.conn.execute(statement);
      }
    }

    stdout.writeln('Migrations completed successfully.');
  } catch (error, stackTrace) {
    exitCodeValue = 1;
    stderr.writeln('Migration failed: $error');
    stderr.writeln(stackTrace);
  } finally {
    await db.close();
  }

  if (exitCodeValue != 0) {
    exit(exitCodeValue);
  }
}

List<String> _splitSqlStatements(String sql) {
  final statements = <String>[];
  var buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  String? dollarTag;

  var index = 0;
  while (index < sql.length) {
    final char = sql[index];
    final nextChar = index + 1 < sql.length ? sql[index + 1] : null;

    if (dollarTag != null) {
      if (_matchesAt(sql, dollarTag, index)) {
        buffer.write(dollarTag);
        index += dollarTag.length;
        dollarTag = null;
        continue;
      }

      buffer.write(char);
      index++;
      continue;
    }

    if (!inSingleQuote &&
        !inDoubleQuote &&
        char == '-' &&
        nextChar == '-') {
      index += 2;
      while (index < sql.length &&
          sql[index] != '
' &&
          sql[index] != '
') {
        index++;
      }
      continue;
    }

    if (inSingleQuote) {
      buffer.write(char);
      if (char == "'" && nextChar == "'") {
        buffer.write(nextChar);
        index += 2;
        continue;
      }
      if (char == "'") {
        inSingleQuote = false;
      }
      index++;
      continue;
    }

    if (inDoubleQuote) {
      buffer.write(char);
      if (char == '"' && nextChar == '"') {
        buffer.write(nextChar);
        index += 2;
        continue;
      }
      if (char == '"') {
        inDoubleQuote = false;
      }
      index++;
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      buffer.write(char);
      index++;
      continue;
    }

    if (char == '"') {
      inDoubleQuote = true;
      buffer.write(char);
      index++;
      continue;
    }

    if (char == r'$') {
      final tag = _readDollarTag(sql, index);
      if (tag != null) {
        dollarTag = tag;
        buffer.write(tag);
        index += tag.length;
        continue;
      }
    }

    if (char == ';') {
      final statement = buffer.toString().trim();
      if (statement.isNotEmpty) {
        statements.add(statement);
      }
      buffer = StringBuffer();
      index++;
      continue;
    }

    buffer.write(char);
    index++;
  }

  final tail = buffer.toString().trim();
  if (tail.isNotEmpty) {
    statements.add(tail);
  }

  return statements;
}

bool _matchesAt(String source, String pattern, int index) {
  if (index + pattern.length > source.length) {
    return false;
  }
  for (var i = 0; i < pattern.length; i++) {
    if (source[index + i] != pattern[i]) {
      return false;
    }
  }
  return true;
}

String? _readDollarTag(String source, int index) {
  final length = source.length;
  if (index >= length || source[index] != r'$') {
    return null;
  }

  var end = index + 1;
  while (end < length) {
    final code = source.codeUnitAt(end);
    if (code == 36) {
      return source.substring(index, end + 1);
    }
    if (!_isIdentifierChar(code)) {
      break;
    }
    end++;
  }

  if (end == index + 1 && end < length && source.codeUnitAt(end) == 36) {
    return source.substring(index, end + 1);
  }

  return null;
}

bool _isIdentifierChar(int code) {
  return code == 95 ||
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
}
