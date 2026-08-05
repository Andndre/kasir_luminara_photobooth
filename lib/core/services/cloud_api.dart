import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../data/result.dart';
import '../domain/domain.dart';
import 'auth_service.dart';

/// One page of the account as the server sent it, plus the cursor to resume
/// from. Rows stay as raw column maps — they go straight into SQLite, and
/// hydrating them into domain objects on the way would only be undone again.
typedef RemotePage = ({
  String? cursor,
  List<Map<String, Object?>> transactions,
  List<Map<String, Object?>> items,
  List<Product> products,
});

/// Authenticated calls to `/api/pos/*`.
///
/// Pure transport — *when* to call these lives in [SyncService]. Every method
/// returns a [Result] because all of them run in the background, where a thrown
/// exception would kill the loop that called it.
class CloudApi {
  const CloudApi();

  static const _timeout = Duration(seconds: 20);

  /// Matches the server's cap. A device catching up on a long history drains it
  /// a page per tick rather than in one response big enough to time out.
  static const _pullPage = 500;

  static AuthService get _auth => AuthService();

  /// Uploads transactions (and optionally the product list) to the server.
  ///
  /// The server ignores `status` and `redeemed_at` on rows it already has —
  /// redemption is its call, not ours — so re-sending a row is always safe.
  Future<Result<void>> push(
    List<Transaction> transactions, {
    List<Product> products = const [],
    List<String> deleted = const [],
  }) => _send(
    'POST',
    '/pos/sync',
    body: {
      'transactions': transactions
          .map(
            (t) => {
              ...t.toMap(),
              'items': t.items
                  .map(
                    (i) => {
                      'product_name': i.productName,
                      'product_price': i.productPrice,
                      'quantity': i.quantity,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      if (products.isNotEmpty)
        'products': products
            .where((p) => p.id != null)
            .map((p) => {'id': p.id, 'name': p.name, 'price': p.price})
            .toList(),
      if (deleted.isNotEmpty) 'deleted': deleted,
    },
    parse: (_) {},
  );

  /// How much this account holds on the server. Used right after login to
  /// decide between pulling, pushing, or asking the user.
  Future<Result<({int transactions, int products})>> summary() => _send(
    'GET',
    '/pos/summary',
    parse: (body) {
      final map = body as Map<String, dynamic>;
      return (
        transactions: map['transactions'] as int? ?? 0,
        products: map['products'] as int? ?? 0,
      );
    },
  );

  /// Rows changed since [since] — tickets another till sold, and tickets the
  /// verifier redeemed. Pass the previous call's cursor.
  ///
  /// Same endpoint as [restoreJson] on purpose: `?limit` is what turns the
  /// whole-account restore into a page, so there is only one response shape to
  /// keep in step with the server.
  Future<Result<RemotePage>> pull({String? since}) => _send(
    'GET',
    '/pos/restore?limit=$_pullPage'
        '${since == null ? '' : '&since=${Uri.encodeQueryComponent(since)}'}',
    parse: (body) {
      final map = body as Map<String, dynamic>;
      final tables =
          (map['tables'] as Map?)?.cast<String, dynamic>() ?? const {};

      List<Map<String, Object?>> rows(String table) =>
          ((tables[table] as List?) ?? const [])
              .whereType<Map>()
              .map((row) => row.cast<String, Object?>())
              .toList();

      return (
        cursor: map['cursor'] as String?,
        transactions: rows('transactions'),
        items: rows('transaction_items'),
        products: rows(
          'products',
        ).where((p) => p['id'] is int).map(Product.fromMap).toList(),
      );
    },
  );

  /// The whole account as a backup-format JSON string, ready for
  /// `BackupService.applyBackupJson`.
  Future<Result<String>> restoreJson() =>
      _send('GET', '/pos/restore', parse: jsonEncode);

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    Map<String, Object?>? body,
    required T Function(Object? body) parse,
  }) async {
    final uri = Uri.parse('$cloudBaseUrl$path');
    try {
      final response = method == 'GET'
          ? await http.get(uri, headers: _auth.headers).timeout(_timeout)
          : await http
                .post(uri, headers: _auth.headers, body: jsonEncode(body))
                .timeout(_timeout);

      if (response.statusCode == 401) {
        return Err(
          'Sesi berakhir, silakan masuk lagi',
          'HTTP 401 $path',
          StackTrace.current,
        );
      }
      if (response.statusCode ~/ 100 != 2) {
        return Err(
          'Server menolak permintaan (${response.statusCode})',
          'HTTP ${response.statusCode} $path: ${response.body}',
          StackTrace.current,
        );
      }

      return Ok(parse(jsonDecode(response.body)));
    } on SocketException catch (e, s) {
      return Err('Tidak dapat menghubungi server', e, s);
    } on TimeoutException catch (e, s) {
      return Err('Server tidak merespons', e, s);
    } catch (e, s) {
      return Err('Respons server tidak dikenali', e, s);
    }
  }
}
