import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart' as esc;
import 'package:intl/intl.dart';

import 'package:luminara_photobooth/model/transaksi.dart';

class PrinterHelper {
  // Store the name of connected printer

  static String? connectedPrinterName;

  /// Get list of paired bluetooth devices

  static Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  /// Connect to printer using MAC address

  static Future<bool> connect(String macAddress) async {
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  /// Disconnect from printer

  static Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }

  /// Check if printer is connected

  static Future<bool> get isConnected async {
    bool status = await PrintBluetoothThermal.connectionStatus;

    if (!status) {
      connectedPrinterName = null; // Reset if disconnected
    }

    return status;
  }

  /// Print test receipt

  static Future<bool> printTestReceipt() async {
    return await printPhotoboothTicket(
      uuid: 'TEST123456',
      customerName: 'Nama Pelanggan',
      items: exampleItems
          .map(
            (e) => TransaksiItem(
              productName: e['name'],
              quantity: e['qty'],
              productPrice: e['price'],
            ),
          )
          .toList(),
      totalPrice: 80000,
      paymentMethod: 'TUNAI',
      bayarAmount: 100000,
      kembalian: 20000,
      date: DateTime.now(),
    );
  }

  /// Struktur item

  static List<Map<String, dynamic>> exampleItems = [
    {'name': 'Self Photo 15 Menit', 'qty': 1, 'price': 50000},

    {'name': 'Cetak Tambahan', 'qty': 2, 'price': 15000},
  ];

  // ======================================================

  // 🎟️ PHOTOBOOTH TICKET

  // ======================================================

  static Future<bool> printPhotoboothTicket({
    required String uuid,
    required String customerName,
    required List<TransaksiItem> items,
    required int totalPrice,
    String paymentMethod = 'TUNAI',
    int? bayarAmount,
    int? kembalian,
    DateTime? date,
    String storeName = 'LUMINARA PHOTOBOOTH',
    String tagline = 'Capture Your Best Moments',
  }) async {
    try {
      final profile = await esc.CapabilityProfile.load();

      final generator = esc.Generator(esc.PaperSize.mm58, profile);

      List<int> bytes = [];

      // Header

      bytes += generator.text(
        storeName,
        styles: const esc.PosStyles(
          align: esc.PosAlign.center,
          height: esc.PosTextSize.size1,
          width: esc.PosTextSize.size1,
          bold: true,
        ),
      );

      bytes += generator.text(
        tagline,
        styles: const esc.PosStyles(align: esc.PosAlign.center),
      );

      bytes += generator.hr(ch: "=");
      // Ticket Info
      bytes += generator.text(
        'TIKET PHOTOBOOTH',

        styles: const esc.PosStyles(
          align: esc.PosAlign.center,
          bold: true,
          height: esc.PosTextSize.size2,
          width: esc.PosTextSize.size2,
        ),
      );

      bytes += generator.feed(1);

      // QR Code

      bytes += generator.qrcode(
        uuid,
        size: esc.QRSize.Size8,
        cor: esc.QRCorrection.H,
      );

      bytes += generator.feed(1);

      // UUID Text

      bytes += generator.text(
        'CODE VOUCHER: ${uuid.toUpperCase()}',
        styles: const esc.PosStyles(align: esc.PosAlign.center),
      );

      bytes += generator.hr(ch: "-");

      // Details

      bytes += generator.text(
        'Tanggal : ${DateFormat('dd/MM/yyyy HH:mm').format(date ?? DateTime.now())}',
      );

      bytes += generator.text('Nama    : $customerName');
      bytes += generator.text('Metode  : $paymentMethod');
      bytes += generator.hr(ch: "-");

      // Items
      for (var item in items) {
        bytes += generator.text(item.productName);

        bytes += generator.row([
          esc.PosColumn(
            text:
                '${item.quantity} x ${NumberFormat("#,###").format(item.productPrice)}',

            width: 7,

            styles: const esc.PosStyles(align: esc.PosAlign.left),
          ),

          esc.PosColumn(
            text: NumberFormat(
              "#,###",
            ).format(item.quantity * item.productPrice),

            width: 5,

            styles: const esc.PosStyles(align: esc.PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr(ch: "-");

      bytes += generator.row([
        esc.PosColumn(
          text: 'TOTAL :',

          width: 6,

          styles: const esc.PosStyles(bold: true, align: esc.PosAlign.left),
        ),

        esc.PosColumn(
          text: 'Rp ${NumberFormat("#,###").format(totalPrice)}',

          width: 6,

          styles: const esc.PosStyles(bold: true, align: esc.PosAlign.right),
        ),
      ]);

      // Cash Details (Only for TUNAI)
      if (paymentMethod.toUpperCase() == 'TUNAI' && bayarAmount != null) {
        bytes += generator.row([
          esc.PosColumn(
            text: 'BAYAR :',
            width: 6,
            styles: const esc.PosStyles(align: esc.PosAlign.left),
          ),
          esc.PosColumn(
            text: NumberFormat("#,###").format(bayarAmount),
            width: 6,
            styles: const esc.PosStyles(align: esc.PosAlign.right),
          ),
        ]);

        if (kembalian != null) {
          bytes += generator.row([
            esc.PosColumn(
              text: 'KEMBALI :',
              width: 6,
              styles: const esc.PosStyles(align: esc.PosAlign.left),
            ),
            esc.PosColumn(
              text: NumberFormat("#,###").format(kembalian),
              width: 6,
              styles: const esc.PosStyles(align: esc.PosAlign.right),
            ),
          ]);
        }
      }

      bytes += generator.hr(ch: "=");

      // Footer

      bytes += generator.text(
        'Harap tunjukkan tiket ini\nkepada petugas untuk masuk.',

        styles: const esc.PosStyles(align: esc.PosAlign.center),
      );

      bytes += generator.feed(1);

      bytes += generator.text(
        'Terima Kasih!',
        styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
      );

      bytes += generator.text(
        'WhatsApp: 087788986136',
        styles: const esc.PosStyles(align: esc.PosAlign.center),
      );

      bytes += generator.text(
        'Instagram: @luminara_photobooth',
        styles: const esc.PosStyles(align: esc.PosAlign.center),
      );

      bytes += generator.cut();

      // Send to printer

      final result = await PrintBluetoothThermal.writeBytes(bytes);

      return result;
    } catch (e) {
      print('🎟️ Print ticket error: $e');

      return false;
    }
  }
}
