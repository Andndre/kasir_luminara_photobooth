# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luminara Photobooth** is a Flutter POS/management system for photobooth businesses. It operates in two roles on a local network — **Server (Cashier)** runs an embedded HTTP/WebSocket server and manages transactions; **Client (Verifier)** connects to the server to scan and redeem tickets. The role is toggled at runtime via `AppMode` without restarting the app.

The app is in production use with real customer data on disk. Read "Never Change These" below before touching anything that persists.

## Build Commands

```bash
flutter pub get                  # Install dependencies
flutter analyze                  # Must be clean — no warnings, no infos
flutter test                     # Must be green
flutter run                      # Debug
flutter build apk --release      # Android
flutter build windows --release  # Windows
flutter build linux --release    # Linux
```

## Never Change These

Shipped installs hold real data under these exact names. Renaming any of them silently breaks upgrades — there is no migration path back.

**Tables and columns** (`lib/core/data/db.dart`):

| Table | Columns |
|---|---|
| `products` | `id`, `name`, `price` |
| `transactions` | `uuid`, `customer_name`, `total_price`, `bayar_amount`, `kembalian`, `payment_method`, `status`, `created_at`, `redeemed_at`, `midtrans_order_id`, `queue_number`, `queue_date` |
| `transaction_items` | `id`, `transaction_uuid`, `product_name`, `product_price`, `quantity` |
| `logs` | `id`, `timestamp`, `message`, `is_error` |
| `daily_queue_counter` | `date`, `last_number` |

`bayar_amount` and `kembalian` are Indonesian; the Dart fields are `amountPaid` and `changeGiven`. That mismatch is deliberate — the column names are frozen, the Dart names are not.

**Persisted enum strings**: `TUNAI`, `QRIS`, `NON-TUNAI`, `PAID`, `COMPLETED`, `CANCELLED`.

**SharedPreferences keys**: `is_midtrans_enabled`, `verifier_server_ip`, `verifier_server_port`, `theme_mode`, `printer_paper_mm80_<mac>`, `printer_last_mac`, `profile`.

**Backup file JSON keys**: `version`, `tables`, and the five table names nested under `tables`. Customers have backup files on disk in this format.

**HTTP wire format** (`/api/queue`, `/api/verify`): a verifier running an older build may be on the same network. Adding keys is safe; renaming or removing one is not. See `QueueTicket.toJson()`.

Adding a table or column requires bumping `_schemaVersion` in `db.dart` **and** adding an `oldVersion < n` branch in `_onUpgrade`. Editing `_onCreate` alone leaves upgraded installs missing it.

## Architecture

### Layers

```
lib/
├── app/           Composition root: MyApp, routes, splash
├── core/
│   ├── domain/    Immutable value types. No I/O, no Flutter imports.
│   ├── data/      db.dart (schema) + repositories/ + Result<T>
│   ├── blocs/     AsyncState<T>, shared by every feature
│   ├── services/  server, verifier, midtrans, background
│   ├── helpers/   AppLog, Currency, PrinterHelper, SnackBarHelper
│   ├── components/ Shared widgets
│   └── preferences/ Theme, tokens, SharedPreferences wrappers
└── features/<name>/
    ├── blocs/     Cubit + its state
    ├── pages/     Screens
    ├── widgets/   Feature-local widgets
    └── services/  Feature-local I/O
```

Dependencies point inward: `features` → `core/data` → `core/domain`. Domain knows nothing about persistence or UI.

### Data access: repositories only

Widgets and cubits **never** touch `getDatabase()` directly. All SQL lives in `lib/core/data/repositories/`. Repositories return `Result<T>` (`lib/core/data/result.dart`) rather than throwing:

```dart
switch (await repo.all()) {
  case Ok(:final value): // use value
  case Err(:final message): // message is safe to show the user
}
```

Wrap repository bodies in `runCatching('Pesan untuk user', () async { ... })`.

### State management

- `AppState` (Provider/ChangeNotifier): global `AppMode` and `ThemeMode` only.
- **Every screen that loads data owns a Cubit.** `setState` is for local UI state only — form fields, a scanner's "already handled" guard, a loading flag on a button. Never for data.
- Cubits consume repositories, never the DB.
- Loading/loaded/failed is `AsyncState<T>` (`lib/core/blocs/async_state.dart`), not three separate fields. Switch on it in the UI so the compiler checks every case. `AsyncLoading` carries the previous value so lists don't blink to a spinner on refresh.
- **Critical**: `MultiBlocProvider` sits **above** `MaterialApp` in `app/app.dart`, never inside the `Consumer` that rebuilds on theme change — otherwise every theme switch resets bloc state.

### Refreshing after a restore

`dataRefresh` (`lib/core/data/data_refresh.dart`) is a dedicated notifier fired when the whole database is replaced. Screens listen to it. Do **not** reuse `AppState` for this — it also notifies on every theme toggle, which used to reload every list in the app.

### Typed enums

`TransactionStatus` is a real enum (closed set, exhaustive switches).

`PaymentMethod` is deliberately **a class, not an enum**. `transactions.payment_method` already holds free-form Midtrans channel names on shipped devices (`GoPay/GoPay Later`, `Bank Transfer (VA)`). A closed enum maps all of those to its fallback and silently relabels old rows as cash. `PaymentMethod.fromDb` keeps unknown values verbatim. There is a test pinning this — do not "simplify" it into an enum.

### Server (ServerService)

Singleton using `alfred`. Main isolate on desktop, background isolate via `flutter_background_service` on Android.

- `GET /health` — health check
- `GET /api/queue` — unredeemed tickets, in call order
- `POST /api/verify` — redeem a ticket by UUID
- `GET /ws` — WebSocket for `TICKET_REDEEMED` / `REFRESH_QUEUE` broadcasts

Redeeming uses a conditional `UPDATE ... WHERE status = 'PAID'` so two verifiers scanning the same ticket can't both succeed. The outcome is a sealed `RedeemOutcome` (`RedeemedOk` / `TicketNotFound` / `TicketAlreadyUsed`).

### Logging

`AppLog.error(...)` / `AppLog.info(...)` write to the `logs` table. Both swallow their own failures — they're called from `catch` blocks, so a logging failure must never mask the original error. Never use `print()`; use `AppLog` or `debugPrint`.

### Money

All Rupiah formatting goes through `Currency.format()` (`lib/core/helpers/currency.dart`). Never construct `NumberFormat.currency` inline. `Currency.parse()` reads user input and returns null rather than throwing.

## Key Constraints (Stability Rules)

1. **No nested MaterialApp** — breaks Navigator history and causes `Scaffold.geometryOf` exceptions.
2. **No FFI in background Isolate on Linux** — `sqflite_common_ffi` in a background Isolate on Linux causes GTK deadlocks. Keep `ServerService` in the main isolate.
3. **Server binds to `0.0.0.0`**, not `localhost`. Firewall must allow port 3000 (`sudo ufw allow 3000/tcp` on Linux).
4. **Desktop server startup** — do not auto-start the server in `initState`. Keep the manual "Start Server" button so the GTK window is initialized before opening network ports.
5. **Theme parity** — `LightTheme` and `DarkTheme` must define identical properties (same `fontFamily`, `fontSize`, borders, hint styles). Missing properties cause `Failed to interpolate TextStyles` crashes on theme switch.
6. **Scroll behavior** — do not add `PointerDeviceKind.mouse` to `dragDevices` in `AppScrollBehavior`; it intercepts button clicks on desktop.
7. **NavigationRail layout** — place it directly in a `Row` with `crossAxisAlignment: CrossAxisAlignment.start`. Do not wrap in `SingleChildScrollView + IntrinsicHeight + Expanded` — circular layout dependency.
8. **Grid layout** — prefer `SliverGridDelegateWithMaxCrossAxisExtent` with a fixed `mainAxisExtent` over `FixedCrossAxisCount + childAspectRatio`, which overflows on wide screens.
9. **`Transaction` shadows sqflite's** — files needing both import sqflite with `hide Transaction`.
10. **Never fade to `Colors.transparent`** — that is black at alpha 0, so the animation passes through grey. Fade to the same colour with alpha 0 instead.

## Platform Gotchas

**`file_picker` has opposite contracts per platform.** This broke backup on Android for a whole release:

| | `bytes` | who writes the file | return value |
|---|---|---|---|
| Windows/Linux | ignored | **you must** | real path |
| Android/iOS | **required, else throws** | the plugin does | display-only path |

Also: Android resolves extension filters through `MimeTypeMap`, which has no `json` entry on many builds — the filter comes back empty and the picker errors or hides the file. Use `FileType.any` on mobile and validate the content instead. See `BackupService`.

**Other platform notes:**
- **Android**: background isolate for the server. Requests `notification`, `bluetooth`, `location` permissions.
- **Linux/Windows**: main isolate server, FFI SQLite, `desktop_webview_window` for Midtrans.
- **Windows**: auto-requests a firewall rule for port 3000 on first launch.
- Desktop DB lives in the app support dir: `~/.local/share/luminara_photobooth/photobooth.db` (Linux), `%APPDATA%\...\photobooth.db` (Windows).

## Payment Integration

Midtrans payment opens a WebView (native dialog on Android, popup window on desktop via `desktop_webview_window`). `MidtransService` returns typed results: `MidtransSession` for creation, `MidtransStatus` for polling.

`PaymentPoller` (`lib/features/cashier/payment_poller.dart`) polls until the payment resolves **or a 15-minute deadline passes**, and won't stack overlapping requests. Any polling loop added here needs a stop condition — the original had none and kept hitting the network forever after the customer walked away.

`MidtransStatus.unreachable` is distinct from `unknown` on purpose: a network blip must not be read as a verdict.

## Testing

`flutter test` must stay green. Tests live in `test/`.

The database is testable without `path_provider`: set `debugDatabasePath = inMemoryDatabasePath` and call `resetDatabase()` in `setUp`/`tearDown` (see `test/photobooth_test.dart`).

Pure logic should be extracted so it can be tested without pumping a widget — `CashDenominations`, `Cart`, `ServerAddress.tryParse`, `BackupService.buildBackupJson` / `applyBackupJson` all exist as separate units for this reason. When adding non-trivial logic, put it somewhere a test can reach it.

Tests that pin behaviour someone might "fix" incorrectly (persisted enum strings, `PaymentMethod` keeping unknown values, backup rejecting corrupt files without deleting data) are load-bearing. Don't delete them to make a change pass.

## Conventions

- File names mirror their primary class: `settings_page.dart` → `SettingsPage`. No generic `page.dart`.
- Each feature has a barrel (`features/<name>/<name>.dart`).
- Comments explain **why**, not what — especially where the obvious approach is wrong. Keep the existing Indonesian comments; new ones can be either language.
- Domain models are immutable with `copyWith`. Prefer deriving values (`totalPrice` from items) over storing them, so two fields can't disagree.
