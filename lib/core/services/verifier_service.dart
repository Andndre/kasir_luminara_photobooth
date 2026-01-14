import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class VerifierService {
  static final VerifierService _instance = VerifierService._internal();
  factory VerifierService() => _instance;
  VerifierService._internal();

  String? _baseUrl;
  WebSocketChannel? _channel;
  
  bool get isConnected => _baseUrl != null;

  void connect(String ip, int port) {
    _baseUrl = 'http://$ip:$port';
    _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:$port/ws'));
  }

  Stream<dynamic>? get eventStream => _channel?.stream;

  Future<List<Map<String, dynamic>>> getQueue() async {
    if (_baseUrl == null) return [];
    
    final response = await http.get(Uri.parse('$_baseUrl/api/queue'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> verifyTicket(String ticketCode) async {
    if (_baseUrl == null) return {'valid': false, 'message': 'Not connected to server'};
    
    final response = await http.post(
      Uri.parse('$_baseUrl/api/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ticket_code': ticketCode}),
    );
    
    return jsonDecode(response.body);
  }

  void disconnect() {
    _channel?.sink.close();
    _baseUrl = null;
    _channel = null;
  }
}
