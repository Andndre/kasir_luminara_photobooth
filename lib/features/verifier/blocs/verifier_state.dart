import 'package:equatable/equatable.dart';

enum VerifierStatus { disconnected, connecting, connected, error }

class VerifierState extends Equatable {
  final VerifierStatus status;
  final String? serverIp;
  final List<Map<String, dynamic>> queue;
  final String? errorMessage;

  const VerifierState({
    this.status = VerifierStatus.disconnected,
    this.serverIp,
    this.queue = const [],
    this.errorMessage,
  });

  VerifierState copyWith({
    VerifierStatus? status,
    String? serverIp,
    List<Map<String, dynamic>>? queue,
    String? errorMessage,
  }) {
    return VerifierState(
      status: status ?? this.status,
      serverIp: serverIp ?? this.serverIp,
      queue: queue ?? this.queue,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, serverIp, queue, errorMessage];
}
