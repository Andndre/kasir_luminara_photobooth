import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/core/services/verifier_service.dart';

import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/core/helpers/app_log.dart';

abstract class VerifierEvent extends Equatable {
  const VerifierEvent();
  @override
  List<Object> get props => [];
}

class InitializeVerifier extends VerifierEvent {}

/// Pairs through the account on luminarabali.com. The account is the pairing;
/// there is no address to type in.
class ConnectToServer extends VerifierEvent {}

class DisconnectFromServer extends VerifierEvent {}

class RefreshQueue extends VerifierEvent {}

class VerifyTransaction extends VerifierEvent {
  final String uuid;
  const VerifyTransaction(this.uuid);

  @override
  List<Object> get props => [uuid];
}

class VerifierBloc extends Bloc<VerifierEvent, VerifierState> {
  final VerifierService service = VerifierService();

  VerifierBloc() : super(const VerifierState()) {
    on<InitializeVerifier>(_onInitialize);
    on<ConnectToServer>(_onConnect);
    on<DisconnectFromServer>(_onDisconnect);
    on<RefreshQueue>(_onRefreshQueue);
    on<VerifyTransaction>(_onVerifyTransaction);
  }

  Future<void> _onInitialize(
    InitializeVerifier event,
    Emitter<VerifierState> emit,
  ) async {
    // Tidak ada lagi alamat tersimpan yang perlu dibaca: akun yang jadi
    // pasangannya, jadi begitu sudah masuk, sambungkan saja.
    if (AuthService().isLoggedIn) add(ConnectToServer());
  }

  Future<void> _onConnect(
    ConnectToServer event,
    Emitter<VerifierState> emit,
  ) async {
    if (!AuthService().isLoggedIn) {
      emit(
        state.copyWith(
          status: VerifierStatus.error,
          errorMessage: 'Masuk ke akun dulu untuk verifikasi lewat internet',
        ),
      );
      return;
    }

    emit(state.copyWith(status: VerifierStatus.connecting));
    service.connect();

    emit(
      state.copyWith(
        status: VerifierStatus.connected,
        serverIp: 'luminarabali.com',
      ),
    );
    add(RefreshQueue());
  }

  Future<void> _onDisconnect(
    DisconnectFromServer event,
    Emitter<VerifierState> emit,
  ) async {
    service.disconnect();
    emit(const VerifierState(status: VerifierStatus.disconnected));
  }

  Future<void> _onRefreshQueue(
    RefreshQueue event,
    Emitter<VerifierState> emit,
  ) async {
    // `fetchQueue` mengembalikan daftar kosong — bukan melempar — saat belum
    // tersambung. Tanpa penjaga ini, menyegarkan dalam keadaan terputus akan
    // mengumumkan status `connected` dengan antrean kosong: persis tampilan
    // "semua tiket sudah dilayani", padahal yang benar "kita tidak tahu".
    // Baru bisa dijangkau sejak tombol Segarkan ada di bilah judul.
    if (!service.isConnected) return;

    try {
      final queue = await service.fetchQueue();
      emit(
        state.copyWith(
          queue: queue,
          status: VerifierStatus.connected,
          clearError: true,
          queueFetchedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      AppLog.error('Refresh Queue Error: $e');
      emit(
        state.copyWith(
          status: VerifierStatus.error,
          errorMessage: 'Refresh Failed: $e',
        ),
      );
    }
  }

  Future<void> _onVerifyTransaction(
    VerifyTransaction event,
    Emitter<VerifierState> emit,
  ) async {
    emit(state.copyWith(verifyingUuid: event.uuid, verifySuccess: false));
    try {
      switch (await service.verifyTicket(event.uuid)) {
        case TicketAccepted():
          emit(
            state.copyWith(
              verifyingUuid: null,
              verifySuccess: true,
              clearError: true,
            ),
          );
          add(RefreshQueue());

        case TicketRejected(:final message):
          emit(
            state.copyWith(
              verifyingUuid: null,
              verifySuccess: false,
              errorMessage: message,
            ),
          );
      }
    } catch (e) {
      AppLog.error('Verify Transaction Error: $e');
      emit(
        state.copyWith(
          verifyingUuid: null,
          verifySuccess: false,
          errorMessage: 'Verification Failed: $e',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    service.disconnect();
    return super.close();
  }
}
