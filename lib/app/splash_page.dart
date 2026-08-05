import 'dart:async';

import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/core/services/cashier_lease_service.dart';
import 'package:luminara_photobooth/core/services/sync_service.dart';
import 'package:provider/provider.dart';
import 'package:luminara_photobooth/features/auth/auth.dart';
import 'package:luminara_photobooth/features/home/home.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _statusText = 'Memuat aplikasi...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (mounted) setState(() => _statusText = 'Memeriksa akun...');

    // Menggantikan penundaan 2 detik yang dulu hanya simulasi. Kalau server
    // tidak terjangkau, checkAccess jatuh ke masa tenggang offline dan tetap
    // menjawab granted — kasir tidak boleh terkunci gara-gara Wi-Fi venue.
    final access = await AuthService().checkAccess();

    if (!mounted) return;

    switch (access) {
      case AccessStatus.granted:
        setState(() => _statusText = 'Siap digunakan!');
        // Sync hanya di mode kasir. Verifier tidak membuat apa pun, jadi tidak
        // punya yang perlu didorong, dan tidak menyimpan salinan lokal yang
        // perlu ditarik — riwayatnya dibaca langsung dari server.
        if (context.read<AppMode>() == AppMode.server) {
          // Diklaim sebelum sync jalan, supaya detak pertama sudah punya sewa
          // untuk dilaporkan.
          await CashierLeaseService().claim();
          if (!mounted) return;
          SyncService().start();
        }
        // Tidak ditunggu: menyambung Bluetooth bisa memakan beberapa detik, dan
        // aplikasi tidak boleh menahan layar splash karena printer.
        unawaited(PrinterHelper.reconnectLast());
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          MainPage.routeName,
          (route) => false,
        );

      case AccessStatus.needsLogin:
        Navigator.pushNamedAndRemoveUntil(
          context,
          LoginPage.routeName,
          (route) => false,
        );

      case AccessStatus.offlineTooLong:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginPage(
              notice:
                  'Aplikasi belum terhubung ke server lebih dari '
                  '${AuthService.licenseGrace.inDays} hari. Sambungkan internet '
                  'dan masuk lagi untuk melanjutkan.',
            ),
          ),
          (route) => false,
        );
    }
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
                // Ukuran tetap, bukan pecahan lebar layar: di tablet dan
                // desktop yang dulu jadi logo raksasa.
                const AppLogoMark(size: 96),

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
                        borderRadius: BorderRadius.circular(Dimens.rFull),
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
