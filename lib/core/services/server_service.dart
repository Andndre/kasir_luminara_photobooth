import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:luminara_photobooth/core/data/db.dart';

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal();

  Alfred? _alfred;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  
  final _clientCountController = StreamController<int>.broadcast();
  Stream<int> get clientCountStream => _clientCountController.stream;
  int get clientCount => _clients.length;
  
  bool get isRunning => _server != null;

  Future<void> start({int port = 3000}) async {
    if (_server != null) return;

    _alfred = Alfred();

    // Health Check
    _alfred!.get('/health', (req, res) => 'OK');

    // API: Get Queue
    _alfred!.get('/api/queue', (req, res) async {
      try {
        final db = await getDatabase();
        return await db.query(
          'transactions',
          where: 'status = ?',
          whereArgs: ['PAID'],
          orderBy: 'created_at ASC',
        );
      } catch (e) {
        return [];
      }
    });

    // API: Verify Ticket
    _alfred!.post('/api/verify', (req, res) async {
      final body = await req.body as Map<String, dynamic>;
      final ticketCode = body['ticket_code'];

      if (ticketCode == null) {
        res.statusCode = 400;
        return {'valid': false, 'message': 'Ticket code is required'};
      }

      final db = await getDatabase();
      final result = await db.query('transactions', where: 'uuid = ?', whereArgs: [ticketCode]);

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
        {'status': 'COMPLETED', 'redeemed_at': DateTime.now().toIso8601String()},
        where: 'uuid = ?',
        whereArgs: [ticketCode],
      );

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

    // WebSocket
    _alfred!.get('/ws', (req, res) async {
      final socket = await WebSocketTransformer.upgrade(req);
      _clients.add(socket);
      _clientCountController.add(_clients.length);
      
      socket.listen(
        (_) {}, 
        onDone: () {
          _clients.remove(socket);
          _clientCountController.add(_clients.length);
        },
        onError: (_) {
          _clients.remove(socket);
          _clientCountController.add(_clients.length);
        }
      );
    });

    _server = await _alfred!.listen(port, '0.0.0.0');
    print('Server started on 0.0.0.0:$port');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _alfred = null;
    for (var client in _clients) {
      await client.close();
    }
    _clients.clear();
    _clientCountController.add(0);
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
