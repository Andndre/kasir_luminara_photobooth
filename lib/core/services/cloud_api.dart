import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../data/result.dart';
import '../domain/domain.dart';
import '../helpers/server_error_message.dart';
import 'auth_service.dart';
import 'cashier_lease_service.dart';

/// Redemptions pulled from the server, plus the cursor to resume from.
typedef Redemptions = ({String? cursor, Map<String, DateTime?> redeemedAt});

/// Authenticated calls to `/api/pos/*`.
///
/// Pure transport — *when* to call these lives in [SyncService]. Every method
/// returns a [Result] because all of them run in the background, where a thrown
/// exception would kill the loop that called it.
class CloudApi {
  const CloudApi();

  static const _timeout = Duration(seconds: 20);

  static AuthService get _auth => AuthService();

  /// Uploads transactions (and optionally the product list) to the server.
  ///
  /// The server ignores `status` and `redeemed_at` on rows it already has —
  /// redemption is its call, not ours — so re-sending a row is always safe.
  ///
  /// [products] null berarti "jangan sentuh katalog"; daftar kosong berarti
  /// "katalognya memang kosong". Bedanya penting: yang kedua menghapus.
  ///
  /// Returns the server's verdict on our cashier lease, or null when we didn't
  /// ask (verifier mode, or a server too old to answer).
  Future<Result<String?>> push(
    List<Transaction> transactions, {
    List<Product>? products,
    List<String> deleted = const [],
    String? deviceId,
  }) => _send(
    'POST',
    '/pos/sync',
    body: {
      if (deviceId != null) 'device_id': deviceId,
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
      // Dikirim sebagai pengganti utuh, jadi kuncinya harus ada walau daftarnya
      // kosong: tanpa itu, menghapus paket TERAKHIR tidak pernah sampai server.
      if (products != null)
        'products': products
            .where((p) => p.id != null)
            .map((p) => {'id': p.id, 'name': p.name, 'price': p.price})
            .toList(),
      if (deleted.isNotEmpty) 'deleted': deleted,
    },
    parse: (body) => (body as Map<String, dynamic>)['cashier_lease'] as String?,
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

  /// The account's catalogue.
  ///
  /// Sengaja bukan bagian dari sync berkala: katalog naik saat berubah, dan
  /// turun hanya saat user menyegarkan daftar paket.
  Future<Result<List<Product>>> products() => _send(
    'GET',
    '/pos/products',
    parse: (body) => _parseProducts((body as Map<String, dynamic>)['products']),
  );

  /// Tickets redeemed since [since]. Pass the previous call's cursor.
  ///
  /// Penukaran adalah satu-satunya hal yang dimiliki server, jadi ini
  /// satu-satunya yang perlu turun ke kasir. Transaksi tidak: hanya satu
  /// perangkat yang membuatnya, dan perangkat itu sudah memilikinya.
  Future<Result<Redemptions>> redemptions({String? since}) => _send(
    'GET',
    '/pos/redemptions${since == null ? '' : '?since=${Uri.encodeQueryComponent(since)}'}',
    parse: (body) {
      final map = body as Map<String, dynamic>;
      final list = (map['redemptions'] as List?) ?? const [];
      return (
        cursor: map['cursor'] as String?,
        redeemedAt: {
          for (final row in list.whereType<Map>())
            row['uuid'] as String: DateTime.tryParse(
              row['redeemed_at'] as String? ?? '',
            ),
        },
      );
    },
  );

  /// The account's history, read straight from the server.
  ///
  /// Dipakai verifier, yang tidak menyimpan salinan lokal apa pun — ia butuh
  /// internet untuk memindai tiket, jadi mereplikasi database yang harus
  /// didamaikan tidak membeli apa-apa.
  ///
  /// [to] eksklusif: kirim hari berikutnya untuk memasukkan seluruh hari ini.
  Future<Result<List<Transaction>>> history({String? from, String? to}) {
    final query = <String>[
      if (from != null) 'from=${Uri.encodeQueryComponent(from)}',
      if (to != null) 'to=${Uri.encodeQueryComponent(to)}',
    ];

    return _send(
      'GET',
      '/pos/history${query.isEmpty ? '' : '?${query.join('&')}'}',
      parse: (body) {
        final rows =
            ((body as Map<String, dynamic>)['transactions'] as List?) ??
            const [];
        return rows.whereType<Map>().map((row) {
          final map = row.cast<String, Object?>();
          final items = ((map['items'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (i) => TransactionItem(
                  productName: i['product_name'] as String? ?? '-',
                  productPrice: (i['product_price'] as num?)?.toInt() ?? 0,
                  quantity: (i['quantity'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList();
          return Transaction.fromMap(map, items);
        }).toList();
      },
    );
  }

  /// The whole account as a backup-format JSON string, ready for
  /// `BackupService.applyBackupJson`.
  Future<Result<String>> restoreJson() =>
      _send('GET', '/pos/restore', parse: jsonEncode);

  /// Claims the cashier role for this account.
  ///
  /// A 409 comes back as [LeaseHeldByOther] rather than a generic failure: the
  /// caller must tell "another device is the cashier" apart from "we couldn't
  /// ask", and merging the two would make a dropped connection look like a
  /// takeover.
  /// [products] null berarti server tidak menjawabnya sama sekali — versi lama,
  /// yang belum tahu katalog ikut di sini. Bedanya dengan daftar kosong sama
  /// pentingnya dengan di [push]: yang satu berarti "jangan sentuh", yang lain
  /// berarti "katalognya memang kosong, buang punyamu".
  Future<
    Result<({({String date, int lastNumber}) queue, List<Product>? products})>
  >
  claimCashier({
    required String deviceId,
    required String deviceName,
    required String queueDate,
    bool force = false,
  }) => _send(
    'POST',
    '/pos/cashier/claim',
    body: {
      'device_id': deviceId,
      'device_name': deviceName,
      'queue_date': queueDate,
      if (force) 'force': true,
    },
    onConflict: (body) {
      final holder = (body['holder'] as Map?)?.cast<String, dynamic>() ?? {};
      return LeaseHeldByOther((
        deviceName: holder['device_name'] as String? ?? 'perangkat lain',
        heartbeatAt: DateTime.tryParse(holder['heartbeat_at'] as String? ?? ''),
      ));
    },
    parse: (body) {
      final map = body as Map<String, dynamic>;
      final queue = (map['queue'] as Map?)?.cast<String, dynamic>() ?? const {};
      return (
        queue: (
          date: queue['date'] as String? ?? '',
          lastNumber: queue['last_number'] as int? ?? 0,
        ),
        products: map.containsKey('products')
            ? _parseProducts(map['products'])
            : null,
      );
    },
  );

  static List<Product> _parseProducts(Object? rows) =>
      ((rows as List?) ?? const [])
          .whereType<Map>()
          .map(
            (p) => Product(
              id: (p['id'] as num?)?.toInt(),
              name: p['name'] as String? ?? '-',
              price: (p['price'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();

  Future<Result<void>> releaseCashier({required String deviceId}) => _send(
    'POST',
    '/pos/cashier/release',
    body: {'device_id': deviceId},
    parse: (_) {},
  );

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    Map<String, Object?>? body,
    required T Function(Object? body) parse,
    Object Function(Map<String, dynamic> body)? onConflict,
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
          serverErrorMessage(401),
          'HTTP 401 $path',
          StackTrace.current,
        );
      }
      // 409 bukan kegagalan, melainkan jawaban: sesuatu yang lain memegangnya.
      // Pemanggil yang menyediakan [onConflict] mau membedakannya.
      if (response.statusCode == 409 && onConflict != null) {
        return Err(
          'Sedang dipakai perangkat lain',
          onConflict(jsonDecode(response.body) as Map<String, dynamic>),
          StackTrace.current,
        );
      }

      if (response.statusCode ~/ 100 != 2) {
        return Err(
          serverErrorMessage(response.statusCode),
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
