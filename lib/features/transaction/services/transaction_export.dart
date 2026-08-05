import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';

/// Dibatalkan lewat dialog simpan — keluar biasa, bukan kegagalan.
class ExportCancelled implements Exception {
  const ExportCancelled();
}

/// Writes the transaction list to an .xlsx report.
///
/// Lifted out of the history screen's widget code so the spreadsheet layout can
/// change without touching the UI.
class TransactionExport {
  const TransactionExport._();

  static final _date = DateFormat('yyyy-MM-dd');
  static final _time = DateFormat('HH:mm:ss');
  static final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  /// Returns the path of the saved file.
  static Future<Result<String>> toExcel(
    List<Transaction> transactions,
  ) => runCatching('Gagal export data', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan'];

    sheet.appendRow([
      TextCellValue('UUID'),
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('Pelanggan'),
      TextCellValue('Rincian Produk'),
      TextCellValue('Harga Total'),
      TextCellValue('Metode'),
      TextCellValue('Status'),
      TextCellValue('Waktu Redeem'),
    ]);

    for (final t in transactions) {
      sheet.appendRow([
        TextCellValue(t.uuid),
        TextCellValue(_date.format(t.createdAt)),
        TextCellValue(_time.format(t.createdAt)),
        TextCellValue(t.customerName ?? '-'),
        TextCellValue(
          t.items.map((i) => '${i.productName} (x${i.quantity})').join(', '),
        ),
        IntCellValue(t.totalPrice),
        TextCellValue(t.paymentMethod.dbValue),
        TextCellValue(t.status.dbValue),
        TextCellValue(
          t.redeemedAt == null
              ? '-'
              : '${_date.format(t.redeemedAt!)} ${_time.format(t.redeemedAt!)}',
        ),
      ]);
    }

    final saved = excel.save();
    if (saved == null) {
      throw const FileSystemException('Excel gagal dibuat');
    }
    final bytes = Uint8List.fromList(saved);

    // Kontrak saveFile berlawanan per platform — lihat BackupService.export:
    // di mobile `bytes` wajib dan plugin yang menulis, di desktop `bytes`
    // diabaikan dan kita sendiri yang menulis ke path yang dipilih.
    final isMobile = Platform.isAndroid || Platform.isIOS;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Laporan',
      fileName: 'Laporan_Luminara_${_fileStamp.format(DateTime.now())}.xlsx',
      // Android menerjemahkan filter ekstensi lewat MimeTypeMap yang sering
      // tidak punya entri "xlsx", dan pickernya lalu error. Sama seperti backup.
      type: isMobile ? FileType.any : FileType.custom,
      allowedExtensions: isMobile ? null : const ['xlsx'],
      bytes: isMobile ? bytes : null,
    );

    if (path == null) throw const ExportCancelled();

    if (!isMobile) await File(path).writeAsBytes(bytes);

    return path;
  });
}
