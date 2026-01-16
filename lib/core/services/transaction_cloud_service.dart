import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/model/transaksi.dart';
import 'package:flutter/foundation.dart';

class TransactionCloudService {
  static const String _baseUrl = "https://luminarabali.com/api";

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<bool> saveTransaction(Transaksi transaction) async {
    final url = Uri.parse('$_baseUrl/pos/transactions');
    
    try {
      final body = jsonEncode({
        'uuid': transaction.uuid,
        'customer_name': transaction.customerName,
        'total_price': transaction.totalPrice,
        'bayar_amount': transaction.bayarAmount,
        'kembalian': transaction.kembalian,
        'payment_method': transaction.paymentMethod,
        'midtrans_order_id': transaction.midtransOrderId,
        'items': transaction.items.map((item) => {
          'product_name': item.productName,
          'product_price': item.productPrice,
          'quantity': item.quantity,
        }).toList(),
      });

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: body,
      );

      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Cloud Save Error: $e');
      return false;
    }
  }

  Future<List<Transaksi>> getAllTransactions() async {
    final url = Uri.parse('$_baseUrl/pos/transactions');
    
    try {
      final response = await http.get(
        url,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> list = data['data'];
        
        return list.map((json) {
          // Parse Items
          final List<dynamic> itemsJson = json['items'] ?? [];
          final items = itemsJson.map((i) => TransaksiItem(
            productName: i['product_name'],
            productPrice: (i['product_price'] as num).toInt(),
            quantity: i['quantity'],
          )).toList();

          return Transaksi(
            uuid: json['uuid'],
            customerName: json['customer_name'],
            items: items,
            totalPrice: (json['total_price'] as num).toInt(),
            bayarAmount: (json['bayar_amount'] as num).toInt(),
            kembalian: (json['kembalian'] as num).toInt(),
            paymentMethod: json['payment_method'],
            createdAt: DateTime.parse(json['created_at']),
            midtransOrderId: json['midtrans_order_id'],
            status: json['status'],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Cloud Fetch Error: $e');
      return [];
    }
  }
}
