# HomeCare Monorepo

This repository contains the Flutter client application (`homecare_app`) and the
Dart backend (`homecare_backend`). The steps below walk through bringing up the
infrastructure, running database migrations, launching the API, configuring the
client, and starting the mobile app end to end.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.0 or newer (which
  bundles a matching Dart SDK).
- Docker and Docker Compose for provisioning Postgres.
- A running Android emulator, iOS simulator, or physical device for the Flutter
  app.

## Initial configuration

1. Copy the backend environment template and adjust the values as needed. The
   default values expose the backend on port `8080` and Postgres on `5432`:

   ```bash
   cp homecare_backend/.env.example homecare_backend/.env
   ```

2. Install dependencies for both projects (run once per clone):

   ```bash
   (cd homecare_backend && dart pub get)
   (cd homecare_app && flutter pub get)
   ```

## End-to-end workflow

1. **Start PostgreSQL via Docker**

   From `homecare_backend/`, bring up the Postgres container defined in
   `docker-compose.yml`:

   ```bash
   cd homecare_backend
   docker compose up -d
   ```

   The database is exposed on `localhost:5432` by default. Verify connectivity
   with `docker compose ps` if needed.

2. **Run database migrations**

   With Postgres running and environment variables loaded from `.env`, execute
   the migration script:

   ```bash
   dart run tool/migrate.dart
   ```

   The script applies every `.sql` file in `homecare_backend/migrations/` using
   the connection information from `.env`.

3. **Launch the backend server**

   Start the HTTP API (and Socket.IO server) from the backend package:

   ```bash
   dart run bin/server.dart
   ```

   By default the service listens on port `8080` (configure `APP_PORT` in
   `.env` to change it). Keep this process running while you use the client.

4. **Configure Flutter environment**

   Update the Flutter client so it targets the correct backend host and port.
   The defaults are set for an Android emulator (`http://10.0.2.2:8080`) in
   `homecare_app/lib/core/constants/app_constants.dart`. Adjust the values if
   you are running on another platform:

   - Android emulator: `http://10.0.2.2:8080`
   - iOS simulator / macOS / web: `http://localhost:8080`
   - Physical devices: `http://<your-computer-ip>:8080`

   You can also override the constants at runtime with Flutter defines:

   ```bash
   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8080
   ```

   (Make sure the code reading `AppConstants.baseUrl` respects your chosen
   configuration.)

5. **Run the Flutter app**

   From `homecare_app/`, launch the client on your target device:

   ```bash
   cd ../homecare_app
   flutter run
   ```

   Flutter connects to the backend over HTTP on port `8080` and uses the same
   port for Socket.IO real-time updates.

## Troubleshooting

- **Android desugaring errors** – If Gradle reports missing desugared libraries,
  confirm that `isCoreLibraryDesugaringEnabled = true` and the
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")`
  dependency are present in `homecare_app/android/app/build.gradle.kts`. Run
  `flutter clean` followed by `flutter pub get` before rebuilding.

- **Emulator cannot reach the backend** – Android emulators cannot hit
  `localhost` directly. Use `10.0.2.2` as shown above or run
  `adb reverse tcp:8080 tcp:8080` for physical devices. For iOS simulators,
  `localhost` works, but ensure the backend is bound to `0.0.0.0` (the default
  in `bin/server.dart`).

- **Docker port conflicts** – If `5432` is already in use, stop the conflicting
  service or edit the port mapping in `homecare_backend/docker-compose.yml` to
  a free port (for example, `55432:5432`) and update the database URL in
  `.env` accordingly before rerunning migrations.

With these steps complete you can iterate on both the backend and Flutter app
locally with a single command chain.
