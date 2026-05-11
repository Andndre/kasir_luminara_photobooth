import 'package:equatable/equatable.dart';

enum VerifierStatus { disconnected, connecting, connected, error }

class VerifierState extends Equatable {
  final VerifierStatus status;
  final String? serverIp;
  final List<Map<String, dynamic>> queue;
  final String? errorMessage;
  final String? verifyingUuid;
  final bool verifySuccess;

  const VerifierState({
    this.status = VerifierStatus.disconnected,
    this.serverIp,
    this.queue = const [],
    this.errorMessage,
    this.verifyingUuid,
    this.verifySuccess = false,
  });

  VerifierState copyWith({
    VerifierStatus? status,
    String? serverIp,
    List<Map<String, dynamic>>? queue,
    String? errorMessage,
    String? verifyingUuid,
    bool? verifySuccess,
  }) {
    return VerifierState(
      status: status ?? this.status,
      serverIp: serverIp ?? this.serverIp,
      queue: queue ?? this.queue,
      errorMessage: errorMessage ?? this.errorMessage,
      verifyingUuid: verifyingUuid,
      verifySuccess: verifySuccess ?? this.verifySuccess,
    );
  }

  @override
  List<Object?> get props => [
    status,
    serverIp,
    queue,
    errorMessage,
    verifyingUuid,
    verifySuccess,
  ];
}
