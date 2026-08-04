import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:path_provider/path_provider.dart';

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
  static Future<Result<String>> toExcel(List<Transaction> transactions) =>
      runCatching('Gagal export data', () async {
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

        final directory = Platform.isAndroid || Platform.isIOS
            ? await getApplicationDocumentsDirectory()
            : await getDownloadsDirectory();

        if (directory == null) {
          throw const FileSystemException('Folder unduhan tidak ditemukan');
        }

        final bytes = excel.save();
        if (bytes == null) {
          throw const FileSystemException('Excel gagal dibuat');
        }

        final path =
            '${directory.path}/Laporan_Luminara_${_fileStamp.format(DateTime.now())}.xlsx';
        await File(path).writeAsBytes(bytes);
        return path;
      });
}
