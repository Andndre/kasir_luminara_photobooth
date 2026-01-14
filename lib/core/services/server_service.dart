import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:kasir/core/data/db.dart';

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal();

  Alfred? _alfred;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  
  bool get isRunning => _server != null;

  Future<void> start({int port = 3000}) async {
    if (_alfred != null) return;

    _alfred = Alfred();

    // Middleware for logging or security could go here
    _alfred!.all('*', (req, res) {
      // res.headers.add('Access-Control-Allow-Origin', '*');
    });

    // 1. Cek Status Server
    _alfred!.get('/health', (req, res) => 'OK');

    // 2. Ambil Antrean (Polling/Fetch)
    _alfred!.get('/api/queue', (req, res) async {
      final db = await getDatabase();
      final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: 'status = ?',
        whereArgs: ['PAID'],
        orderBy: 'created_at ASC',
      );
      return maps;
    });

    // 3. Verifikasi Tiket
    _alfred!.post('/api/verify', (req, res) async {
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

      // Update status to COMPLETED
      await db.update(
        'transactions',
        {
          'status': 'COMPLETED',
          'redeemed_at': DateTime.now().toIso8601String(),
        },
        where: 'uuid = ?',
        whereArgs: [ticketCode],
      );

      // Broadcast to all WS clients
      broadcast('TICKET_REDEEMED');

      return {
        'valid': true,
        'data': {
          'id': transaction['uuid'],
          'customer_name': transaction['customer_name'],
          'product_name': transaction['product_name'],
          'status': 'COMPLETED',
        }
      };
    });

    // 4. WebSocket Endpoint
    _alfred!.get('/ws', (req, res) async {
      final socket = await WebSocketTransformer.upgrade(req);
      _clients.add(socket);
      print('Client connected to WS. Total clients: ${_clients.length}');

      socket.listen(
        (data) {
          // Handle incoming messages if needed
        },
        onDone: () {
          _clients.remove(socket);
          print('Client disconnected from WS. Total clients: ${_clients.length}');
        },
      );
    });

    _server = await _alfred!.listen(port);
    print('Server started on port $port');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _alfred = null;
    for (var client in _clients) {
      await client.close();
    }
    _clients.clear();
    print('Server stopped');
  }

  void broadcast(String eventName) {
    final message = jsonEncode({'event': eventName});
    for (var client in _clients) {
      if (client.readyState == WebSocket.open) {
        client.add(message);
      }
    }
  }
}
