import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/settings/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isBusy = false;

  Future<void> _run<T>(
    Future<Result<T>> Function() action,
    String done,
  ) async {
    setState(() => _isBusy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);

    switch (result) {
      case Ok():
        SnackBarHelper.showSuccess(context, done);
      // Cancelling the file picker is a normal exit, not a failure worth
      // shouting about.
      case Err(error: BackupCancelled()):
        break;
      case Err(:final message):
        AppLog.error(message);
        SnackBarHelper.showError(context, message);
    }
  }

  Future<void> _backup() =>
      _run(BackupService.export, 'Backup berhasil disimpan');

  Future<void> _restore() async {
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

    if (confirmed != true || !mounted) return;

    await _run(
      BackupService.import,
      'Restore berhasil. Data sudah di-refresh.',
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
      body: _isBusy
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(Dimens.dp16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            onPressed: _backup,
                            icon: const Icon(Icons.download),
                            label: const Text('Download Backup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Dimens.dp16.height,
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
                            onPressed: _restore,
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
