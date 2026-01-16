import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MidtransService {
  // Production URL
  static const String _baseUrl = "https://luminarabali.com/api";

  String get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> createTransaction(int amount) async {
    final url = Uri.parse('$baseUrl/transaction');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create transaction: ${response.body}');
      }
    } catch (e) {
      debugPrint('Midtrans Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkStatus(String orderId) async {
    final url = Uri.parse('$baseUrl/transaction/$orderId');

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['data']['status'], // pending, paid, failed
          'payment_type':
              data['data']['payment_type'], // gopay, qris, bank_transfer
        };
      } else {
        return {'status': 'unknown', 'payment_type': null};
      }
    } catch (e) {
      return {'status': 'error', 'payment_type': null};
    }
  }

  Future<void> syncTransaction(String orderId) async {
    final url = Uri.parse('$baseUrl/transaction/$orderId/sync');
    try {
      await http.post(url);
    } catch (_) {}
  }
}
