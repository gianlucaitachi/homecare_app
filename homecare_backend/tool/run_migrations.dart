import 'dart:io';

import 'package:homecare_backend/db/postgres_client.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  final migrationsDir = Directory('migrations');
  if (!await migrationsDir.exists()) {
    stderr.writeln('Migrations directory not found at ${migrationsDir.path}');
    exitCode = 1;
    return;
  }

  final migrationFiles = await migrationsDir
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.sql'))
      .cast<File>()
      .toList();

  migrationFiles.sort((a, b) => a.path.compareTo(b.path));

  if (migrationFiles.isEmpty) {
    stdout.writeln('No migration files found.');
    return;
  }

  final client = PostgresClient.fromEnv();
  await client.connect();
  stdout.writeln('Connected to database, applying ${migrationFiles.length} migrations...');

  try {
    await client.raw.transaction((ctx) async {
      for (final file in migrationFiles) {
        final sql = await file.readAsString();
        final statements = _splitSqlStatements(sql);
        stdout.writeln('Applying migration: ${file.uri.pathSegments.last}');
        for (final statement in statements) {
          if (statement.trim().isEmpty) continue;
          await ctx.execute(statement);
        }
      }
    });
    stdout.writeln('Migrations applied successfully.');
  } on PostgreSQLException catch (e) {
    stderr.writeln('Failed to apply migrations: ${e.message}');
    exitCode = 1;
  } finally {
    await client.close();
  }
}

final _dollarQuotePattern = RegExp(r'\$[A-Za-z0-9_]*\$');

List<String> _splitSqlStatements(String sql) {
  final statements = <String>[];
  var buffer = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;
  String? dollarQuoteTag;

  for (var i = 0; i < sql.length; i++) {
    final char = sql[i];
    final nextChar = i + 1 < sql.length ? sql[i + 1] : null;

    if (dollarQuoteTag != null) {
      if (sql.startsWith(dollarQuoteTag, i)) {
        buffer.write(dollarQuoteTag);
        i += dollarQuoteTag.length - 1;
        dollarQuoteTag = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == '\'' && !inDoubleQuote) {
      if (inSingleQuote) {
        if (nextChar == \'') {
          buffer.write(char);
          buffer.write(nextChar);
          i++;
          continue;
        }
        inSingleQuote = false;
      } else {
        inSingleQuote = true;
      }
      buffer.write(char);
      continue;
    }

    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      buffer.write(char);
      continue;
    }

    if (!inSingleQuote && !inDoubleQuote && char == r'$') {
      final match = _dollarQuotePattern.matchAsPrefix(sql, i);
      if (match != null) {
        dollarQuoteTag = match.group(0);
        buffer.write(dollarQuoteTag);
        i += dollarQuoteTag!.length - 1;
        continue;
      }
    }

    if (char == ';' && !inSingleQuote && !inDoubleQuote && dollarQuoteTag == null) {
      final statement = buffer.toString().trim();
      if (statement.isNotEmpty) {
        statements.add(statement);
      }
      buffer = StringBuffer();
      continue;
    }

    buffer.write(char);
  }

  final last = buffer.toString().trim();
  if (last.isNotEmpty) {
    statements.add(last);
  }

  return statements;
}
