import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/result.dart';
import '../helpers/app_log.dart';

/// Root of every call to luminarabali.com — Midtrans and POS sync alike.
/// Lives here because auth is the lowest layer that needs it; everything else
/// imports it from this file rather than repeating the string.
///
/// Arahkan ke DDEV saat menguji lokal:
///   flutter run --dart-define=CLOUD_BASE_URL=http://localhost:44624/api
/// Tetap `const`, jadi build rilis tanpa flag ini persis seperti sebelumnya.
const cloudBaseUrl = String.fromEnvironment(
  'CLOUD_BASE_URL',
  defaultValue: 'https://luminarabali.com/api',
);

/// Whether the app may be used right now.
enum AccessStatus {
  granted,

  /// No token, or the server rejected the one we had.
  needsLogin,

  /// Token is still on disk, but we haven't been able to confirm it with the
  /// server for longer than [AuthService.licenseGrace].
  offlineTooLong,
}

/// Owns the Sanctum token: the account gate, and the credential every other
/// cloud call attaches.
///
/// Login is the only unauthenticated call, so it lives here instead of in
/// [CloudApi] — that keeps the dependency pointing one way.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  // Kunci baru; tidak ada instalasi lama yang memakainya.
  static const _keyToken = 'auth_token';
  static const _keyEmail = 'auth_email';
  static const _keyVerifiedAt = 'auth_last_verified';

  /// How long the app keeps working without reaching the server.
  ///
  /// Tanpa tenggang ini, internet yang mati di venue akan mengunci kasir di
  /// tengah acara — kegagalan yang jauh lebih mahal daripada instalasi liar
  /// yang dicegahnya. Angka ini memang untuk disetel setelah lihat lapangan.
  static const licenseGrace = Duration(days: 7);

  static const _timeout = Duration(seconds: 15);

  String? _token;
  String? _email;

  String? get token => _token;
  String? get email => _email;
  bool get isLoggedIn => _token != null;

  /// Headers for an authenticated request. Empty when logged out, which the
  /// server answers with 401 — callers don't need to pre-check.
  Map<String, String> get headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _email = prefs.getString(_keyEmail);
  }

  Future<Result<void>> login(
    String email,
    String password,
    String deviceName,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$cloudBaseUrl/pos/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
              'device_name': deviceName,
            }),
          )
          .timeout(_timeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        // 422 dari Laravel membawa pesan yang memang ditulis untuk dibaca user
        // ("Email atau password salah"), jadi diteruskan apa adanya.
        final message = _validationMessage(body) ?? 'Gagal masuk';
        return Err(message, message, StackTrace.current);
      }

      _token = body['token'] as String?;
      _email = (body['user'] as Map?)?['email'] as String?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, _token!);
      if (_email != null) await prefs.setString(_keyEmail, _email!);
      await _markVerified(prefs);

      return const Ok(null);
    } on SocketException catch (e, s) {
      return Err('Tidak dapat menghubungi server', e, s);
    } on TimeoutException catch (e, s) {
      return Err('Server tidak merespons', e, s);
    } catch (e, s) {
      AppLog.error('Login gagal: $e');
      return Err('Gagal masuk', e, s);
    }
  }

  Future<void> logout() async {
    _token = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyVerifiedAt);
  }

  /// Confirms the token with the server, falling back to [licenseGrace] when
  /// the server can't be reached.
  ///
  /// Only a 401 logs the device out. A 500 or a dead network must not — those
  /// are our problem, not evidence that the account is invalid.
  Future<AccessStatus> checkAccess() async {
    await load();
    if (_token == null) return AccessStatus.needsLogin;

    try {
      final response = await http
          .get(Uri.parse('$cloudBaseUrl/user'), headers: headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        await _markVerified(await SharedPreferences.getInstance());
        return AccessStatus.granted;
      }
      if (response.statusCode == 401) {
        await logout();
        return AccessStatus.needsLogin;
      }
    } catch (e) {
      AppLog.info('Verifikasi akun offline: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final lastVerified = DateTime.tryParse(
      prefs.getString(_keyVerifiedAt) ?? '',
    );
    if (lastVerified == null ||
        DateTime.now().difference(lastVerified) > licenseGrace) {
      return AccessStatus.offlineTooLong;
    }
    return AccessStatus.granted;
  }

  Future<void> _markVerified(SharedPreferences prefs) =>
      prefs.setString(_keyVerifiedAt, DateTime.now().toIso8601String());

  /// Pulls the first message out of Laravel's `{message, errors: {field: []}}`.
  static String? _validationMessage(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return body['message'] as String?;
  }
}
