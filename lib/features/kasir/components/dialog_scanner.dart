import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class DialogScanner extends StatefulWidget {
  final Function(String) onDetect;

  const DialogScanner({super.key, required this.onDetect});

  @override
  State<DialogScanner> createState() => _DialogScannerState();
}

class _DialogScannerState extends State<DialogScanner> {
  MobileScannerController? controller;
  String? lastScannedCode;
  DateTime? lastScannedTime;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _handleBarcodeScan(String code) async {
    // Prevent duplicate scans within 2 seconds
    final now = DateTime.now();
    if (lastScannedCode == code &&
        lastScannedTime != null &&
        now.difference(lastScannedTime!).inSeconds < 2) {
      return;
    }

    lastScannedCode = code;
    lastScannedTime = now;

    // Add vibration feedback
    HapticFeedback.mediumImpact();

    // Call the callback
    widget.onDetect(code);

    // Show overlay feedback
    if (!mounted) return;

    // Use centralized snackbar helper for consistent styling
    SnackBarHelper.showSuccess(context, 'Barcode dipindai: $code');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return Dialog(
      insetPadding: const EdgeInsets.all(Dimens.dp16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimens.dp20,
                Dimens.dp12,
                Dimens.dp8,
                Dimens.dp8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pindai Barcode', style: theme.textTheme.titleLarge),
                        Text(
                          'Dialog tetap terbuka — beberapa produk bisa '
                          'dipindai berturut-turut.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Area kamera
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Dimens.dp16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: surfaces.surfaceAlt,
                  borderRadius: BorderRadius.circular(Dimens.rMd),
                ),
                child: MobileScanner(
                  controller: controller,
                  fit: BoxFit.cover,
                  onDetect: (capture) async {
                    final barcode = capture.barcodes.first;
                    if (barcode.rawValue != null) {
                      _handleBarcodeScan(barcode.rawValue!);
                    }
                  },
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(Dimens.dp16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => controller?.toggleTorch(),
                      icon: const Icon(Icons.flashlight_on_outlined, size: 20),
                      label: const Text('Senter'),
                    ),
                  ),
                  const SizedBox(width: Dimens.dp12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
