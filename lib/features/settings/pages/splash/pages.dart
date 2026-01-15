import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/home/home.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ShorebirdUpdater _updater = ShorebirdUpdater();
  String _statusText = 'Memuat aplikasi...';
  String _versionInfo = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Get current patch info
      final currentPatch = await _updater.readCurrentPatch();
      if (mounted) {
        setState(() {
          _versionInfo = currentPatch != null
              ? 'Patch: ${currentPatch.number}'
              : 'Versi Original';
          _statusText = 'Memeriksa pembaruan...';
        });
      }

      // Check if update is available
      final status = await _updater.checkForUpdate();

      if (!mounted) return;

      if (status == UpdateStatus.outdated) {
        await _showUpdateDialog();
      } else {
        await _navigateToHome();
      }
    } catch (e) {
      // If check update fails, proceed to home
      if (mounted) {
        await _navigateToHome();
      }
    }
  }

  Future<void> _showUpdateDialog() async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Pembaruan Tersedia'),
          ],
        ),
        content: const Text(
          'Versi terbaru aplikasi telah tersedia. Pembaruan ini mungkin berisi perbaikan bug dan fitur baru.\n\nApakah Anda ingin memperbarui sekarang?',
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
            child: const Text('Perbarui Sekarang'),
          ),
        ],
      ),
    );

    if (shouldUpdate == true) {
      await _downloadAndInstallUpdate();
    } else {
      await _navigateToHome();
    }
  }

  Future<void> _downloadAndInstallUpdate() async {
    setState(() {
      _statusText = 'Mengunduh pembaruan...';
    });

    try {
      // Download and install the update
      await _updater.update();

      if (!mounted) return;

      setState(() {
        _statusText = 'Pembaruan berhasil diunduh!';
      });

      // Small delay to show the success message
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;

      // Show restart dialog
      await _showRestartDialog();
    } catch (e) {
      if (!mounted) return;

      // Show error and proceed anyway
      setState(() {
        _statusText = 'Gagal mengunduh pembaruan';
      });

      if (mounted) {
        SnackBarHelper.showError(context, 'Gagal mengunduh pembaruan: $e');
      }

      await _navigateToHome();
    }
  }

  Future<void> _showRestartDialog() async {
    final shouldRestart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Pembaruan Berhasil'),
          ],
        ),
        content: const Text(
          'Pembaruan telah berhasil diunduh! Untuk mengaktifkan versi terbaru, aplikasi perlu ditutup sepenuhnya dan dibuka kembali.\n\nLanjutkan menggunakan aplikasi atau lihat panduan aktivasi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjutkan Saja'),
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
      // Show detailed instruction before navigation
      await _showDetailedInstruction();
    } else {
      await _navigateToHome();
    }
  }

  Future<void> _showDetailedInstruction() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
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
              'Pembaruan telah diunduh! Untuk mengaktifkan versi terbaru:',
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
                  child: Text('Geser aplikasi Kasir ke atas untuk menutup'),
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
                const Expanded(child: Text('Buka kembali aplikasi Kasir')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
            onPressed: () {
              Navigator.pop(context);
              _navigateToHome();
            },
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

  Future<void> _navigateToHome() async {
    setState(() {
      _statusText = 'Siap digunakan!';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      MainPage.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with subtle animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    MainAssets.logo,
                    width: MediaQuery.of(context).size.width / 4,
                  ),
                ),
  
                Dimens.defaultSize.height,
  
                // App title
                HeadingText(
                  'Luminara Photobooth',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.headlineLarge?.color,
                    fontSize: Dimens.dp32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
  
                const SizedBox(height: 40),
  
                // Progress indicator and status
                Column(
                  children: [
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        borderRadius: BorderRadius.circular(Dimens.radius),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_versionInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _versionInfo,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
