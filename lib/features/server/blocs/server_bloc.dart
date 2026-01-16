import 'dart:io';
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
import 'package:luminara_photobooth/model/log.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'server_state.dart';

abstract class ServerEvent extends Equatable {
  const ServerEvent();

  @override
  List<Object> get props => [];
}

class StartServer extends ServerEvent {}

class StopServer extends ServerEvent {}

class RefreshServerInfo extends ServerEvent {}

class UpdateClientCount extends ServerEvent {
  final int count;
  const UpdateClientCount(this.count);

  @override
  List<Object> get props => [count];
}

class UpdateServerStatus extends ServerEvent {
  final bool isOnline;
  const UpdateServerStatus(this.isOnline);

  @override
  List<Object> get props => [isOnline];
}

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  final ServerService _serverService = ServerService();
  final NetworkInfo _networkInfo = NetworkInfo();
  StreamSubscription<int>? _clientCountSubscription;
  StreamSubscription<bool>? _statusSubscription;

  ServerBloc() : super(const ServerState()) {
    on<StartServer>(_onStartServer);
    on<StopServer>(_onStopServer);
    on<RefreshServerInfo>(_onRefreshServerInfo);
    on<UpdateClientCount>(_onUpdateClientCount);
    on<UpdateServerStatus>(_onUpdateServerStatus);

    // Initial listener for status changes (for Android background service)
    _statusSubscription = _serverService.statusStream.listen((isOnline) {
      add(UpdateServerStatus(isOnline));
    });
  }

  @override
  Future<void> close() {
    _clientCountSubscription?.cancel();
    _statusSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStartServer(
    StartServer event,
    Emitter<ServerState> emit,
  ) async {
    if (state.status == ServerStatus.online) return;

    emit(state.copyWith(status: ServerStatus.starting));
    try {
      String? ip = await _networkInfo.getWifiIP();

      if (ip == null || ip.isEmpty) {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        );
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
          if (ip != null) break;
        }
      }

      await _serverService.start(port: state.port);

      // Listen to client count changes
      _clientCountSubscription?.cancel();
      _clientCountSubscription = _serverService.clientCountStream.listen((
        count,
      ) {
        add(UpdateClientCount(count));
      });

      // If not on Android, we can immediately emit online
      // On Android, the background service will eventually emit its status
      if (!Platform.isAndroid) {
        emit(
          state.copyWith(
            status: ServerStatus.online,
            ipAddress: ip ?? '127.0.0.1',
            connectedClients: _serverService.clientCount,
          ),
        );
      } else {
        // Just update IP, status will follow from UpdateServerStatus event
        emit(state.copyWith(ipAddress: ip ?? '127.0.0.1'));
      }
    } catch (e) {
      Log.insertLog('Server Start Error: $e', isError: true);
      emit(
        state.copyWith(
          status: ServerStatus.offline,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onStopServer(
    StopServer event,
    Emitter<ServerState> emit,
  ) async {
    emit(state.copyWith(status: ServerStatus.stopping));
    try {
      _clientCountSubscription?.cancel();
      await _serverService.stop();

      if (!Platform.isAndroid) {
        emit(state.copyWith(status: ServerStatus.offline, connectedClients: 0));
      }
    } catch (e) {
      Log.insertLog('Server Stop Error: $e', isError: true);
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void _onRefreshServerInfo(
    RefreshServerInfo event,
    Emitter<ServerState> emit,
  ) async {}

  void _onUpdateClientCount(
    UpdateClientCount event,
    Emitter<ServerState> emit,
  ) {
    emit(state.copyWith(connectedClients: event.count));
  }

  void _onUpdateServerStatus(
    UpdateServerStatus event,
    Emitter<ServerState> emit,
  ) {
    emit(
      state.copyWith(
        status: event.isOnline ? ServerStatus.online : ServerStatus.offline,
        connectedClients: event.isOnline ? state.connectedClients : 0,
      ),
    );
  }
}
