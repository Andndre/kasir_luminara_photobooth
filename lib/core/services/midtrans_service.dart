import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:luminara_photobooth/core/helpers/app_log.dart';

/// A payment session created on the backend: where to send the customer, and
/// the id to poll for its outcome.
class MidtransSession {
  final String redirectUrl;
  final String orderId;

  const MidtransSession({required this.redirectUrl, required this.orderId});
}

/// Where a payment stands. `unknown` and `error` used to be indistinguishable
/// strings inside a `Map`, so a network blip looked the same as "still
/// pending" and the poller quietly kept going forever.
enum MidtransStatus {
  pending,
  paid,
  failed,
  expired,

  /// Backend answered, but with a status this app doesn't know.
  unknown,

  /// Could not reach the backend at all. Distinct from [unknown] so the poller
  /// can keep retrying instead of treating it as a verdict.
  unreachable;

  static MidtransStatus parse(String? value) => switch (value) {
    'paid' || 'settlement' || 'capture' => paid,
    'pending' => pending,
    'failed' || 'deny' || 'cancel' => failed,
    'expire' || 'expired' => expired,
    _ => unknown,
  };

  bool get isTerminal =>
      this == paid || this == failed || this == expired;
}

class MidtransPaymentStatus {
  final MidtransStatus status;

  /// Raw Midtrans channel (`qris`, `gopay`, `bca_va`, …), null until paid.
  final String? paymentType;

  const MidtransPaymentStatus(this.status, [this.paymentType]);
}

class MidtransService {
  // Production URL
  static const String _baseUrl = 'https://luminarabali.com/api';
  static const _timeout = Duration(seconds: 15);

  String get baseUrl => _baseUrl;

  /// Throws on failure — the caller is mid-checkout and must show an error.
  Future<MidtransSession> createTransaction(
    int amount,
    String? customerName,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transaction'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'amount': amount, 'customer_name': customerName}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to create transaction: ${response.body}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final redirectUrl = body['redirect_url'] as String?;
      final orderId = body['order_id'] as String?;

      if (redirectUrl == null || orderId == null) {
        throw Exception('Respons Midtrans tidak lengkap: ${response.body}');
      }

      return MidtransSession(redirectUrl: redirectUrl, orderId: orderId);
    } catch (e) {
      AppLog.error('Midtrans Error: $e');
      rethrow;
    }
  }

  /// Never throws: this runs on a polling timer, where an exception would kill
  /// the loop. Failures come back as [MidtransStatus.unreachable].
  Future<MidtransPaymentStatus> checkStatus(String orderId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/transaction/$orderId'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return const MidtransPaymentStatus(MidtransStatus.unreachable);
      }

      final data =
          (jsonDecode(response.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;

      return MidtransPaymentStatus(
        MidtransStatus.parse(data['status'] as String?),
        data['payment_type'] as String?,
      );
    } catch (e) {
      AppLog.error('Midtrans Error: $e');
      return const MidtransPaymentStatus(MidtransStatus.unreachable);
    }
  }

  /// Asks the backend to re-check with Midtrans. Needed because the webhook
  /// does not reach us on a local network.
  ///
  /// Returns false if the sync itself failed — the caller can still poll, but
  /// now knows the status it reads may be stale.
  Future<bool> syncTransaction(String orderId) async {
    try {
      await http
          .post(Uri.parse('$baseUrl/transaction/$orderId/sync'))
          .timeout(_timeout);
      return true;
    } catch (e) {
      AppLog.error('Midtrans Sync Error for orderId $orderId: $e');
      return false;
    }
  }
}
