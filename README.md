# HomeCare Backend & Development Environment

This repository contains the HomeCare backend service implemented in Dart together with helper assets to spin up a local development environment quickly.

## Requirements

- [Dart SDK](https://dart.dev/get-dart) 3.x
- PostgreSQL 13+ (local install or via Docker)
- `psql` CLI (optional, only needed if you prefer to run SQL files manually)

## Environment configuration

The backend reads configuration from environment variables. Copy the provided template and adjust it for your local setup:

```bash
cp .env.example .env
```

| Variable | Description | Default in code |
| --- | --- | --- |
| `DB_HOST` | Database host name | `localhost`
| `DB_PORT` | Database port | `5432`
| `DB_NAME` | Database name | `homecare`
| `DB_USER` | Database user | `dev`
| `DB_PASS` | Database password | `devpass`
| `JWT_ACCESS_SECRET` | Secret used to sign access tokens | `dev_access_secret`
| `JWT_REFRESH_SECRET` | Secret used to sign refresh tokens | `dev_refresh_secret`
| `PORT` | HTTP port that the API server binds to | `8080`

> **Security note:** Always replace the default JWT secrets with strong random strings in real deployments.

To load the variables you can either export them manually (`export VAR=value`) or use a tool such as [`direnv`](https://direnv.net/) or [`dotenv`](https://github.com/motdotla/dotenv).

## Installing dependencies

Inside the backend package run:

```bash
cd homecare_backend
dart pub get
```

## Database migrations

Migration files live under [`homecare_backend/migrations/`](homecare_backend/migrations). A helper script is provided to apply every `.sql` file in order:

```bash
cd homecare_backend
dart run tool/run_migrations.dart
```

The script connects with the credentials provided via environment variables and executes the SQL inside a single transaction. You can re-run it safely; PostgreSQL will ignore statements that already exist (for example, `CREATE TABLE IF NOT EXISTS`).

If you prefer manual execution, you can run each file with `psql`:

```bash
psql postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME -f migrations/001_create_users_table.sql
```

## Running the development server

After exporting the environment variables and applying migrations, start the API server:

```bash
cd homecare_backend
dart run bin/server.dart
```

The server listens on the port specified by `PORT` (default `8080`).

## Docker Compose workflow

A ready-to-use `docker-compose.yml` is available to launch both PostgreSQL and the Dart backend without installing local dependencies:

```bash
docker compose up --build
```

Useful Compose targets:

- `docker compose up db` — start only the PostgreSQL service.
- `docker compose run --rm backend dart run tool/run_migrations.dart` — apply migrations inside the backend container.
- `docker compose logs -f backend` — tail the backend logs.

The Compose file mounts the local `homecare_backend` directory, so code changes are reflected immediately. Adjust secrets by creating an `.env` file in the project root before running Compose.

## Project structure

```
.
├── .env.example         # Environment template
├── docker-compose.yml   # Local development stack (PostgreSQL + backend)
├── README.md            # This guide
└── homecare_backend
    ├── bin/             # Entry point for the server
    ├── lib/             # Application source code
    ├── migrations/      # Database migrations
    └── tool/            # Developer tooling (e.g. migration runner)
```

Happy hacking!
