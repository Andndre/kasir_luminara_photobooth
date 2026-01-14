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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pindai Barcode',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Status info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: const Text(
                'Dialog tetap terbuka, scan beberapa produk sekaligus',
                style: TextStyle(fontSize: 12, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),

            // Area kamera
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
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

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Selesai Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      controller?.toggleTorch();
                    },
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Flash'),
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
