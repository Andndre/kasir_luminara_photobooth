# GEMINI.md - Luminara Photobooth Development Master Guide

## 1. Project Overview
**Project Name:** Luminara Photobooth  
**Legacy Base:** Kasir Mimba Bali (Fully Transformed)  
**Architecture:** Dual-Mode (Server/Cashier & Client/Verifier)  
**Primary Goal:** Local Network (LAN) based management for Photobooth businesses, operating entirely offline.

## 2. System Architecture & Roles

### **Dual-Mode Workflow**
The application uses a **Global State Management** pattern to toggle between two roles at runtime without restarting the process.

1.  **Server Mode (Cashier):**
    *   **Dashboard:** Displays local IP and Pairing QR.
    *   **Embedded Server:** Launches a **Background Isolate** running an `Alfred` HTTP & WebSocket server.
    *   **Database:** Master SQLite storage (`photobooth.db`).
    *   **Features:** Create transactions, print thermal tickets with QR codes.
2.  **Client Mode (Verifier):**
    *   **Pairing:** Scans Server's Pairing QR to retrieve IP/Port.
    *   **Live Queue:** Real-time list of paid customers (via WebSocket signals).
    *   **Verification:** Scans customer ticket QR and validates via REST API.

## 3. Technology Stack & Key Patterns

### **Core Frameworks**
*   **Flutter (3.9.2+):** Desktop (Linux/Windows) and Mobile (Android).
*   **State Management:**
    *   `AppState` (Provider/ChangeNotifier): Global mode control.
    *   `Bloc` (flutter_bloc): Feature-level business logic.
*   **Database:** `sqflite` (Android) & `sqflite_common_ffi` (Linux/Windows).

### **Critical Patterns**
*   **Isolate-Based Server:** The `ServerService` runs entirely in a background `Isolate`. This prevents the HTTP/WebSocket event loop from blocking the Flutter UI thread (essential for Linux Desktop stability).
*   **Single MaterialApp:** The app maintains a single `MaterialApp` instance. Mode changes trigger a root rebuild using a `ValueKey(mode)`.
*   **Offline-First:** No external APIs are used. All communication is P2P within the LAN.

## 4. Code Structure (Master Map)
*   `lib/app/`: Navigation (`routes.dart`) and Root Widget (`app.dart`).
*   `lib/core/`:
    *   `services/`: `ServerService` (Background Isolate) and `VerifierService`.
    *   `data/`: Database schema and connection.
    *   `preferences/`: Global UI themes, constants, and `AppState`.
*   `lib/features/`:
    *   `mode_selection/`: First screen shown to the user.
    *   `server/`: Server-specific UI and logic.
    *   `verifier/`: Client-specific UI and real-time queue.
    *   `kasir/`: Transaction processing UI.
*   `lib/model/`: Simplified schema (`produk.dart`, `transaksi.dart`).

## 5. Development Best Practices

### **Before Commit / Build**
1.  **Static Analysis:** Always run `flutter analyze`. Fix all errors and warnings. The project should have 0 issues (excluding minor platform-specific hints).
2.  **Test Execution:** Run `flutter test`. Ensure `test/photobooth_test.dart` passes.
3.  **No Nested MaterialApps:** Never create a `MaterialApp` inside another. Use the global `AppState` to switch home screens.
4.  **Isolate Hygiene:** Any logic that runs a continuous loop (like a Server) **must** be in an Isolate.
5.  **Platform Awareness:** Wrap mobile-only code (Permissions, Bluetooth) in `if (Platform.isAndroid || Platform.isIOS)`.

### **Handling Crashes**
*   **Global Error Catcher:** `lib/main.dart` contains `_setupErrorHandling()` which overrides `ErrorWidget.builder`. 
*   **Black Screen Policy:** If a black screen occurs, check for unhandled exceptions in `build` methods or malformed JSON parsing in services.

## 6. Deployment
*   **Build Android:** `flutter build apk --release` (outputs to `build/app/outputs/flutter-apk/`).
*   **Package Name:** `com.andndredev.luminaraphotobooth`.
*   **Icons:** Managed via `flutter_launcher_icons` (source: `assets/images/logo.png`).
