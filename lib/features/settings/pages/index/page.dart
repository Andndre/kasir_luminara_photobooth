import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/settings/pages/printer/page.dart';
import 'package:luminara_photobooth/features/settings/pages/privacy_policy/page.dart';
import 'package:luminara_photobooth/features/settings/settings.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

part 'sections/profile_section.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Keluar dari Aplikasi'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Memeriksa pembaruan...'),
          ],
        ),
      ),
    );

    try {
      final status = await _updater.checkForUpdate();

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (status == UpdateStatus.outdated) {
        // Show update available dialog
        final shouldUpdate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.system_update, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Pembaruan Tersedia'),
              ],
            ),
            content: const Text(
              'Versi terbaru aplikasi telah tersedia. Apakah Anda ingin memperbarui sekarang?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Nanti Saja'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Perbarui'),
              ),
            ],
          ),
        );

        if (!context.mounted) return;

        if (shouldUpdate == true) {
          await _downloadUpdate(context);
        }
      } else {
        // No update available
        SnackBarHelper.showSuccess(
          context,
          "Aplikasi sudah menggunakan versi terbaru",
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error
      SnackBarHelper.showError(context, "Gagaal memeriksa pembaruan: $e");
    }
  }

  Future<void> _downloadUpdate(BuildContext context) async {
    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Mengunduh pembaruan...'),
          ],
        ),
      ),
    );

    try {
      await _updater.update();

      if (!context.mounted) return;

      // Close download dialog
      Navigator.pop(context);

      // Show success and restart prompt
      final shouldRestart = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Pembaruan Berhasil'),
            ],
          ),
          content: const Text(
            'Pembaruan telah berhasil diunduh! Untuk mengaktifkan versi terbaru, tutup aplikasi sepenuhnya dari latar belakang, lalu buka kembali.\n\nLihat panduan cara mengaktifkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nanti Saja'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lihat Panduan'),
            ),
          ],
        ),
      );

      if (shouldRestart == true) {
        // Show detailed instruction for activating the patch
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('Cara Mengaktifkan Pembaruan'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ikuti langkah berikut untuk mengaktifkan pembaruan:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Tekan tombol multitasking (□) di hp Anda'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Geser aplikasi Kasir ke atas untuk menutup',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Buka kembali aplikasi Kasir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Versi terbaru akan aktif!',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mengerti'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;

      // Close download dialog
      Navigator.pop(context);

      // Show error
      SnackBarHelper.showError(context, "Gagal mengunduh pembaruan: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        children: [
          const _ProfileSection(),
          const Divider(thickness: Dimens.dp8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(Dimens.dp16),
                child: RegularText.semiBold('Pengaturan Perangkat'),
              ),
              ItemMenuSetting(
                title: 'Printer',
                icon: Icons.print,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrinterPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(thickness: Dimens.dp8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(Dimens.dp16),
                child: RegularText.semiBold('Info Lainnya'),
              ),
              ItemMenuSetting(
                title: 'Kebijakan Privasi',
                icon: AppIcons.verified,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              ItemMenuSetting(
                title: 'Periksa Pembaruan',
                icon: Icons.system_update,
                onTap: () {
                  _checkForUpdate(context);
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(Dimens.dp16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.theme.colorScheme.error,
                side: BorderSide(color: context.theme.colorScheme.error),
              ),
              onPressed: () {
                _showExitDialog(context);
              },
              child: const Text('Keluar Aplikasi'),
            ),
          ),
        ],
      ),
    );
  }
}
