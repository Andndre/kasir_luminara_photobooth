import 'dart:io';

import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Unduh lalu pasang, tanpa keluar dari aplikasi.
///
/// Tidak bisa ditutup dengan mengetuk latar: mengunduh puluhan megabita lalu
/// menghilangkan satu-satunya tempat kemajuannya terlihat adalah cara membuat
/// orang menekan Perbarui berkali-kali.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.update});

  final AppUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  String? _error;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _progress = 0;
    });

    try {
      final file = await UpdateService.download(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _installing = true);

      // Di Windows ini tidak pernah kembali — aplikasinya keluar supaya
      // berkasnya bisa ditimpa. Di Android dialog sistem yang mengambil alih.
      await UpdateService.install(file);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AppLog.error('Gagal memasang pembaruan: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _installing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = _error != null;

    return AlertDialog(
      title: Text(failed ? 'Pembaruan gagal' : 'Memperbarui ke ${widget.update.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failed)
            Text(_error!, style: theme.textTheme.bodyMedium)
          else ...[
            LinearProgressIndicator(
              // Null saat memasang: kemajuannya tidak lagi milik kita.
              value: _installing ? null : (_progress == 0 ? null : _progress),
            ),
            const SizedBox(height: Dimens.dp12),
            Text(
              _installing
                  ? 'Membuka pemasang…'
                  : 'Mengunduh ${(_progress * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
            if (_installing && Platform.isAndroid) ...[
              const SizedBox(height: Dimens.dp8),
              Text(
                'Kalau Android menolak, izinkan "Pasang aplikasi tidak dikenal" '
                'untuk aplikasi ini sekali saja.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
      actions: failed
          ? [
              // Jalan keluar terakhir kalau pemasang di dalam aplikasi buntu:
              // berkasnya tetap ada di halaman rilis.
              TextButton(
                onPressed: () => launchUrl(
                  widget.update.url,
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Unduh di browser'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              FilledButton(onPressed: _run, child: const Text('Coba Lagi')),
            ]
          : null,
    );
  }
}
