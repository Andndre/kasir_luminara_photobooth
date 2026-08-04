import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/settings/blocs/printer/printer_cubit.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterPage extends StatelessWidget {
  const PrinterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PrinterCubit()..init(),
      child: const _PrinterView(),
    );
  }
}

class _PrinterView extends StatelessWidget {
  const _PrinterView();

  /// Runs a cubit action behind a blocking spinner and reports the result.
  ///
  /// The old code popped the loading dialog inside its own catch block without
  /// checking it was still on top, which could pop the page instead.
  Future<void> _withLoading(
    BuildContext context,
    String message,
    Future<String?> Function() action,
    String success,
  ) async {
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: Dimens.dp16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );

    final error = await action();
    navigator.pop(); // the loading dialog

    if (!context.mounted) return;
    if (error != null) {
      SnackBarHelper.showError(context, error);
    } else {
      SnackBarHelper.showSuccess(context, success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PrinterCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cubit.loadDevices,
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<PrinterCubit, PrinterState>(
          builder: (context, state) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.dp20,
                  Dimens.dp8,
                  Dimens.dp20,
                  Dimens.dp16,
                ),
                child: _ConnectionCard(
                  state: state,
                  onDisconnect: () async {
                    final error = await cubit.disconnect();
                    if (!context.mounted) return;
                    if (error != null) {
                      SnackBarHelper.showError(context, error);
                    } else {
                      SnackBarHelper.showSuccess(context, 'Printer diputuskan');
                    }
                  },
                  onPrintTest: () => _withLoading(
                    context,
                    'Mencetak struk uji...',
                    cubit.printTest,
                    'Struk uji berhasil dicetak',
                  ),
                ),
              ),
              Expanded(
                child: state.isScanning
                    ? const Center(child: CircularProgressIndicator())
                    : state.devices.isEmpty
                    ? EmptyState(
                        icon: Icons.bluetooth_searching_rounded,
                        title: 'Tidak ada printer',
                        message:
                            'Pasangkan printer lewat pengaturan Bluetooth '
                            'perangkat terlebih dahulu, lalu muat ulang.',
                        actionLabel: 'Muat Ulang',
                        onAction: cubit.loadDevices,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Dimens.dp20,
                          0,
                          Dimens.dp20,
                          Dimens.dp20,
                        ),
                        itemCount: state.devices.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Dimens.dp12),
                        itemBuilder: (context, index) {
                          final device = state.devices[index];
                          return _DeviceCard(
                            device: device,
                            isCurrent: state.connectedName == device.name,
                            isMm80: state.paperMm80[device.macAdress] ?? false,
                            onConnect: () => _withLoading(
                              context,
                              'Menghubungkan ke ${device.name}...',
                              () => cubit.connect(device),
                              'Terhubung ke ${device.name}',
                            ),
                            onPaperSizeChanged: (isMm80) =>
                                cubit.setPaperSize(device.macAdress, isMm80),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.state,
    required this.onDisconnect,
    required this.onPrintTest,
  });

  final PrinterState state;
  final VoidCallback onDisconnect;
  final VoidCallback onPrintTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final connected = state.isConnected;

    return AppCard(
      color: connected ? surfaces.successTint : null,
      borderColor: connected ? Colors.transparent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                size: 20,
                color: connected ? surfaces.onSuccessTint : surfaces.textMuted,
              ),
              const SizedBox(width: Dimens.dp12),
              Expanded(
                child: Text(
                  connected
                      ? state.connectedName ?? 'Printer terhubung'
                      : 'Belum ada printer terhubung',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: connected ? surfaces.onSuccessTint : null,
                  ),
                ),
              ),
              if (connected)
                TextButton(
                  onPressed: onDisconnect,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTokens.danger,
                  ),
                  child: const Text('Putuskan'),
                ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: Dimens.dp12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPrintTest,
                icon: const Icon(Icons.print_outlined, size: 20),
                label: const Text('Cetak Struk Uji'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.isCurrent,
    required this.isMm80,
    required this.onConnect,
    required this.onPaperSizeChanged,
  });

  final BluetoothInfo device;
  final bool isCurrent;
  final bool isMm80;
  final VoidCallback onConnect;
  final ValueChanged<bool> onPaperSizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return AppCard(
      onTap: isCurrent ? null : onConnect,
      borderColor: isCurrent ? AppTokens.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.print_outlined,
                size: 20,
                color: isCurrent ? AppTokens.success : surfaces.textSecondary,
              ),
              const SizedBox(width: Dimens.dp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: theme.textTheme.titleMedium),
                    Text(device.macAdress, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (isCurrent)
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: AppTokens.success,
                ),
            ],
          ),
          const SizedBox(height: Dimens.dp12),
          Row(
            children: [
              Text('Ukuran kertas', style: theme.textTheme.bodyMedium),
              const Spacer(),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('58mm')),
                  ButtonSegment(value: true, label: Text('80mm')),
                ],
                selected: {isMm80},
                onSelectionChanged: (selection) =>
                    onPaperSizeChanged(selection.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
