# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luminara Photobooth** is a Flutter POS/management system for photobooth businesses. It operates in two roles — **Cashier** records transactions, **Verifier** scans and redeems tickets. Both talk to luminarabali.com over an account; the role is toggled at runtime via `AppMode` without restarting the app.

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
| `transactions` | `uuid`, `customer_name`, `total_price`, `bayar_amount`, `kembalian`, `payment_method`, `status`, `created_at`, `redeemed_at`, `midtrans_order_id`, `queue_number`, `queue_date`, `synced_at` |
| `transaction_items` | `id`, `transaction_uuid`, `product_name`, `product_price`, `quantity` |
| `logs` | `id`, `timestamp`, `message`, `is_error` |
| `daily_queue_counter` | `date`, `last_number` |
| `pending_deletes` | `uuid`, `deleted_at` |

`bayar_amount` and `kembalian` are Indonesian; the Dart fields are `amountPaid` and `changeGiven`. That mismatch is deliberate — the column names are frozen, the Dart names are not.

**Persisted enum strings**: `TUNAI`, `QRIS`, `NON-TUNAI`, `PAID`, `COMPLETED`, `CANCELLED`.

**SharedPreferences keys**: `is_midtrans_enabled`, `theme_mode`, `printer_paper_mm80_<mac>`, `printer_last_mac`, `profile`, `auth_token`, `auth_email`, `auth_last_verified`, `device_id`, `device_name`,
`sync_pull_cursor`,
`sync_redemption_cursor` (unused since the pull widened past redemptions, but
still cleared on logout so it can't leak into the next account).

**Backup file JSON keys**: `version`, `tables`, and the five table names nested under `tables`. Customers have backup files on disk in this format.

**HTTP wire format** (`/api/pos/queue`, `/api/pos/verify`): a verifier running an older build may still be pointed at the same account. Adding keys is safe; renaming or removing one is not. See `QueueTicket.toJson()` and `PosTransaction::toTicket()` on the Laravel side — the two must stay identical.

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
│   ├── services/  auth, cloud_api, sync, verifier, midtrans
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

### Verifier

`VerifierService` reads `GET /api/pos/queue` and redeems through
`POST /api/pos/verify`. The account pairs the scanner with the till, so it does
not have to share a network with it.

**The queue is not polled.** It used to be, every 5 seconds unconditionally —
720 requests an hour per verifier, screen off or not. From one venue IP that was
enough for Cloudflare to answer the whole site with 403, which is what took the
booth down on 2026-08-07. The queue now refreshes when the tab opens, when the
app returns to the foreground, on pull-to-refresh, on the AppBar button, and
after a successful redeem.

That is safe because scanning a QR is the primary path and it always hits the
server right then; the list is only the fallback for a ticket that won't scan.
What it costs is that the list can be arbitrarily stale, so `_FreshnessBar`
states its age and turns amber past two minutes — same rule as
`CashierLeaseBanner`: a state you cannot vouch for must never look like one you
can. `VerifierBloc._onRefreshQueue` bails when the service is disconnected,
because `fetchQueue` answers `[]` rather than throwing and an empty queue reads
as "everyone has been served".

A verifier is a **pure reader**: it creates nothing, so it takes no cashier
lease, runs no `SyncService`, and keeps no local replica. Its history tab reads
`GET /api/pos/history` directly, and the delete button is not rendered there at
all (`TransactionDetailDialog.canDelete`).

There used to be an embedded `alfred` server on the cashier device, reached over
the LAN by IP address, with a WebSocket for push. It is gone — along with the
Windows firewall rule, the Android background isolate, the pairing QR and the
manual IP entry. Redeeming is now the server's call alone, which is also what
makes double-redeem impossible without any coordination between devices.

The **Koneksi** tab that survived that removal is gone too. Once the account was
the pairing, `connect()` was one line — `_connected = true` — so the page was a
button that flipped a local boolean and a "Putuskan Koneksi" that flipped it
back. `ConnectToServer`/`DisconnectFromServer` went with it; `InitializeVerifier`
now does the whole job at startup. The verifier's nav is three tabs: Beranda,
Antrean, Setelan.

### Cloud sync (luminarabali.com)

The Laravel backend holds a copy of every transaction, behind a Sanctum token.
The rule that keeps the two sides from ever disagreeing:

> **The cashier creates, the server redeems.**

`SyncService.push()` therefore never uploads `status`/`redeemed_at` changes — the
server ignores those columns on rows it already has — and `pull()` brings back
**only redemptions**, applied by `TransactionRepository.applyRedemptions` and
guarded by `status = 'PAID'` so it can never overwrite a `redeemed_at` already
printed on a receipt. Break that split and you get double-redeemed tickets.

Transactions themselves never come down. They don't need to: exactly one device
creates them, and that device already has them. That is what the cashier lease
buys — see below.

### Who reads from where

| | Source of truth | Reads from |
|---|---|---|
| Cashier | its own SQLite | SQLite; only redemptions come down |
| Verifier | — (creates nothing) | the server, always |

The verifier keeps **no local replica**. It already needs the internet to scan a
ticket at all, so replicating a database that would then have to be reconciled
buys nothing. `TransactionHistoryView` takes a `HistoryLoader`; the cashier
passes the repository-backed one, the verifier passes `fromServer`
(`GET /api/pos/history?from=&to=`, upper bound exclusive).

### Deletion

Deleting is a creation-side act, so the cashier owns it — but a deleted row
leaves nothing behind to upload. `TransactionRepository.delete` therefore writes
a tombstone to `pending_deletes`, `push()` sends it, and the tombstone is only
dropped once the server acknowledges it. Reverse that order and one failed send
loses the deletion for good.

On the server `pos_transactions.deleted_at` is set rather than the row dropped —
an audit trail for money that was taken and then un-taken. `queue`, `summary`,
`verify`, `history` and the **full** restore all exclude those rows; only the
paged restore carries them, and only there does the response include a
`deleted_at` key. The full restore feeds `applyBackupJson`, which inserts
column-by-column into a SQLite table that has no such column, so one extra key
there fails the whole device-migration restore.

`sync` never clears `deleted_at`, for the same reason it never clears `status`:
a device that hasn't polled yet will happily re-send a row it still holds.

### Products are replaced wholesale, not merged

The catalogue belongs to the cashier, so the list it sends **is** the truth and
the server deletes anything missing from it. `push()` sends `products` even when
empty — `null` means "don't touch the catalogue", `[]` means "the catalogue is
empty". Without that distinction, deleting the last package never reaches the
server, and a replacement device restoring from there gets back every package
ever deleted.

The delete half only runs for a device that **holds the lease**. One that has
lost it may still push transactions (that is money already taken) but its
catalogue may be stale, and letting it delete would let one stray device empty
the account.

### One cashier at a time

Queue numbers are handed out locally, so nothing stops two tills from issuing the
same one — except there only ever being one till. That is enforced by a **lease**
(`pos_cashier_leases`, one row per account), and it is what lets the rest of this
design have no conflicts to resolve: no merge, no duelling queue numbers, no
deletion with an opponent. Verifiers never take a lease; they create nothing, so
there can be any number of them.

`CashierLeaseService` is the state machine. Only `active` and `activeOffline`
answer `canSell`. The heartbeat rides on `POST /pos/sync`, which already runs
every 15s — there is no second timer, and `sync` still **accepts** rows from a
device that has lost the lease, because those rows are money that was already
taken.

The part that cannot be fixed, only made visible: a device that loses internet
keeps selling, and after the 90s TTL another device may claim the role. So the
lease prevents a careless second cashier (spare phone left on in a drawer), not a
partitioned one. `CashierLeaseBanner` exists so `activeOffline` never looks like
`active`.

Claiming returns the day's highest queue number and
`TransactionRepository.raiseQueueCounter` applies it *before* the state goes
active, so a replacement device can't reprint a number already in a customer's
hand.

- `AuthService` owns the token and the offline grace period (`licenseGrace`,
  7 days). Only a **401** logs the device out; a 500 or a dead network falls back
  to the grace window. Locking the till because venue Wi-Fi died is worse than
  the piracy it would prevent.
- `SyncService.push()` is **awaited at checkout, before printing** — a customer
  walks to the booth in seconds and a ticket the server has never seen cannot be
  scanned there. Failure warns, it does not cancel the sale.
- The cashier's 15s `POST /pos/sync` is the one remaining timer, and it stays:
  it carries the lease heartbeat against a 90s TTL. The verifier's 5s queue
  poll is gone — see **Verifier** above for why.
- `/api/pos/restore` answers in the **backup file format**, so device migration
  reuses `BackupService.applyBackupJson` instead of a second restore path.

### Logging

`AppLog.error(...)` / `AppLog.info(...)` write to the `logs` table. Both swallow their own failures — they're called from `catch` blocks, so a logging failure must never mask the original error. Never use `print()`; use `AppLog` or `debugPrint`.

### Money

All Rupiah formatting goes through `Currency.format()` (`lib/core/helpers/currency.dart`). Never construct `NumberFormat.currency` inline. `Currency.parse()` reads user input and returns null rather than throwing.

## Key Constraints (Stability Rules)

1. **No nested MaterialApp** — breaks Navigator history and causes `Scaffold.geometryOf` exceptions.
2. **Theme parity** — `LightTheme` and `DarkTheme` must define identical properties (same `fontFamily`, `fontSize`, borders, hint styles). Missing properties cause `Failed to interpolate TextStyles` crashes on theme switch.
3. **Scroll behavior** — do not add `PointerDeviceKind.mouse` to `dragDevices` in `AppScrollBehavior`; it intercepts button clicks on desktop.
4. **NavigationRail layout** — place it directly in a `Row` with `crossAxisAlignment: CrossAxisAlignment.start`. Do not wrap in `SingleChildScrollView + IntrinsicHeight + Expanded` — circular layout dependency.
5. **Grid layout** — prefer `SliverGridDelegateWithMaxCrossAxisExtent` with a fixed `mainAxisExtent` over `FixedCrossAxisCount + childAspectRatio`, which overflows on wide screens.
6. **`Transaction` shadows sqflite's** — files needing both import sqflite with `hide Transaction`.
7. **Never fade to `Colors.transparent`** — that is black at alpha 0, so the animation passes through grey. Fade to the same colour with alpha 0 instead.

## Platform Gotchas

**`file_picker` has opposite contracts per platform.** This broke backup on Android for a whole release:

| | `bytes` | who writes the file | return value |
|---|---|---|---|
| Windows/Linux | ignored | **you must** | real path |
| Android/iOS | **required, else throws** | the plugin does | display-only path |

Also: Android resolves extension filters through `MimeTypeMap`, which has no `json` entry on many builds — the filter comes back empty and the picker errors or hides the file. Use `FileType.any` on mobile and validate the content instead. See `BackupService`.

**Other platform notes:**
- **Android**: requests `bluetooth` (printer), `location` (BLE scan) and `camera` permissions.
- **Linux/Windows**: FFI SQLite, `desktop_webview_window` for Midtrans.
- Desktop DB lives in the app support dir: `~/.local/share/luminara_photobooth/photobooth.db` (Linux), `%APPDATA%\...\photobooth.db` (Windows).

## Payment Integration

Midtrans payment opens a WebView (native dialog on Android, popup window on desktop via `desktop_webview_window`). `MidtransService` returns typed results: `MidtransSession` for creation, `MidtransStatus` for polling.

`PaymentPoller` (`lib/features/cashier/payment_poller.dart`) polls until the payment resolves **or a 15-minute deadline passes**, and won't stack overlapping requests. Any polling loop added here needs a stop condition — the original had none and kept hitting the network forever after the customer walked away.

`MidtransStatus.unreachable` is distinct from `unknown` on purpose: a network blip must not be read as a verdict.

## Testing

`flutter test` must stay green. Tests live in `test/`.

The database is testable without `path_provider`: set `debugDatabasePath = inMemoryDatabasePath` and call `resetDatabase()` in `setUp`/`tearDown` (see `test/photobooth_test.dart`).

Pure logic should be extracted so it can be tested without pumping a widget — `CashDenominations`, `Cart`, `BackupService.buildBackupJson` / `applyBackupJson` all exist as separate units for this reason. When adding non-trivial logic, put it somewhere a test can reach it.

Tests that pin behaviour someone might "fix" incorrectly (persisted enum strings, `PaymentMethod` keeping unknown values, backup rejecting corrupt files without deleting data) are load-bearing. Don't delete them to make a change pass.

## Conventions

- File names mirror their primary class: `settings_page.dart` → `SettingsPage`. No generic `page.dart`.
- Each feature has a barrel (`features/<name>/<name>.dart`).
- Comments explain **why**, not what — especially where the obvious approach is wrong. Keep the existing Indonesian comments; new ones can be either language.
- Domain models are immutable with `copyWith`. Prefer deriving values (`totalPrice` from items) over storing them, so two fields can't disagree.
