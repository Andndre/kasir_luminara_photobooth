import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/core/services/verifier_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Overlay bidik: area gelap dengan lubang di tengah, sudut siku brand, dan
/// instruksi berlatar pil supaya tetap terbaca di atas video apa pun.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  static const double _size = 260;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Lapisan gelap berlubang. BlendMode.dstOut melubangi, bukan
            // menumpuk kotak terang di atas video.
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x8C000000),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(Dimens.rXl),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _size,
              height: _size,
              child: CustomPaint(painter: _CornerPainter()),
            ),
            Positioned(
              top: constraints.maxHeight / 2 + _size / 2 + Dimens.dp24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.dp16,
                  vertical: Dimens.dp10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(Dimens.rFull),
                ),
                child: const Text(
                  'Arahkan ke QR pada tiket',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Empat sudut siku, bukan bingkai penuh — lebih ringan secara visual dan
/// tetap memandu penempatan.
class _CornerPainter extends CustomPainter {
  static const double _len = 28;
  static const double _radius = Dimens.rXl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTokens.accent400
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final path = Path();

    // Kiri atas
    path.moveTo(rect.left, rect.top + _radius + _len);
    path.lineTo(rect.left, rect.top + _radius);
    path.arcToPoint(
      Offset(rect.left + _radius, rect.top),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(rect.left + _radius + _len, rect.top);

    // Kanan atas
    path.moveTo(rect.right - _radius - _len, rect.top);
    path.lineTo(rect.right - _radius, rect.top);
    path.arcToPoint(
      Offset(rect.right, rect.top + _radius),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(rect.right, rect.top + _radius + _len);

    // Kanan bawah
    path.moveTo(rect.right, rect.bottom - _radius - _len);
    path.lineTo(rect.right, rect.bottom - _radius);
    path.arcToPoint(
      Offset(rect.right - _radius, rect.bottom),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(rect.right - _radius - _len, rect.bottom);

    // Kiri bawah
    path.moveTo(rect.left + _radius + _len, rect.bottom);
    path.lineTo(rect.left + _radius, rect.bottom);
    path.arcToPoint(
      Offset(rect.left, rect.bottom - _radius),
      radius: const Radius.circular(_radius),
    );
    path.lineTo(rect.left, rect.bottom - _radius - _len);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TicketScannerPage extends StatefulWidget {
  const TicketScannerPage({super.key});

  @override
  State<TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<TicketScannerPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Kamera memenuhi layar, AppBar mengambang di atasnya.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scan Tiket'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isProcessing = true);
                  await _verifyTicket(barcode.rawValue!);
                  // _isProcessing reset is handled in _showResult or catch block
                  break;
                }
              }
            },
          ),
          const _ScannerOverlay(),
        ],
      ),
    );
  }

  Future<void> _verifyTicket(String code) async {
    try {
      final result = await context.read<VerifierBloc>().service.verifyTicket(
        code,
      );
      if (mounted) {
        _showResult(result);
      } else {
        // If unmounted, reset processing state immediately
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        AppLog.error('Error verifying ticket: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      // Reset state on error to allow retry
      setState(() => _isProcessing = false);
    }
  }

  void _showResult(VerifyResult result) {
    final accepted = result is TicketAccepted ? result : null;
    final isValid = accepted != null;
    final items = accepted?.items ?? const <QueueTicketItem>[];

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final surfaces = sheetContext.surfaces;
        final tint = isValid ? surfaces.successTint : surfaces.dangerTint;
        final fg = isValid ? surfaces.onSuccessTint : surfaces.onDangerTint;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Dimens.dp24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isValid
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      color: fg,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: Dimens.dp16),
                  Text(
                    isValid ? 'Tiket Valid' : 'Tiket Tidak Valid',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: Dimens.dp20),

                  if (accepted != null) ...[
                    Text(
                      accepted.customerName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: Dimens.dp16),
                    if (items.isEmpty)
                      Text(
                        accepted.summary,
                        style: theme.textTheme.bodyLarge,
                      )
                    else
                      ...items.map(
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: Dimens.dp8),
                          child: Row(
                            children: [
                              PackageMonogram(i.productName, size: 32),
                              const SizedBox(width: Dimens.dp12),
                              Expanded(
                                child: Text(
                                  '${i.productName} ×${i.quantity}',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: Dimens.dp16),
                    const StatusBadge(TransactionStatus.completed),
                  ] else
                    Text(
                      (result as TicketRejected).message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),

                  const SizedBox(height: Dimens.dp24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        setState(() => _isProcessing = false); // Resume scanning

                        if (isValid) {
                          Navigator.pop(context); // Close scanner on success
                        }
                      },
                      child: Text(isValid ? 'Selesai' : 'Scan Lagi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
