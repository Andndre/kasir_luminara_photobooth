# GEMINI.md - Luminara Photobooth Development Master Guide

## 1. Project Overview
**Project Name:** Luminara Photobooth  
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

### **Critical Stability Constraints (Lessons Learned)**

#### **1. Architecture & Navigation**
*   **Single MaterialApp Rule:** Never use nested `MaterialApp` widgets. It breaks the `Navigator` history and causes `Scaffold.geometryOf` exceptions.
*   **Global Provider Placement:** Use `ChangeNotifierProvider` (for `AppState`) at the absolute root. Use `MaterialApp.builder` or wrap the `home` widget to inject `Bloc` providers so they are accessible to all dynamically pushed routes.
*   **AppMode Toggle:** Switching modes should update the global `AppState`. The UI reacts by switching the `home` widget of the `MaterialApp`, preserving the core engine state.

#### **2. Linux Desktop Compatibility**
*   **Isolate vs FFI Deadlock:** Avoid running `sqflite_common_ffi` in a background `Isolate` while also using it in the main thread on Linux. This causes GTK window deadlocks (unresponsive UI). Keep the `ServerService` in the **Main Isolate**; Dart's non-blocking I/O is sufficient for `Alfred`.
*   **UI Responsiveness:** If the UI becomes unclickable, check for:
    *   **Gesture Conflicts:** Do not add `PointerDeviceKind.mouse` to `dragDevices` in `ScrollBehavior` as it can intercept button clicks.
    *   **Transparent Backgrounds:** Avoid `Colors.transparent` for `Scaffold.backgroundColor`. Use solid colors to ensure the Window Manager correctly registers hit-tests.
*   **Manual Server Startup:** On Desktop, avoid automatic server startup in `initState`. Provide a manual "Start Server" button to ensure the UI engine is fully "settled" before opening network ports.

#### **3. Network & Connectivity**
*   **Binding:** The server must bind to `0.0.0.0` to be accessible across the LAN.
*   **Firewall:** Ensure port `3000` is open (e.g., `sudo ufw allow 3000/tcp`).
*   **Self-Ping Debugging:** If connectivity fails, use a "Self-Ping" test (reaching the LAN IP from the server itself) to diagnose firewall blocks.

### **Best Practices Before Commit/Build**
1.  **Run Analysis:** `flutter analyze`. Fix all issues.
2.  **Test Models:** `flutter test` to ensure database schema changes don't break logic.
3.  **Clean Build:** `flutter clean && flutter build apk --release` for final delivery.

## 6. Deployment
*   **Build Android:** `flutter build apk --release` (outputs to `build/app/outputs/flutter-apk/`).
*   **Package Name:** `com.andndredev.luminaraphotobooth`.
*   **Icons:** Managed via `flutter_launcher_icons` (source: `assets/images/logo.png`).
