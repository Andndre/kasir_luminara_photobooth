import 'package:equatable/equatable.dart';

/// Host and port of the cashier's server, as typed by the operator or read
/// from a pairing QR.
///
/// Parsing lives here rather than at each call site: the handshake screen and
/// the QR scanner each had their own `split(':')` + `int.parse(...)`, and the
/// `int.parse` threw on anything non-numeric.
class ServerAddress extends Equatable {
  final String host;
  final int port;

  const ServerAddress(this.host, this.port);

  static const defaultPort = 3000;

  /// Accepts `192.168.1.5` or `192.168.1.5:3000`. Returns null when the host
  /// is empty or the port isn't a valid number.
  static ServerAddress? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(':');
    // More than one colon is a typo, not an address — silently keeping the
    // first port hid the mistake.
    if (parts.length > 2) return null;

    final host = parts.first.trim();
    if (host.isEmpty) return null;

    if (parts.length == 1) return ServerAddress(host, defaultPort);

    final port = int.tryParse(parts[1].trim());
    if (port == null || port <= 0 || port > 65535) return null;

    return ServerAddress(host, port);
  }

  @override
  String toString() => '$host:$port';

  @override
  List<Object?> get props => [host, port];
}
