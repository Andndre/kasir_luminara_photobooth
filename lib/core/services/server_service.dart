import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:alfred/alfred.dart';
import 'package:luminara_photobooth/core/data/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import for manual DB init in isolate

// Command messages for the isolate
abstract class ServerCommand {}
class StartServerCommand extends ServerCommand {
  final int port;
  final SendPort sendPort;
  StartServerCommand(this.port, this.sendPort);
}
class StopServerCommand extends ServerCommand {}
class BroadcastCommand extends ServerCommand {
  final String event;
  BroadcastCommand(this.event);
}

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal();

  Isolate? _serverIsolate;
  SendPort? _isolateSendPort;
  bool _isRunning = false;
  
  bool get isRunning => _isRunning;

  // This method is called from the Main Isolate (UI)
  Future<void> start({int port = 3000}) async {
    if (_isRunning) return;

    final receivePort = ReceivePort();
    _serverIsolate = await Isolate.spawn(
      _serverIsolateEntryPoint,
      StartServerCommand(port, receivePort.sendPort),
    );

    // Wait for the isolate to send back its SendPort
    _isolateSendPort = await receivePort.first as SendPort;
    _isRunning = true;
    print('Server Isolate Started');
  }

  // This method is called from the Main Isolate (UI)
  Future<void> stop() async {
    if (_isolateSendPort != null) {
      _isolateSendPort!.send(StopServerCommand());
    }
    _serverIsolate?.kill(priority: Isolate.immediate);
    _serverIsolate = null;
    _isolateSendPort = null;
    _isRunning = false;
    print('Server Isolate Stopped');
  }

  // This method is called from the Main Isolate (UI)
  void broadcast(String eventName) {
    _isolateSendPort?.send(BroadcastCommand(eventName));
  }

  // --- ISOLATE ENTRY POINT (Runs in background thread) ---
  static void _serverIsolateEntryPoint(StartServerCommand command) async {
    // 1. Initialize SQLite for this isolate (Crucial for FFI on Linux/Windows)
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 2. Setup internal communication port
    final internalReceivePort = ReceivePort();
    command.sendPort.send(internalReceivePort.sendPort); // Send port back to main

    // 3. Start Alfred Server
    final alfred = Alfred();
    final List<WebSocket> clients = [];
    HttpServer? server;

    alfred.all('*', (req, res) {}); // CORS or logging

    // API: Health
    alfred.get('/health', (req, res) => 'OK');

    // API: Queue
    alfred.get('/api/queue', (req, res) async {
      try {
        final db = await getDatabase();
        final List<Map<String, dynamic>> maps = await db.query(
          'transactions',
          where: 'status = ?',
          whereArgs: ['PAID'],
          orderBy: 'created_at ASC',
        );
        // Important: Close DB connection in isolate after use or keep open efficiently?
        // Usually sqflite manages pool, but in isolate be careful.
        return maps;
      } catch (e) {
        print('Isolate DB Error: $e');
        return [];
      }
    });

    // API: Verify
    alfred.post('/api/verify', (req, res) async {
      try {
        final body = await req.body as Map<String, dynamic>;
        final ticketCode = body['ticket_code'];

        if (ticketCode == null) {
          res.statusCode = 400;
          return {'valid': false, 'message': 'Ticket code is required'};
        }

        final db = await getDatabase();
        final List<Map<String, dynamic>> result = await db.query(
          'transactions',
          where: 'uuid = ?',
          whereArgs: [ticketCode],
        );

        if (result.isEmpty) {
          res.statusCode = 404;
          return {'valid': false, 'message': 'Tiket tidak ditemukan'};
        }

        final transaction = result.first;
        if (transaction['status'] != 'PAID') {
          res.statusCode = 400;
          return {'valid': false, 'message': 'Tiket sudah dipakai'};
        }

        await db.update(
          'transactions',
          {
            'status': 'COMPLETED',
            'redeemed_at': DateTime.now().toIso8601String(),
          },
          where: 'uuid = ?',
          whereArgs: [ticketCode],
        );

        // Broadcast locally in isolate
        final message = jsonEncode({'event': 'TICKET_REDEEMED'});
        for (var client in clients) {
          if (client.readyState == WebSocket.open) client.add(message);
        }

        return {
          'valid': true,
          'data': {
            'id': transaction['uuid'],
            'customer_name': transaction['customer_name'],
            'product_name': transaction['product_name'],
            'status': 'COMPLETED',
          }
        };
      } catch (e) {
        res.statusCode = 500;
        return {'valid': false, 'message': 'Server Error: $e'};
      }
    });

    // API: WebSocket
    alfred.get('/ws', (req, res) async {
      final socket = await WebSocketTransformer.upgrade(req);
      clients.add(socket);
      socket.listen((_) {}, onDone: () => clients.remove(socket));
    });

    try {
      server = await alfred.listen(command.port, '0.0.0.0');
      print('Isolate Server listening on 0.0.0.0:${command.port}');
    } catch (e) {
      print('Failed to start server in isolate: $e');
    }

    // 4. Listen for commands from Main Isolate
    await for (final msg in internalReceivePort) {
      if (msg is StopServerCommand) {
        await server?.close(force: true);
        for (var client in clients) {
          await client.close();
        }
        Isolate.current.kill();
      } else if (msg is BroadcastCommand) {
        final message = jsonEncode({'event': msg.event});
        for (var client in clients) {
          if (client.readyState == WebSocket.open) {
            client.add(message);
          }
        }
      }
    }
  }
}