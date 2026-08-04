import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Outcome of `POST /api/verify`, as seen by the verifier client.
///
/// The server answers `{valid: bool, ...}`; modelling that as two types means
/// the UI cannot read ticket details off a rejected response by mistake.
sealed class VerifyResult {
  const VerifyResult();
}

final class TicketAccepted extends VerifyResult {
  final String customerName;
  final List<QueueTicketItem> items;

  /// One-line fallback used when [items] is empty.
  final String summary;

  const TicketAccepted({
    required this.customerName,
    required this.items,
    required this.summary,
  });
}

final class TicketRejected extends VerifyResult {
  final String message;
  const TicketRejected(this.message);
}

/// Client half of the local-network link: talks to the cashier's embedded
/// server over HTTP and listens for push events over a WebSocket.
class VerifierService {
  static final VerifierService _instance = VerifierService._internal();
  factory VerifierService() => _instance;
  VerifierService._internal();

  /// Without this, a dropped Wi-Fi link left requests hanging until the OS
  /// gave up — the queue screen would just spin.
  static const _timeout = Duration(seconds: 10);

  String? _baseUrl;
  WebSocketChannel? _channel;

  bool get isConnected => _baseUrl != null;

  void connect(String ip, int port) {
    _baseUrl = 'http://$ip:$port';
    _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port/ws'));
  }

  Stream<dynamic>? get eventStream => _channel?.stream;

  /// Throws [ServerUnreachable] on network failure, so the bloc surfaces a real
  /// error instead of silently rendering an empty queue.
  Future<List<QueueTicket>> fetchQueue() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) return const [];

    final response = await _get('$baseUrl/api/queue');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((e) => QueueTicket.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<VerifyResult> verifyTicket(String ticketCode) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return const TicketRejected('Belum terhubung ke server');
    }

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/api/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ticket_code': ticketCode}),
          )
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw ServerUnreachable(e.message);
    }

    // A rejection is a normal outcome and arrives with a 4xx status, so the
    // body is parsed either way.
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['valid'] != true) {
      return TicketRejected(body['message'] as String? ?? 'Verifikasi gagal');
    }

    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TicketAccepted(
      customerName: data['customer_name'] as String? ?? 'Pelanggan',
      summary: data['product_name'] as String? ?? '-',
      items: ((data['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((i) => QueueTicketItem.fromJson(i.cast<String, dynamic>()))
          .toList(),
    );
  }

  Future<http.Response> _get(String url) async {
    final http.Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(_timeout);
    } on SocketException catch (e) {
      throw ServerUnreachable(e.message);
    }

    if (response.statusCode != 200) {
      throw ServerUnreachable('Server menjawab ${response.statusCode}');
    }
    return response;
  }

  void disconnect() {
    _channel?.sink.close();
    _baseUrl = null;
    _channel = null;
  }
}

class ServerUnreachable implements Exception {
  final String message;
  const ServerUnreachable(this.message);

  @override
  String toString() => 'Server tidak dapat dihubungi: $message';
}
