# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luminara Photobooth** is a Flutter POS/management system for photobooth businesses. It operates in two roles on a local network — **Server (Cashier)** runs an embedded HTTP/WebSocket server and manages transactions; **Client (Verifier)** connects to the server to scan and redeem tickets. The role is toggled at runtime via `AppMode` without restarting the app.

## Build Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint check
flutter run              # Run in debug mode
flutter build apk --release   # Android APK
flutter build linux --release # Linux desktop
flutter clean && flutter build apk --release # Full clean build
```

## Architecture

### Dual-Mode System

`AppMode` (server/client) is stored in `AppState` and drives which page set renders in `MainPage`:
- **Server mode**: `HomePage`, `TransactionPage`, `ProductPage`, `SettingPage` + embedded `Alfred` server on port 3000
- **Client mode**: `ClientHomePage`, `LiveQueuePage`, `HandshakePage`, `SettingPage` + WebSocket connection to server

Navigation uses `BottomNavBloc` (flutter_bloc) for index tracking. On desktop (width > 700px), `NavigationRail` is used; on mobile, `BottomAppBar`.

### State Management

- `AppState` (Provider/ChangeNotifier): global `AppMode` and `ThemeMode`
- `flutter_bloc`: feature-level blocs (`BottomNavBloc`, `ProfileBloc`, `ServerBloc`, `VerifierBloc`)
- **Critical**: `MultiBlocProvider` is placed **above** `MaterialApp` in the widget tree — never inside a `Consumer` that rebuilds on state change, as this resets bloc state on every theme/mode switch.

### Database

SQLite via `sqflite` (Android) or `sqflite_common_ffi` (Linux/Windows). Desktop DB path: `~/.local/share/luminara_photobooth/photobooth.db`. Tables: `products`, `transactions`, `transaction_items`, `logs`.

`getDatabase()` is the singleton accessor — call it anywhere to get the open DB.

### Server (ServerService)

Singleton using `alfred` package. Runs in the main isolate on desktop (Linux/Windows) and in a background isolate via `flutter_background_service` on Android. Key endpoints:
- `GET /health` — health check
- `GET /api/queue` — all PAID transactions with items
- `POST /api/verify` — redeem a ticket by UUID
- `GET /ws` — WebSocket for real-time `TICKET_REDEEMED` broadcasts

### Key Constraints (Stability Rules)

1. **No nested MaterialApp** — breaks Navigator history and causes `Scaffold.geometryOf` exceptions.
2. **No FFI in background Isolate on Linux** — running `sqflite_common_ffi` in a background Isolate on Linux causes GTK deadlocks. Keep `ServerService` in the main isolate.
3. **Server binds to `0.0.0.0`** — not `localhost`. Firewall must allow port 3000 (`sudo ufw allow 3000/tcp` on Linux).
4. **Desktop server startup** — do not auto-start the server in `initState`. Provide a manual "Start Server" button so the GTK window is fully initialized before opening network ports.
5. **Theme parity** — `LightTheme` and `DarkTheme` must define identical properties (same `fontFamily`, `fontSize`, borders, hint styles). Missing properties cause `Failed to interpolate TextStyles` crashes during theme switching.
6. **Scroll behavior** — do not add `PointerDeviceKind.mouse` to `dragDevices` in `AppScrollBehavior`; it intercepts button clicks on desktop.
7. **NavigationRail layout** — place `NavigationRail` directly in a `Row` with `crossAxisAlignment: CrossAxisAlignment.start`. Do not wrap it in `SingleChildScrollView + IntrinsicHeight + Expanded` — causes circular layout dependencies.
8. **Grid layout** — prefer `SliverGridDelegateWithMaxCrossAxisExtent` with fixed `mainAxisExtent` over `FixedCrossAxisCount + childAspectRatio` to avoid overflow on wide screens.

### Platform-Specific Behavior

- **Android**: Background Isolate for server via `flutter_background_service`. Requests `notification`, `bluetooth`, `location` permissions.
- **Linux/Windows**: Main isolate server, FFI-based SQLite, `desktop_webview_window` for Midtrans payment WebView.
- **Windows**: Auto-requests firewall rule for port 3000 on first launch.

### Logging

`Log.insertLog(message, isError: bool)` inserts into the `logs` table. Global errors are caught via `runZonedGuarded` in `main.dart` and also logged.

### Payment Integration

Midtrans payments use a WebView (native dialog on Android, popup window on Linux/Windows via `desktop_webview_window`). The `MidtransService` handles payment initiation and status polling.
