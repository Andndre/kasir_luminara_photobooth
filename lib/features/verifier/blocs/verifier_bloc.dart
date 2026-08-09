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

/// Menyambung sekaligus, karena tidak ada lagi yang perlu disambungkan.
///
/// Dulu ada ConnectToServer dan DisconnectFromServer, dipicu tombol di halaman
/// Koneksi. Halaman itu sudah dihapus: akun yang jadi pasangannya dan itu sudah
/// didapat saat login, jadi yang tersisa cuma membalik sebuah boolean lokal.
class InitializeVerifier extends VerifierEvent {}

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
    on<RefreshQueue>(_onRefreshQueue);
    on<VerifyTransaction>(_onVerifyTransaction);
  }

  Future<void> _onInitialize(
    InitializeVerifier event,
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

    service.connect();
    emit(
      state.copyWith(
        status: VerifierStatus.connected,
        serverIp: 'luminarabali.com',
      ),
    );
    add(RefreshQueue());
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
      AppLog.error('Gagal memuat antrean: $e');
      // Pesannya dipakai apa adanya, tidak diberi awalan lagi. Versi lama
      // menumpuk tiga: "Refresh Failed: Server tidak dapat dihubungi: Server
      // menjawab 403" — panjang, dua bahasa, dan menyesatkan di dua tempat.
      emit(
        state.copyWith(status: VerifierStatus.error, errorMessage: '$e'),
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
      AppLog.error('Gagal memverifikasi tiket: $e');
      emit(
        state.copyWith(
          verifyingUuid: null,
          verifySuccess: false,
          errorMessage: '$e',
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
