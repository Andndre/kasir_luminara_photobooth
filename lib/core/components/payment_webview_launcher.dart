import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentWebViewLauncher {
  static Webview? _activeWebview;

  static Future<void> launch(
    BuildContext context,
    String url, {
    VoidCallback? onClose,
  }) async {
    // Linux Specific: Open in External Browser
    if (Platform.isLinux) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Windows / macOS: Desktop Window
    if (Platform.isWindows || Platform.isMacOS) {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Pembayaran Midtrans',
          titleBarTopPadding: Platform.isMacOS ? 20 : 0,
        ),
      );

      _activeWebview = webview;
      webview.launch(url);

      webview.onClose.then((_) {
        if (onClose != null) onClose();
        _activeWebview = null;
      });
    } else {
      // Mobile (Android/iOS)
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _MobileWebViewDialog(url: url, onClose: onClose),
      );
    }
  }

  // Method to close active desktop webview (Safe for Windows/macOS)
  static void close() {
    if (Platform.isWindows || Platform.isMacOS) {
      if (_activeWebview != null) {
        _activeWebview!.close();
        _activeWebview = null;
      }
    }
  }
}

class _MobileWebViewDialog extends StatefulWidget {
  final String url;
  final VoidCallback? onClose;

  const _MobileWebViewDialog({required this.url, this.onClose});

  @override
  State<_MobileWebViewDialog> createState() => _MobileWebViewDialogState();
}

class _MobileWebViewDialogState extends State<_MobileWebViewDialog> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 40,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.onClose != null) widget.onClose!();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
