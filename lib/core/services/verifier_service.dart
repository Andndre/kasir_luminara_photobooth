import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';

/// Outcome of `POST /api/pos/verify`, as seen by the verifier client.
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

/// Reads the queue and redeems tickets through luminarabali.com.
///
/// The account is what pairs this scanner with the till — it replaces the LAN
/// address the operator used to type in, and with it the embedded HTTP server,
/// the WebSocket, the firewall rule and the Android background isolate.
class VerifierService {
  static final VerifierService _instance = VerifierService._internal();
  factory VerifierService() => _instance;
  VerifierService._internal();

  /// Without this, a dropped link left requests hanging until the OS gave up —
  /// the queue screen would just spin.
  static const _timeout = Duration(seconds: 10);

  /// How often the queue is refreshed. There is no push channel over the
  /// internet, so this interval *is* the latency a customer sees between
  /// paying and appearing on the booth's screen.
  static const pollInterval = Duration(seconds: 5);

  bool _connected = false;
  Stream<dynamic>? _pollStream;

  bool get isConnected => _connected;

  void connect() {
    _connected = true;

    _pollStream = Stream.periodic(
      pollInterval,
      (_) => jsonEncode({'event': 'REFRESH_QUEUE'}),
    ).asBroadcastStream();
  }

  Stream<dynamic>? get eventStream => _pollStream;

  /// Throws [ServerUnreachable] on network failure, so the bloc surfaces a real
  /// error instead of silently rendering an empty queue.
  Future<List<QueueTicket>> fetchQueue() async {
    if (!_connected) return const [];

    final response = await _get('$cloudBaseUrl/pos/queue');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((e) => QueueTicket.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<VerifyResult> verifyTicket(String ticketCode) async {
    if (!_connected) return const TicketRejected('Belum terhubung ke server');

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$cloudBaseUrl/pos/verify'),
            headers: AuthService().headers,
            body: jsonEncode({'ticket_code': ticketCode}),
          )
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw ServerUnreachable(e.message);
    } on TimeoutException {
      throw const ServerUnreachable('Waktu tunggu habis');
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
      response = await http
          .get(Uri.parse(url), headers: AuthService().headers)
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw ServerUnreachable(e.message);
    } on TimeoutException {
      throw const ServerUnreachable('Waktu tunggu habis');
    }

    if (response.statusCode != 200) {
      throw ServerUnreachable('Server menjawab ${response.statusCode}');
    }
    return response;
  }

  void disconnect() {
    _connected = false;
    _pollStream = null;
  }
}

class ServerUnreachable implements Exception {
  final String message;
  const ServerUnreachable(this.message);

  @override
  String toString() => 'Server tidak dapat dihubungi: $message';
}
