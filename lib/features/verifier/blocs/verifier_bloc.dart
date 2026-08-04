import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/services/verifier_service.dart';
import 'package:luminara_photobooth/core/domain/domain.dart';
import 'package:luminara_photobooth/core/preferences/verifier_preferences.dart';

import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/core/helpers/app_log.dart';

abstract class VerifierEvent extends Equatable {
  const VerifierEvent();
  @override
  List<Object> get props => [];
}

class InitializeVerifier extends VerifierEvent {}

class ConnectToServer extends VerifierEvent {
  final ServerAddress address;
  const ConnectToServer(this.address);

  @override
  List<Object> get props => [address];
}

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
  StreamSubscription? _eventSubscription;

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
    final saved = await VerifierPreferences.getServerAddress();
    if (saved != null) add(ConnectToServer(saved));
  }

  Future<void> _onConnect(
    ConnectToServer event,
    Emitter<VerifierState> emit,
  ) async {
    emit(state.copyWith(status: VerifierStatus.connecting));
    try {
      service.connect(event.address.host, event.address.port);

      // Save for next time
      await VerifierPreferences.saveServerAddress(event.address);

      // Listen for WebSocket events
      await _eventSubscription?.cancel();
      _eventSubscription = service.eventStream?.listen((data) {
        final message = jsonDecode(data);
        if (message['event'] == 'TICKET_REDEEMED' ||
            message['event'] == 'REFRESH_QUEUE') {
          add(RefreshQueue());
        }
      });

      emit(
        state.copyWith(status: VerifierStatus.connected, serverIp: event.address.toString()),
      );
      add(RefreshQueue());
    } catch (e) {
      AppLog.error('Verifier Connect Error: $e');
      emit(
        state.copyWith(
          status: VerifierStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDisconnect(
    DisconnectFromServer event,
    Emitter<VerifierState> emit,
  ) async {
    _eventSubscription?.cancel();
    service.disconnect();
    // Clear saved address so it doesn't auto-connect next time if manually disconnected
    await VerifierPreferences.clearServerAddress();
    emit(const VerifierState(status: VerifierStatus.disconnected));
  }

  Future<void> _onRefreshQueue(
    RefreshQueue event,
    Emitter<VerifierState> emit,
  ) async {
    try {
      final queue = await service.fetchQueue();
      emit(
        state.copyWith(
          queue: queue,
          status: VerifierStatus.connected,
          clearError: true,
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
    emit(
      state.copyWith(verifyingUuid: event.uuid, verifySuccess: false),
    );
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
    _eventSubscription?.cancel();
    service.disconnect();
    return super.close();
  }
}
