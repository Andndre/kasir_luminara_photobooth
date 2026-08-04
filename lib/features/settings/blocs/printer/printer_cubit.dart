import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/printer_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterState extends Equatable {
  final List<BluetoothInfo> devices;

  /// Paper width per printer MAC. true = 80mm, false = 58mm.
  final Map<String, bool> paperMm80;

  final bool isScanning;
  final bool isConnected;
  final String? connectedName;

  const PrinterState({
    this.devices = const [],
    this.paperMm80 = const {},
    this.isScanning = false,
    this.isConnected = false,
    this.connectedName,
  });

  PrinterState copyWith({
    List<BluetoothInfo>? devices,
    Map<String, bool>? paperMm80,
    bool? isScanning,
    bool? isConnected,
    String? connectedName,
  }) => PrinterState(
    devices: devices ?? this.devices,
    paperMm80: paperMm80 ?? this.paperMm80,
    isScanning: isScanning ?? this.isScanning,
    isConnected: isConnected ?? this.isConnected,
    // Passing null clears it, which is what disconnecting wants.
    connectedName: isConnected == false ? null : connectedName ?? this.connectedName,
  );

  @override
  List<Object?> get props => [
    devices.map((d) => d.macAdress).toList(),
    paperMm80,
    isScanning,
    isConnected,
    connectedName,
  ];
}

/// Bluetooth printer pairing and paper size.
///
/// The connected printer's name used to live in a mutable static on
/// `PrinterHelper`, so the page and the helper could disagree about it.
class PrinterCubit extends Cubit<PrinterState> {
  PrinterCubit() : super(const PrinterState());

  Future<void> init() async {
    emit(state.copyWith(isConnected: await PrinterHelper.isConnected));
    await loadDevices();
  }

  /// Returns an error message, or null on success.
  Future<String?> loadDevices() async {
    emit(state.copyWith(isScanning: true));
    try {
      final devices = await PrinterHelper.getPairedDevices();

      final paperSizes = <String, bool>{};
      for (final device in devices) {
        paperSizes[device.macAdress] = await PrinterPreferences.isPaperMm80(
          device.macAdress,
        );
      }

      if (isClosed) return null;
      emit(
        state.copyWith(
          devices: devices,
          paperMm80: paperSizes,
          isScanning: false,
        ),
      );
      return null;
    } catch (e) {
      if (!isClosed) emit(state.copyWith(isScanning: false));
      final message = 'Gagal memuat daftar printer: $e';
      AppLog.error(message);
      return message;
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> connect(BluetoothInfo device) async {
    try {
      final connected = await PrinterHelper.connect(device.macAdress);
      if (isClosed) return null;

      if (!connected) return 'Gagal terhubung ke ${device.name}';

      emit(state.copyWith(isConnected: true, connectedName: device.name));
      return null;
    } catch (e) {
      final message = 'Gagal terhubung: $e';
      AppLog.error(message);
      return message;
    }
  }

  Future<String?> disconnect() async {
    try {
      final ok = await PrinterHelper.disconnect();
      if (isClosed) return null;

      if (!ok) return 'Gagal memutuskan koneksi';

      emit(state.copyWith(isConnected: false));
      return null;
    } catch (e) {
      final message = 'Gagal memutuskan koneksi: $e';
      AppLog.error(message);
      return message;
    }
  }

  Future<void> setPaperSize(String macAddress, bool isMm80) async {
    await PrinterPreferences.setPaperMm80(macAddress, isMm80);
    if (isClosed) return;
    emit(
      state.copyWith(paperMm80: {...state.paperMm80, macAddress: isMm80}),
    );
  }

  Future<String?> printTest() async {
    if (!state.isConnected) return 'Hubungkan printer terlebih dahulu';

    try {
      final ok = await PrinterHelper.printTestReceipt();
      return ok ? null : 'Gagal mencetak struk uji';
    } catch (e) {
      final message = 'Gagal mencetak: $e';
      AppLog.error(message);
      return message;
    }
  }
}
