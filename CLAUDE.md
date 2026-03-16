# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter Android application for Inmobarco Real Estate Company. Android-only target. Primary markets: Colombian cities (Medellín metro area). All user-facing text is in Spanish.

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run app (select device)
flutter analyze          # Static analysis / linting
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run specific test file
flutter build apk        # Build Android APK
```

## Architecture

The project follows Clean Architecture with these layers:

- **`lib/core/`** — Cross-cutting concerns: constants, services (global data singleton, notifications), and theme
- **`lib/data/`** — External communication: API clients, cache, auth, and sync services
- **`lib/domain/`** — Business models: `Apartment`, `Appointment`, `PropertyFilter`, `User`
- **`lib/ui/providers/`** — State (Provider/ChangeNotifier): `AuthProvider`, `PropertyProvider`, `AppointmentProvider`
- **`lib/ui/screens/`** — Screens navigated via bottom tabs in `HomeScreen`
- **`lib/ui/widgets/`** — Reusable UI components

## State Management

Uses the `provider` package with `ChangeNotifier`. The three main providers are registered at the root in `main.dart`:

- **`AuthProvider`** — Login/logout, JWT token, session persistence
- **`PropertyProvider`** — Property list with pagination (100/page), search debounce (350ms), filter persistence via SharedPreferences
- **`AppointmentProvider`** — Local-first CRUD; `SyncService` handles async server sync

## Dual API Integration

**WASI API** (`WasiApiService`) — Read-only property data from `https://api.wasi.co/v1`; uses an API token configured in `.env`.

**Custom Backend** (`ApiService`) — Appointment CRUD at `http://194.163.147.243:8080`; uses JWT token stored in SharedPreferences after login.

Credentials and API keys are stored in `assets/config/.env` (loaded via `flutter_dotenv`). Never hardcode secrets.

## Offline Sync (`SyncService`)

Singleton with three sync triggers:
1. **App startup** — immediate full sync
2. **Timer** — every 5 minutes
3. **Connectivity** — triggers on offline→online transition (via `connectivity_plus`)

Appointments use a local queue for offline mutations; the queue is compacted before each sync to avoid inconsistencies.

## Caching (`CacheService`)

- Properties: file-based JSON cache (via `path_provider`) with 6-hour expiration
- Appointments: SharedPreferences-based cache
- Auth session: persisted in SharedPreferences

## Navigation

`HomeScreen` owns a bottom `NavigationBar` with two tabs: Properties and Calendar. There is no named route system — screens are navigated using `Navigator.push()` directly. Authentication state determines which tabs render.

## Key Constants (`core/constants/app_constants.dart`)

- Allowed cities: Envigado, Medellín, Sabaneta, La Estrella, Itagüí, Bello
- API timeouts: 10s connect/send, 15s receive (standard); 120s send for webhooks
- Pagination: 100 items/page, load-more triggers at 200px scroll threshold
- Primary color: `#1B99D3`

## Localization

All date formatting uses `es_ES` locale via the `intl` package. Timezone is `America/Bogota`.

## Build Scripts

- `build_android.bat` — Android release build
