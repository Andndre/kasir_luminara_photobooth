import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/services/verifier_service.dart';
import 'package:luminara_photobooth/core/preferences/verifier_preferences.dart';

import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/model/log.dart';

abstract class VerifierEvent extends Equatable {
  const VerifierEvent();
  @override
  List<Object> get props => [];
}

class InitializeVerifier extends VerifierEvent {}

class ConnectToServer extends VerifierEvent {
  final String ip;
  final int port;
  const ConnectToServer(this.ip, this.port);
}

class DisconnectFromServer extends VerifierEvent {}

class RefreshQueue extends VerifierEvent {}

class ReconnectTick extends VerifierEvent {}

class SetReconnectingStatus extends VerifierEvent {}

class VerifierBloc extends Bloc<VerifierEvent, VerifierState> {
  final VerifierService service = VerifierService();
  StreamSubscription? _eventSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);

  VerifierBloc() : super(const VerifierState()) {
    on<InitializeVerifier>(_onInitialize);
    on<ConnectToServer>(_onConnect);
    on<DisconnectFromServer>(_onDisconnect);
    on<RefreshQueue>(_onRefreshQueue);
    on<SetReconnectingStatus>(_onSetReconnectingStatus);
  }

  Future<void> _onInitialize(
    InitializeVerifier event,
    Emitter<VerifierState> emit,
  ) async {
    final saved = await VerifierPreferences.getServerAddress();
    if (saved != null) {
      emit(state.copyWith(status: VerifierStatus.reconnecting));
      add(ConnectToServer(saved['ip'], saved['port']));
    }
  }

  Future<void> _onConnect(
    ConnectToServer event,
    Emitter<VerifierState> emit,
  ) async {
    emit(state.copyWith(status: VerifierStatus.connecting));
    try {
      service.connect(event.ip, event.port);

      await VerifierPreferences.saveServerAddress(event.ip, event.port);

      _connectionSubscription?.cancel();
      _connectionSubscription = service.connectionStream.listen((isConnected) {
        if (!isConnected && state.status == VerifierStatus.connected) {
          _scheduleReconnect();
        }
      });

      _eventSubscription?.cancel();
      _eventSubscription = service.eventStream?.listen((data) {
        final message = jsonDecode(data);
        if (message['event'] == 'TICKET_REDEEMED' ||
            message['event'] == 'REFRESH_QUEUE') {
          add(RefreshQueue());
        }
      });

      emit(
        state.copyWith(status: VerifierStatus.connected, serverIp: event.ip),
      );
      _reconnectAttempts = 0;
      add(RefreshQueue());
    } catch (e) {
      Log.insertLog('Verifier Connect Error: $e', isError: true);
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
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _connectionSubscription?.cancel();
    _eventSubscription?.cancel();
    service.disconnect();
    await VerifierPreferences.clearServerAddress();
    emit(const VerifierState(status: VerifierStatus.disconnected));
  }

  Future<void> _onRefreshQueue(
    RefreshQueue event,
    Emitter<VerifierState> emit,
  ) async {
    final isStillConnected = await service.testConnection();

    if (!isStillConnected && state.serverIp != null) {
      emit(state.copyWith(status: VerifierStatus.reconnecting));
      add(ConnectToServer(state.serverIp!, 3000));
      return;
    }

    try {
      final queue = await service.getQueue();
      emit(state.copyWith(queue: queue, status: VerifierStatus.connected));
    } catch (e) {
      Log.insertLog('Refresh Queue Error: $e', isError: true);
      emit(
        state.copyWith(
          status: VerifierStatus.error,
          errorMessage: 'Refresh Failed: $e',
        ),
      );
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      add(DisconnectFromServer());
      return;
    }

    add(SetReconnectingStatus());
    final delay = _initialReconnectDelay * (1 << _reconnectAttempts);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      add(RefreshQueue());
    });
  }

  Future<void> _onSetReconnectingStatus(
    SetReconnectingStatus event,
    Emitter<VerifierState> emit,
  ) async {
    emit(state.copyWith(status: VerifierStatus.reconnecting));
  }

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _connectionSubscription?.cancel();
    _eventSubscription?.cancel();
    service.disconnect();
    return super.close();
  }
}