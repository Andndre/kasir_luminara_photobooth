# GEMINI.md - Developer Context & Instructions

## 1. Project Overview

**Project Name:** Photobooth Management System (Luminara)
**Original Base:** Kasir Mimba Bali
**Type:** Flutter Application (Dual Mode: Server/Desktop & Client/Mobile)
**Description:** A Local Network (LAN) based management system for a Photobooth business. It orchestrates the flow between the Cashier (Server) and the Entrance/Verification (Client) nodes without internet dependency (Offline First).

## 2. Architecture & Toplogy

The system operates on a **Single Codebase** architecture with role-based behavior.

### **Roles**
1.  **Server Node (Laptop/Windows):**
    *   **Function:** Cashier Station, Central Server.
    *   **Responsibilities:**
        *   Host HTTP Server (REST API) on port 3000.
        *   Host WebSocket Server (`/ws`) for real-time signaling.
        *   Manage Central Database (SQLite).
        *   Print Receipts (Thermal Printer).
        *   Display Pairing QR for Clients.
2.  **Client Node (Android/Mobile):**
    *   **Function:** Ticket Verifier / Queue Display.
    *   **Responsibilities:**
        *   Connect to Server via P2P/LAN (Scan Pairing QR).
        *   Listen to WebSocket for Queue Updates.
        *   Scan User Tickets (QR Code).
        *   Verify Tickets via REST API.

### **Communication Protocol**
*   **REST HTTP:** For data fetching (Polling queues, verifying tickets).
*   **WebSocket:** For lightweight signals (Triggers: `REFRESH_QUEUE`, `TICKET_REDEEMED`).

## 3. Data Model (SQLite)

**Table: `products`**
*   `id` (PK, Auto Increment)
*   `name` (Text)
*   `price` (Integer)

**Table: `transactions`**
*   `uuid` (PK, Text) - QR Code Content
*   `customer_name` (Text)
*   `product_name` (Text)
*   `product_price` (Integer)
*   `status` (Text) - 'PAID', 'COMPLETED', 'CANCELLED'
*   `created_at` (DateTime)
*   `redeemed_at` (DateTime, Nullable)

## 4. Key Dependencies & Packages

*   **Core:** `flutter`, `flutter_bloc` (State Management).
*   **Networking:**
    *   `alfred` (or similar) for Embedded HTTP/WS Server.
    *   `http` / `dio` for REST Client.
    *   `web_socket_channel` for WebSocket Client.
*   **Database:**
    *   `sqflite` (Android).
    *   `sqflite_common_ffi` (Windows/Linux Support).
*   **Hardware:**
    *   `mobile_scanner` (QR Scanning).
    *   `print_bluetooth_thermal` or `esc_pos_utils` (Printing).
    *   `network_info_plus` (To retrieve local IP).

## 5. Development Conventions

*   **Feature-First Structure:** Keep the existing modular structure (`lib/features/`).
*   **Platform-Aware:** Use `Platform.isWindows` or `Platform.isAndroid` to toggle Server/Client logic.
*   **Offline-First:** All logic must assume no internet connection.
*   **Security:** Simple Authorization Header for Client-Server handshake.

## 6. Implementation Plan (Roadmap)

We will execute this plan step-by-step.

### Phase 1: Foundation & Architecture
- [x] **Step 1.1: Platform-Agnostic Entry Point**
  - Update `lib/main.dart` to include a Role Selection Screen (Server vs Client).
  - Allow dynamic switching or persistent configuration (SharedPrefs) for AppMode.
  - Establish `AppMode` enum (SERVER, CLIENT).
- [x] **Step 1.2: Unified Database Layer**
  - Refactor `lib/core/data/db.dart` to support `sqflite_common_ffi` for Windows.
  - Create the `products` and `transactions` tables per SKPL.

### Phase 2: Server Node (Windows)
- [x] **Step 2.1: Server Service (Alfred)**
  - Implement `ServerService` class.
  - Setup HTTP endpoints (`GET /health`, `GET /api/queue`, `POST /api/verify`).
  - Setup WebSocket endpoint (`/ws`).
- [x] **Step 2.2: Server State Management**
  - Create `ServerBloc` to manage Server Status (Online/Offline), Local IP, and WebSocket connections.
  - Display a "Server Monitor" on the Windows Desktop Dashboard.
- [x] **Step 2.3: Cashier Logic Adaptation**
  - Modify `Transaction` flow to generate UUIDs.
  - Implement "Print Ticket" flow (Ticket QR shown in UI).
  - Show "Pairing QR" (IP + Port) for Mobile Clients.

### Phase 3: Client Node (Android/Verifier)
- [x] **Step 3.1: Client State Management**
  - Create `VerifierBloc` for managing connection state (Disconnected, Connected).
- [x] **Step 3.2: Handshake UI**
  - Create a "Scan Server QR" screen.
  - Implement logic to connect via REST/WebSocket.
- [x] **Step 3.3: Queue & Verification UI**
  - Create `LiveQueuePage` to listen for WebSocket `REFRESH_QUEUE` events.
  - Create `TicketScannerPage` to scan Customer QR and call `POST /api/verify`.

### Phase 4: Integration & Polish
- [ ] **Step 4.1: End-to-End Testing**
  - Verify flow: Create Transaction (Windows) -> Broadcast -> Update Android UI.
  - Verify flow: Scan Ticket (Android) -> Verify API -> Update DB -> Broadcast.
- [ ] **Step 4.2: UI Cleanup**
  - Remove unused features from original POS (if any).
  - Ensure Windows UI is desktop-friendly and Android UI is mobile-friendly.