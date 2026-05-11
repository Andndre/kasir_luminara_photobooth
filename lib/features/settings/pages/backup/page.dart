import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:luminara_photobooth/features/settings/services/backup_service.dart';
import 'package:luminara_photobooth/features/settings/services/restore_service.dart';
import 'package:provider/provider.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isLoading = false;

  Future<void> _doBackup() async {
    setState(() => _isLoading = true);

    final path = await BackupService.exportBackup();

    setState(() => _isLoading = false);

    if (mounted) {
      if (path != null) {
        _showSnackBar('Backup berhasil disimpan ke:\n$path', isError: false);
      } else {
        _showSnackBar('Backup gagal atau dibatalkan', isError: true);
      }
    }
  }

  Future<void> _doRestore() async {
    // Konfirmasi sebelum restore
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text(
          'Data saat ini akan dihapus dan digantikan dengan data dari backup.\n\n'
          'Pastikan Anda sudah memilih file backup yang benar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final success = await RestoreService.importBackup(
      onSuccess: () {
        // Trigger refresh semua data di memory
        context.read<AppState>().notifyDataRestored();
      },
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        _showSnackBar('Restore berhasil. Data sudah di-refresh.', isError: false);
      } else {
        _showSnackBar('Restore gagal. Pastikan file backup valid.', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(Dimens.dp16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Backup Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Dimens.dp16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.backup, color: theme.primaryColor),
                              Dimens.dp12.width,
                              RegularText.semiBold('Backup Data'),
                            ],
                          ),
                          Dimens.dp8.height,
                          RegularText(
                            'Export semua data ke file JSON.\n'
                            'Termasuk: produk, transaksi, antrian.',
                          ),
                          Dimens.dp16.height,
                          ElevatedButton.icon(
                            onPressed: _doBackup,
                            icon: const Icon(Icons.download),
                            label: const Text('Download Backup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Dimens.dp16.height,
                  // Restore Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Dimens.dp16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.restore, color: theme.primaryColor),
                              Dimens.dp12.width,
                              RegularText.semiBold('Restore Data'),
                            ],
                          ),
                          Dimens.dp8.height,
                          RegularText(
                            'Import data dari file backup JSON.\n'
                            'PERINGATAN: Data saat ini akan DIHAPUS!',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          Dimens.dp16.height,
                          OutlinedButton.icon(
                            onPressed: _doRestore,
                            icon: const Icon(Icons.upload),
                            label: const Text('Upload Backup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
