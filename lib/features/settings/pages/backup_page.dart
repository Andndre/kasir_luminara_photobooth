import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/features/settings/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isBusy = false;

  Future<void> _run<T>(Future<Result<T>> Function() action, String done) async {
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

  /// Jalur "ganti perangkat": tarik data akun ini dari luminarabali.com.
  Future<void> _restoreFromCloud() async {
    if (!AuthService().isLoggedIn) {
      SnackBarHelper.showWarning(context, 'Masuk ke akun dulu');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ambil Data dari Server?'),
        content: Text(
          'Data di perangkat ini akan dihapus dan diganti dengan data akun '
          '${AuthService().email ?? ''} di luminarabali.com.\n\n'
          'Transaksi di perangkat ini yang belum sempat terkirim akan hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Ambil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _run(
      BackupService.restoreFromCloud,
      'Data dari server berhasil dimuat.',
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
                            'Salinan dingin di luar server: satu-satunya yang '
                            'tersisa kalau akun atau server luminarabali.com '
                            'ikut hilang.',
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
                  // Dulu dua kartu terpisah yang mengulang peringatan yang sama.
                  // Keduanya melakukan hal identik — mengganti isi perangkat —
                  // jadi yang membedakan cuma sumbernya.
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
                              RegularText.semiBold('Pulihkan Data'),
                            ],
                          ),
                          Dimens.dp8.height,
                          RegularText(
                            'Data di perangkat ini akan diganti. Data di server '
                            'tidak ikut mundur — transaksi yang lebih baru di '
                            'sana tetap ada.',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          Dimens.dp16.height,
                          OutlinedButton.icon(
                            onPressed: _restoreFromCloud,
                            icon: const Icon(Icons.cloud_sync_outlined),
                            label: const Text('Dari Server'),
                          ),
                          Dimens.dp8.height,
                          OutlinedButton.icon(
                            onPressed: _restore,
                            icon: const Icon(Icons.upload),
                            label: const Text('Dari File Backup'),
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
