import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:kasir/core/services/verifier_service.dart';

import 'package:kasir/features/verifier/blocs/verifier_state.dart';

abstract class VerifierEvent extends Equatable {
  const VerifierEvent();
  @override
  List<Object> get props => [];
}

class ConnectToServer extends VerifierEvent {
  final String ip;
  final int port;
  const ConnectToServer(this.ip, this.port);
}

class RefreshQueue extends VerifierEvent {}

class VerifierBloc extends Bloc<VerifierEvent, VerifierState> {
  final VerifierService service = VerifierService();
  StreamSubscription? _eventSubscription;

  VerifierBloc() : super(const VerifierState()) {
    on<ConnectToServer>(_onConnect);
    on<RefreshQueue>(_onRefreshQueue);
  }

  Future<void> _onConnect(ConnectToServer event, Emitter<VerifierState> emit) async {
    emit(state.copyWith(status: VerifierStatus.connecting));
    try {
      service.connect(event.ip, event.port);
      
      // Listen for WebSocket events
      await _eventSubscription?.cancel();
      _eventSubscription = service.eventStream?.listen((data) {
        final message = jsonDecode(data);
        if (message['event'] == 'TICKET_REDEEMED' || message['event'] == 'REFRESH_QUEUE') {
          add(RefreshQueue());
        }
      });

      emit(state.copyWith(
        status: VerifierStatus.connected,
        serverIp: event.ip,
      ));
      add(RefreshQueue());
    } catch (e) {
      emit(state.copyWith(status: VerifierStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefreshQueue(RefreshQueue event, Emitter<VerifierState> emit) async {
    try {
      final queue = await service.getQueue();
      emit(state.copyWith(queue: queue));
    } catch (e) {
      // Keep existing queue if refresh fails
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    service.disconnect();
    return super.close();
  }
}
