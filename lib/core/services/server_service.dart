import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:luminara_photobooth/core/data/db.dart';

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal() {
    _initCommunication();
  }

  static bool _isBackgroundIsolate = false;
  static void setBackgroundMode() => _isBackgroundIsolate = true;

  Alfred? _alfred;
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  
  final _clientCountController = StreamController<int>.broadcast();
  Stream<int> get clientCountStream => _clientCountController.stream;
  int get clientCount => _clients.length;

  // Internal App Events
  final _appEventController = StreamController<String>.broadcast();
  Stream<String> get appEventStream => _appEventController.stream;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;
  
  bool get isRunning => _server != null;
  bool _isServiceRunning = false;
  bool get isServiceRunning => _isServiceRunning;

  void _initCommunication() {
    // Only listen to background service events if we are in the UI isolate
    if (Platform.isAndroid && !_isBackgroundIsolate) {
      FlutterBackgroundService().on('serverStatus').listen((event) {
        _isServiceRunning = event?['running'] ?? false;
        _statusController.add(_isServiceRunning);
      });

      FlutterBackgroundService().on('clientCount').listen((event) {
        _clientCountController.add(event?['count'] ?? 0);
      });

      FlutterBackgroundService().on('appEvent').listen((event) {
        _appEventController.add(event?['event'] ?? '');
      });
    }
  }

  Future<void> start({int port = 3000, bool isBackground = false}) async {
    if (_server != null) return;

    // In background isolate, we must mark it
    if (isBackground) _isBackgroundIsolate = true;

    // On Android, if we are in the UI isolate, we start the background service
    if (Platform.isAndroid && !isBackground) {
      final service = FlutterBackgroundService();
      final isServiceRunning = await service.isRunning();
      if (!isServiceRunning) {
        await service.startService();
      }
      service.invoke('startServer', {'port': port});
      return;
    }

    _alfred = Alfred();

    // Health Check
    _alfred!.get('/health', (req, res) => 'OK');

    // API: Get Queue
    _alfred!.get('/api/queue', (req, res) async {
      try {
        final db = await getDatabase();
        final List<Map<String, dynamic>> transactions = await db.query(
          'transactions',
          where: 'status = ?',
          whereArgs: ['PAID'],
          orderBy: 'created_at ASC',
        );

        List<Map<String, dynamic>> results = [];
        for (var t in transactions) {
          final items = await db.query(
            'transaction_items',
            where: 'transaction_uuid = ?',
            whereArgs: [t['uuid']],
          );
          
          final Map<String, dynamic> transactionWithItems = Map.from(t);
          transactionWithItems['items'] = items;
          
          // Legacy support: for verifier screens that still expect a single product_name
          if (items.isNotEmpty) {
            transactionWithItems['product_name'] = items.map((e) => "${e['product_name']} (x${e['quantity']})").join(", ");
          } else {
            transactionWithItems['product_name'] = "-";
          }
          
          results.add(transactionWithItems);
        }
        return results;
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

      // Get items for the response
      final items = await db.query(
        'transaction_items',
        where: 'transaction_uuid = ?',
        whereArgs: [ticketCode],
      );

      await db.update(
        'transactions',
        {'status': 'COMPLETED', 'redeemed_at': DateTime.now().toIso8601String()},
        where: 'uuid = ?',
        whereArgs: [ticketCode],
      );

      broadcast('TICKET_REDEEMED');
      _appEventController.add('REFRESH_TRANSACTIONS');

      final productName = items.isNotEmpty 
        ? items.map((e) => "${e['product_name']} (x${e['quantity']})").join(", ")
        : "-";

      return {
        'valid': true,
        'data': {
          'id': transaction['uuid'],
          'customer_name': transaction['customer_name'],
          'product_name': productName,
          'items': items,
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
    if (Platform.isAndroid && !isRunning) {
      FlutterBackgroundService().invoke('stopServer');
      return;
    }

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

