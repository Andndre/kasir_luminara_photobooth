import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';

enum VerifierStatus { disconnected, connecting, connected, error }

class VerifierState extends Equatable {
  final VerifierStatus status;
  final String? serverIp;
  final List<QueueTicket> queue;
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
    List<QueueTicket>? queue,
    String? errorMessage,
    String? verifyingUuid,
    bool? verifySuccess,
    // `errorMessage: null` can't distinguish "leave it" from "clear it", so
    // clearing is an explicit flag. Without it a stale error stuck around
    // after a successful refresh.
    bool clearError = false,
  }) {
    return VerifierState(
      status: status ?? this.status,
      serverIp: serverIp ?? this.serverIp,
      queue: queue ?? this.queue,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      // Deliberately not `?? this.verifyingUuid`: passing null means "done
      // verifying", which is the common case.
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
