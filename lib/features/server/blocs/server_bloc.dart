import 'dart:io';
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:luminara_photobooth/core/services/server_service.dart';
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

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  final ServerService _serverService = ServerService();
  final NetworkInfo _networkInfo = NetworkInfo();

  ServerBloc() : super(const ServerState()) {
    on<StartServer>(_onStartServer);
    on<StopServer>(_onStopServer);
    on<RefreshServerInfo>(_onRefreshServerInfo);
  }

  Future<void> _onStartServer(StartServer event, Emitter<ServerState> emit) async {
    emit(state.copyWith(status: ServerStatus.starting));
    try {
      String? ip = await _networkInfo.getWifiIP();
      
      // Fallback if getWifiIP fails (e.g. Ethernet or Linux specific issues)
      if (ip == null || ip.isEmpty) {
        try {
          final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback && !addr.isLinkLocal) {
                // Prioritize 192.168 addresses
                if (addr.address.startsWith('192.168.')) {
                  ip = addr.address;
                  break;
                }
                // Secondary choice
                ip ??= addr.address;
              }
            }
            if (ip != null && ip.startsWith('192.168.')) break;
          }
        } catch (_) {}
      }

      await _serverService.start(port: state.port);
      emit(state.copyWith(
        status: ServerStatus.online,
        ipAddress: ip ?? '127.0.0.1',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ServerStatus.offline,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onStopServer(StopServer event, Emitter<ServerState> emit) async {
    emit(state.copyWith(status: ServerStatus.stopping));
    try {
      await _serverService.stop();
      emit(state.copyWith(status: ServerStatus.offline));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString(),
      ));
    }
  }

  void _onRefreshServerInfo(RefreshServerInfo event, Emitter<ServerState> emit) async {
     // This could update client count if we add a stream to ServerService
  }
}
