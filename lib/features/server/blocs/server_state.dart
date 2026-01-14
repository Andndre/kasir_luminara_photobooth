import 'package:equatable/equatable.dart';

enum ServerStatus { offline, starting, online, stopping }

class ServerState extends Equatable {
  final ServerStatus status;
  final String? ipAddress;
  final int port;
  final int connectedClients;
  final String? errorMessage;

  const ServerState({
    this.status = ServerStatus.offline,
    this.ipAddress,
    this.port = 3000,
    this.connectedClients = 0,
    this.errorMessage,
  });

  ServerState copyWith({
    ServerStatus? status,
    String? ipAddress,
    int? port,
    int? connectedClients,
    String? errorMessage,
  }) {
    return ServerState(
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      connectedClients: connectedClients ?? this.connectedClients,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, ipAddress, port, connectedClients, errorMessage];
}
