import 'dart:io';

import 'package:luminara_photobooth/core/preferences/printer_preferences.dart';
import 'package:luminara_photobooth/core/helpers/app_log.dart';
import 'package:luminara_photobooth/core/helpers/currency.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart' as esc;
import 'package:intl/intl.dart';

import 'package:luminara_photobooth/core/domain/domain.dart';

/// Thin wrapper over the ESC/POS thermal printer.
///
/// Stateless on purpose: which printer is connected lives in `PrinterCubit`,
/// not in a mutable static here where the two could disagree.
class PrinterHelper {
  // ponytail: mayoritas laci pakai pin2; kalau CD 339 tidak bereaksi, ganti ke pin5.
  static const _drawerPin = esc.PosDrawer.pin2;

  /// Get list of paired bluetooth devices

  static Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  /// Connect to printer using MAC address

  static Future<bool> connect(String macAddress) async {
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );

    if (connected) {
      await PrinterPreferences.setLastMac(macAddress);
    }

    return connected;
  }

  /// Ukuran kertas printer yang sedang dipakai (per MAC address).

  static Future<esc.PaperSize> _paperSize() async {
    final mac = await PrinterPreferences.getLastMac();

    if (mac == null) return esc.PaperSize.mm58;

    return await PrinterPreferences.isPaperMm80(mac)
        ? esc.PaperSize.mm80
        : esc.PaperSize.mm58;
  }

  /// Disconnect from printer

  static Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }

  /// Check if printer is connected

  static Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  /// Whether this platform can talk to the thermal printer at all.
  ///
  /// Bluetooth Classic SPP hanya ada di Android dan iOS di paket ini. Di Windows
  /// dan Linux jawabannya selalu "tidak terhubung", jadi apa pun yang memakai
  /// [isConnected] sebagai syarat harus melewati platform itu — kalau tidak,
  /// kasir desktop diblokir oleh printer yang memang tidak pernah ada.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Reconnects to the last printer used.
  ///
  /// Koneksi Bluetooth hidup selama proses, jadi tanpa ini kasir harus mampir
  /// ke Setelan → Printer setiap kali aplikasi dibuka — dan biasanya baru
  /// ketahuan saat struk pertama gagal keluar.
  static Future<bool> reconnectLast() async {
    if (!isSupported) return false;

    final mac = await PrinterPreferences.getLastMac();
    if (mac == null) return false;

    try {
      return await connect(mac);
    } catch (e) {
      // Ditelan: ini dipanggil saat splash, dan printer mati bukan alasan
      // aplikasi gagal terbuka.
      AppLog.error('Gagal menyambung ulang printer: $e');
      return false;
    }
  }

  /// Print test receipt

  static Future<bool> printTestReceipt() => printTicket(
    _sampleTransaction(),
    openDrawer: true, // test print sekalian tes laci kas
  );

  // Dibangun per panggilan: sebagai `static final` tanggalnya beku di test
  // print pertama, jadi cetakan kedua menunjukkan waktu yang salah.
  static Transaction _sampleTransaction() => Transaction(
    uuid: 'TEST123456',
    customerName: 'Nama Pelanggan',
    items: const [
      TransactionItem(
        productName: 'Self Photo 15 Menit',
        quantity: 1,
        productPrice: 50000,
      ),
      TransactionItem(
        productName: 'Cetak Tambahan',
        quantity: 2,
        productPrice: 15000,
      ),
    ],
    totalPrice: 80000,
    amountPaid: 100000,
    changeGiven: 20000,
    createdAt: DateTime.now(),
  );

  // ======================================================

  // 🎟️ PHOTOBOOTH TICKET

  // ======================================================

  /// Prints the customer's ticket. Takes the whole [transaction] so the receipt
  /// can never disagree with what was saved — the previous signature took nine
  /// loose fields that each call site had to keep in sync by hand.
  static Future<bool> printTicket(
    Transaction transaction, {
    bool openDrawer = false,
    String storeName = 'LUMINARA PHOTOBOOTH',
    String tagline = 'Capture Your Best Moments',
  }) async {
    final uuid = transaction.uuid;
    final customerName = transaction.customerName ?? '-';
    final items = transaction.items;
    final totalPrice = transaction.totalPrice;
    final paymentMethod = transaction.paymentMethod;
    final queueNumber = transaction.queueNumber;
    final date = transaction.createdAt;

    try {
      final profile = await esc.CapabilityProfile.load();

      final generator = esc.Generator(await _paperSize(), profile);

      List<int> bytes = [];

      // Laci dibuka di awal stream supaya terbuka barengan nota mulai
      // tercetak, bukan menunggu QR code dan seluruh isi nota selesai.
      if (openDrawer) bytes += generator.drawer(pin: _drawerPin);

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

      // Queue Number (BIG)
      if (queueNumber != null) {
        bytes += generator.text(
          'ANTRIAN #$queueNumber',
          styles: const esc.PosStyles(
            align: esc.PosAlign.center,
            bold: true,
            height: esc.PosTextSize.size2,
            width: esc.PosTextSize.size2,
          ),
        );
        bytes += generator.hr(ch: "-");
      }

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
        'Tanggal : ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
      );

      bytes += generator.text('Nama    : $customerName');
      bytes += generator.text('Metode  : ${paymentMethod.dbValue}');
      bytes += generator.hr(ch: "-");

      // Items
      for (var item in items) {
        bytes += generator.text(item.productName);

        bytes += generator.row([
          esc.PosColumn(
            text:
                '${item.quantity} x ${Currency.formatPlain(item.productPrice)}',

            width: 7,

            styles: const esc.PosStyles(align: esc.PosAlign.left),
          ),

          esc.PosColumn(
            text: Currency.formatPlain(item.quantity * item.productPrice),

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
          text: 'Rp ${Currency.formatPlain(totalPrice)}',

          width: 6,

          styles: const esc.PosStyles(bold: true, align: esc.PosAlign.right),
        ),
      ]);

      // Cash Details (Only for TUNAI)
      final amountPaid = transaction.amountPaid;
      if (paymentMethod.isCash && amountPaid != null) {
        bytes += generator.row([
          esc.PosColumn(
            text: 'BAYAR :',
            width: 6,
            styles: const esc.PosStyles(align: esc.PosAlign.left),
          ),
          esc.PosColumn(
            text: Currency.formatPlain(amountPaid),
            width: 6,
            styles: const esc.PosStyles(align: esc.PosAlign.right),
          ),
        ]);

        final changeGiven = transaction.changeGiven;
        if (changeGiven != null) {
          bytes += generator.row([
            esc.PosColumn(
              text: 'KEMBALI :',
              width: 6,
              styles: const esc.PosStyles(align: esc.PosAlign.left),
            ),
            esc.PosColumn(
              text: Currency.formatPlain(changeGiven),
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
      AppLog.error('Print ticket error: $e');
      return false;
    }
  }
}
