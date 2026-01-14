import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/post_code.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart' as esc;
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';

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
    return await printReceiptWithPayment(
      items: exampleItems,
      storeName: 'MIMBABALI_BUSANA',
      storeTagline: 'Pusat Busana Adat Bali',
      totalAmount: 390000,
      bayarAmount: 400000,
      kembalian: 10000,
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
    required String productName,
    required int price,
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
      bytes += generator.text('TIKET PHOTOBOOTH', 
          styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true, height: esc.PosTextSize.size2, width: esc.PosTextSize.size2));
      bytes += generator.feed(1);

      // QR Code
      bytes += generator.qrcode(uuid, size: esc.QRSize.Size6, cor: esc.QRCorrection.H);
      bytes += generator.feed(1);
      
      // UUID Text
      bytes += generator.text(
        uuid.split('-').first.toUpperCase(), // Short UUID for readability
        styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
      );
      
      bytes += generator.hr(ch: "-");

      // Details
      bytes += generator.text('Tanggal : ${DateFormat('dd/MM/yyyy HH:mm').format(date ?? DateTime.now())}');
      bytes += generator.text('Nama    : $customerName');
      bytes += generator.text('Paket   : $productName');
      bytes += generator.text('Harga   : Rp ${NumberFormat("#,###").format(price)}');

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
      
      bytes += generator.cut();

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      print('🎟️ Print ticket error: $e');
      return false;
    }
  }

  // ======================================================
  // 🧩 HEADER SECTION
  // ======================================================
  static Future<List<int>> _buildHeader(
    esc.Generator generator,
    String storeName,
    String tagline,
    DateTime? waktuBayar,
  ) async {
    List<int> bytes = [];

    // Load & resize logo
    final ByteData imageData = await rootBundle.load(
      'assets/images/logo-struk.png',
    );
    image_lib.Image image = image_lib.decodeImage(
      imageData.buffer.asUint8List(),
    )!;
    image_lib.Image resized = image_lib.copyResize(image, width: 300);

    bytes += generator.image(resized, align: esc.PosAlign.center);
    bytes += generator.hr(ch: "=");

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

    bytes += generator.text(
      'Alamat       : Jln. Tohlangkir \nNo.9, Bebandem, Kec. Bebandem, \nKabupaten Karangasem, Bali 80861',
      styles: const esc.PosStyles(align: esc.PosAlign.left),
    );
    bytes += generator.text(
      'No. WhatsApp : 0813-3654-042',
      styles: const esc.PosStyles(align: esc.PosAlign.left),
    );

    final dateToUse = waktuBayar ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateToUse);
    bytes += generator.text(
      'Tanggal      : $formattedDate',
      styles: const esc.PosStyles(align: esc.PosAlign.left),
      linesAfter: 1,
    );
    bytes += generator.hr(ch: "=");

    return bytes;
  }

  // ======================================================
  // 🧾 ITEM LIST SECTION
  // ======================================================
  static List<int> _buildItemList(
    esc.Generator generator,
    List<Map<String, dynamic>> items,
  ) {
    List<int> bytes = [];
    double total = 0;

    for (var item in items) {
      final name = item['name'] ?? '-';
      final qty = item['qty'] ?? 0;
      final price = item['price'] ?? 0.0;
      final subtotal = qty * price;
      total += subtotal;

      bytes += generator.text(
        name,
        styles: const esc.PosStyles(align: esc.PosAlign.left),
      );

      bytes += generator.row([
        esc.PosColumn(
          text: 'x$qty',
          width: 4,
          styles: const esc.PosStyles(align: esc.PosAlign.right),
        ),
        esc.PosColumn(
          text: NumberFormat("#,###").format(price),
          width: 4,
          styles: const esc.PosStyles(align: esc.PosAlign.right),
        ),
        esc.PosColumn(
          text: NumberFormat("#,###").format(price * qty),
          width: 4,
          styles: const esc.PosStyles(align: esc.PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    bytes += generator.row([
      esc.PosColumn(
        text: 'TOTAL :',
        width: 8,
        styles: const esc.PosStyles(bold: true, align: esc.PosAlign.right),
      ),
      esc.PosColumn(
        text: NumberFormat("#,###").format(total),
        width: 4,
        styles: const esc.PosStyles(bold: true, align: esc.PosAlign.right),
      ),
    ]);

    bytes += generator.hr();
    return bytes;
  }

  // ======================================================
  // 🧷 FOOTER SECTION
  // ======================================================
  static List<int> _buildFooter(esc.Generator generator, String storeName) {
    List<int> bytes = [];

    bytes += generator.text(
      'Terima kasih telah berbelanja di',
      styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
    );
    bytes += generator.text(
      storeName,
      styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Pusat busana adat Bali yang\nmenjaga keanggunan dan tradisi\nbudaya',
      styles: const esc.PosStyles(align: esc.PosAlign.center),
      linesAfter: 1,
    );
    bytes += generator.text(
      'Barang yang sudah dibeli tidak \ndapat dikembalikan',
      styles: const esc.PosStyles(align: esc.PosAlign.center),
      linesAfter: 1,
    );
    bytes += generator.text(
      'Instagram: @mimbabali_busanaa',
      styles: const esc.PosStyles(align: esc.PosAlign.center),
    );

    bytes += generator.hr(ch: "=");
    bytes += generator.cut();

    return bytes;
  }

  /// Print receipt with payment details
  static Future<bool> printReceiptWithPayment({
    required List<Map<String, dynamic>> items,
    required int totalAmount,
    required int bayarAmount,
    required int kembalian,
    String paymentMethod = 'TUNAI',
    String storeName = 'MIMBABALI_BUSANA',
    String storeTagline = 'Pusat Busana Adat Bali',
    DateTime? waktuBayar,
  }) async {
    try {
      final profile = await esc.CapabilityProfile.load();
      final generator = esc.Generator(esc.PaperSize.mm58, profile);
      List<int> bytes = [];

      // Tambahkan bagian-bagian struk
      bytes += await _buildHeader(
        generator,
        storeName,
        storeTagline,
        waktuBayar,
      );
      bytes += _buildItemList(generator, items);
      bytes += _buildPaymentInfo(
        generator,
        totalAmount,
        bayarAmount,
        kembalian,
        paymentMethod,
      );
      bytes += _buildFooter(generator, storeName);

      // Kirim ke printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      print('🧾 Print error: $e');
      return false;
    }
  }

  // ======================================================
  // 💰 PAYMENT INFO SECTION
  // ======================================================
  static List<int> _buildPaymentInfo(
    esc.Generator generator,
    int totalAmount,
    int bayarAmount,
    int kembalian,
    String paymentMethod,
  ) {
    List<int> bytes = [];

    // Determine payment label based on payment method
    String paymentLabel = (paymentMethod.toUpperCase() == 'TUNAI')
        ? 'TUNAI'
        : 'NON TUNAI';

    bytes += generator.row([
      esc.PosColumn(
        text: '$paymentLabel :',
        width: 8,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
      esc.PosColumn(
        text: 'Rp ${NumberFormat("#,###").format(bayarAmount)}',
        width: 4,
        styles: const esc.PosStyles(align: esc.PosAlign.right),
      ),
    ]);

    if (paymentLabel == 'TUNAI') {
      bytes += generator.row([
        esc.PosColumn(
          text: 'KEMBALI :',
          width: 8,
          styles: const esc.PosStyles(bold: true, align: esc.PosAlign.right),
        ),
        esc.PosColumn(
          text: 'Rp ${NumberFormat("#,###").format(kembalian)}',
          width: 4,
          styles: const esc.PosStyles(bold: true, align: esc.PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr(ch: "=");
    return bytes;
  }

  // Print label harga (kertas tempel, dengan command set yang sama, ada barcode juga)
  static Future<bool> printPriceLabel({
    required String productName,
    required String upc,
    required double price,
    String storeName = 'MIMBABALI_BUSANA',
  }) async {
    try {
      final profile = await esc.CapabilityProfile.load();
      final generator = esc.Generator(esc.PaperSize.mm58, profile);
      List<int> bytes = [];

      // Nama toko
      bytes += generator.text(
        storeName,
        styles: const esc.PosStyles(
          align: esc.PosAlign.center,
          height: esc.PosTextSize.size1,
          width: esc.PosTextSize.size1,
          bold: true,
        ),
      );

      // Nama produk
      bytes += generator.text(
        productName,
        styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
      );

      // Harga
      bytes += generator.text(
        'Rp ${NumberFormat("#,###").format(price)}',
        styles: const esc.PosStyles(align: esc.PosAlign.center, bold: true),
      );

      // Barcode UPC
      bytes += PostCode.barcode(barcodeData: upc);

      bytes += generator.cut();

      // Kirim ke printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      print('🏷️ Print label error: $e');
      return false;
    }
  }
}
