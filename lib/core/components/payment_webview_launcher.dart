import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewLauncher {
  static Future<void> launch(BuildContext context, String url, {VoidCallback? onClose}) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'Pembayaran Midtrans',
          titleBarTopPadding: Platform.isMacOS ? 20 : 0,
        ),
      );
      
      webview.launch(url);
      
      webview.onClose.then((_) {
        if (onClose != null) onClose();
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
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
