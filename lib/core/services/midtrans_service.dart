import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MidtransService {
  // Ganti URL ini sesuai IP komputer Laravel Anda jalankan
  // Android Emulator: 10.0.2.2
  // Real Device (Vivo I2218): Gunakan IP Laptop -> 192.168.2.109:8000
  static const String _baseUrlAndroid = "http://192.168.2.109:8000/api";
  static const String _baseUrlDesktop = "http://127.0.0.1:8000/api";

  String get baseUrl => (Platform.isAndroid || Platform.isIOS) ? _baseUrlAndroid : _baseUrlDesktop;

  Future<Map<String, dynamic>> createTransaction(int amount) async {
    final url = Uri.parse('$baseUrl/transaction');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
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

  Future<String> checkStatus(String orderId) async {
    final url = Uri.parse('$baseUrl/transaction/$orderId');

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['status']; // pending, paid, failed
      } else {
        return 'unknown';
      }
    } catch (e) {
      return 'error';
    }
  }

  Future<void> syncTransaction(String orderId) async {
    final url = Uri.parse('$baseUrl/transaction/$orderId/sync');
    try {
      await http.post(url);
    } catch (_) {}
  }
}