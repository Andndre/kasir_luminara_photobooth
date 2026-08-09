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

  /// Kapan [queue] terakhir benar-benar datang dari server.
  ///
  /// Antrean tidak lagi ditarik otomatis tiap 5 detik, jadi daftar ini bisa
  /// setua apa pun. Umurnya ditampilkan supaya petugas tahu kapan perlu
  /// menyegarkan — daftar basi yang terlihat sama dengan yang segar adalah
  /// cara paling halus untuk membuat orang salah menyimpulkan.
  final DateTime? queueFetchedAt;

  const VerifierState({
    this.status = VerifierStatus.disconnected,
    this.serverIp,
    this.queue = const [],
    this.errorMessage,
    this.verifyingUuid,
    this.verifySuccess = false,
    this.queueFetchedAt,
  });

  VerifierState copyWith({
    VerifierStatus? status,
    String? serverIp,
    List<QueueTicket>? queue,
    String? errorMessage,
    String? verifyingUuid,
    bool? verifySuccess,
    DateTime? queueFetchedAt,
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
      queueFetchedAt: queueFetchedAt ?? this.queueFetchedAt,
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
    queueFetchedAt,
  ];
}
