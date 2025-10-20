# HomeCare Backend

## Getting Started

1. **Install prerequisites**
   - Dart SDK version 3.0.0 or higher.
   - Docker and Docker Compose.
2. **Start supporting services**
   ```bash
   docker compose up -d
   ```
3. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```
   Update the new `.env` file with any project-specific values.
4. **Run database migrations**
   ```bash
   dart run tool/migrate.dart
   ```
5. **Launch the development server**
   ```bash
   dart run bin/server.dart
   ```

With these steps complete, the backend should be running locally and ready for development or testing.
