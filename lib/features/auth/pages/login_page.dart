import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/auth_service.dart';
import 'package:luminara_photobooth/core/services/cashier_lease_service.dart';
import 'package:luminara_photobooth/core/services/sync_service.dart';
import 'package:provider/provider.dart';
import 'package:luminara_photobooth/features/home/home.dart';
import 'package:luminara_photobooth/features/settings/services/backup_service.dart';

enum _DataChoice { merge, replace }

/// Gerbang akun. Tidak punya Cubit karena tidak memuat data apa pun — isinya
/// dua field dan satu tombol, yang memang wilayah setState.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.notice});

  static const routeName = '/login';

  /// Alasan kenapa layar ini muncul, mis. masa tenggang offline habis.
  final String? notice;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    if (email.isEmpty || password.isEmpty) {
      SnackBarHelper.showWarning(context, 'Email dan password harus diisi');
      return;
    }

    setState(() => _busy = true);
    final result = await AuthService().login(
      email,
      password,
      '${Platform.operatingSystem} kasir',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Err(:final message):
        SnackBarHelper.showError(context, message);
      case Ok():
        await _reconcileData();
        if (!mounted) return;
        // Sewa diklaim di sini juga, bukan hanya di splash. Server menolak
        // katalog dari perangkat tanpa sewa, dan sesudah login yang berhasil
        // tidak ada yang mengklaimkannya sampai aplikasi dinyalakan ulang —
        // jadi paket yang dibuat di sesi pertama tidak akan pernah terkirim.
        if (context.read<AppMode>() == AppMode.server) {
          await CashierLeaseService().claim();
          if (!mounted) return;
        }
        SyncService().start();
        Navigator.pushNamedAndRemoveUntil(
          context,
          MainPage.routeName,
          (route) => false,
        );
    }
  }

  /// Decides what happens when this device and the server disagree.
  ///
  /// Perangkat baru (lokal kosong) langsung ditarik tanpa bertanya — tidak ada
  /// yang bisa hilang. Kalau dua-duanya berisi, user yang memutuskan: menimpa
  /// data orang lain diam-diam bukan keputusan yang boleh diambil aplikasi.
  Future<void> _reconcileData() async {
    setState(() => _busy = true);
    final plan = await SyncService().planAfterLogin();
    if (!mounted) return;

    switch (plan) {
      case LoginDataPlan.syncNormally:
        break;

      case LoginDataPlan.pullFromServer:
        await _pullFromServer();

      case LoginDataPlan.ask:
        final choice = await showDialog<_DataChoice>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Data berbeda dengan server'),
            content: const Text(
              'Perangkat ini punya transaksi yang tidak sama dengan yang '
              'tersimpan di akun Anda.\n\n'
              'Gabungkan: kirim data perangkat ini ke server, lalu muat '
              'gabungan keduanya.\n\n'
              'Ganti: buang data perangkat ini dan pakai data server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, _DataChoice.replace),
                style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
                child: const Text('Ganti'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _DataChoice.merge),
                child: const Text('Gabungkan'),
              ),
            ],
          ),
        );
        if (!mounted) return;

        if (choice == _DataChoice.merge) {
          // Dorong dulu. Setelah ini server memegang gabungan keduanya, jadi
          // "merge" tinggal menarik ulang — tidak perlu logika penggabungan
          // sendiri. Tapi kalau dorongan gagal, menarik ulang justru MENGHAPUS
          // yang belum terkirim, jadi berhenti di sini.
          switch (await SyncService().push()) {
            case Err(:final message):
              if (!mounted) return;
              SnackBarHelper.showError(
                context,
                'Gagal mengirim data perangkat ini: $message. '
                'Data lokal dibiarkan utuh.',
              );
              return;
            case Ok():
              await _pullFromServer();
          }
        } else if (choice == _DataChoice.replace) {
          await _pullFromServer();
        }
    }

    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pullFromServer() async {
    final restored = await BackupService.restoreFromCloud();
    if (!mounted) return;

    switch (restored) {
      case Ok():
        SnackBarHelper.showSuccess(context, 'Data akun dimuat dari server');
      case Err(:final message):
        SnackBarHelper.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Dimens.dp20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppLogoMark(size: 72),
                  Dimens.dp24.height,

                  HeadingText(
                    'Masuk ke akun Luminara',
                    style: TextStyle(
                      fontSize: Dimens.dp24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Dimens.dp8.height,
                  const SubtitleText(
                    'Data transaksi tersimpan di perangkat ini dan '
                    'disalin ke luminarabali.com',
                    textAlign: TextAlign.center,
                  ),

                  if (notice != null) ...[
                    Dimens.dp16.height,
                    Container(
                      padding: EdgeInsets.all(Dimens.dp12),
                      decoration: BoxDecoration(
                        color: AppTokens.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Dimens.dp8),
                      ),
                      child: RegularText(notice, textAlign: TextAlign.center),
                    ),
                  ],

                  Dimens.dp24.height,
                  RegularTextInput(
                    controller: _email,
                    label: 'Email',
                    hintText: 'nama@luminarabali.com',
                    prefixIcon: Icons.alternate_email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  Dimens.dp16.height,
                  RegularTextInput(
                    controller: _password,
                    label: 'Password',
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    enabled: !_busy,
                    obscureText: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  Dimens.dp24.height,
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Masuk'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
