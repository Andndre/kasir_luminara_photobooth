import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:luminara_photobooth/core/data/repositories/transaction_repository.dart';
import 'package:luminara_photobooth/core/data/result.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/core/helpers/app_log.dart';

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal() {
    _initCommunication();
  }

  static bool _isBackgroundIsolate = false;
  static void setBackgroundMode() => _isBackgroundIsolate = true;

  static const _transactions = TransactionRepository();

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

    // API: Get Queue — unredeemed tickets in call order.
    _alfred!.get('/api/queue', (req, res) async {
      final result = await _transactions.pendingQueue();
      return result.fold(
        ok: (queue) =>
            queue.map((t) => QueueTicket.fromTransaction(t).toJson()).toList(),
        err: (message, _) {
          AppLog.error('Error fetching queue: $message');
          // 500, not an empty 200 — otherwise the verifier renders "antrian
          // kosong" when the database is actually broken.
          res.statusCode = 500;
          return const [];
        },
      );
    });

    // API: Verify Ticket — redeems it and tells every client to refresh.
    _alfred!.post('/api/verify', (req, res) async {
      final body = await req.body as Map<String, dynamic>?;
      final ticketCode = body?['ticket_code'] as String?;

      if (ticketCode == null || ticketCode.isEmpty) {
        res.statusCode = 400;
        return {'valid': false, 'message': 'Ticket code is required'};
      }

      switch (await _transactions.redeem(ticketCode)) {
        case Err(:final message):
          AppLog.error('Verify failed: $message');
          res.statusCode = 500;
          return {'valid': false, 'message': 'Gagal memverifikasi tiket'};

        case Ok(value: TicketNotFound()):
          res.statusCode = 404;
          return {'valid': false, 'message': 'Tiket tidak ditemukan'};

        case Ok(value: TicketAlreadyUsed()):
          res.statusCode = 400;
          return {'valid': false, 'message': 'Tiket sudah dipakai'};

        case Ok(value: RedeemedOk(:final transaction)):
          broadcast('TICKET_REDEEMED');
          _appEventController.add('REFRESH_TRANSACTIONS');

          final ticket = QueueTicket.fromTransaction(transaction);
          return {
            'valid': true,
            'data': {
              // `id` rather than `uuid` here — existing verifier builds read
              // this key, so it stays.
              'id': ticket.uuid,
              'customer_name': transaction.customerName,
              'product_name': ticket.summary,
              'items': ticket.items.map((i) => i.toJson()).toList(),
              'status': transaction.status.dbValue,
            },
          };
      }
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
        },
      );
    });

    _server = await _alfred!.listen(port, '0.0.0.0');
    debugPrint('Server started on 0.0.0.0:$port');
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
    debugPrint('Server stopped');
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
