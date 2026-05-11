# Planning Implementasi: Filter Rentang Tanggal pada Riwayat Transaksi

## 1. Deskripsi Fitur
**Request:** Mengganti "Pilih Bulan" menjadi "Rentang Tanggal" sehingga user dapat memilih tanggal awal dan tanggal akhir secara manual.

**Target File:**
- `lib/features/transaction/pages/index/page.dart` (modifikasi utama)
- `pubspec.yaml` (update versi)
- `windows/installer.iss` (update versi installer)

---

## 2. Analisis Kode Saat Ini

### Struktur yang Relevan:
```
page.dart:
├── _TransactionPageState
│   ├── _selectedDateRange: DateTimeRange?
│   ├── _filterLabel: String
│   ├── _applyFilter(label, range)
│   ├── _showMonthPicker()         ← PERLU DIGANTI
│   └── _buildFilterHeader(theme)
│       └── ActionChip "Pilih Bulan" → _showMonthPicker()
```

### Fungsi yang Perlu Dimodifikasi:
1. `_showMonthPicker()` → `_showDateRangePicker()`
2. `_buildFilterHeader()` → update ActionChip label

---

## 3. Tahapan Implementasi

### Tahap 1: Persiapan
1. Pastikan branch saat ini bersih (`git status`)
2. Buat branch baru: `git checkout -b feature/date-range-filter`

### Tahap 2: Modifikasi `page.dart`

#### 2.1 Hapus fungsi `_showMonthPicker()` dan ganti dengan `_showDateRangePicker()`

**Kode lama (hapus):**
```dart
Future<void> _showMonthPicker() async {
  try {
    final months = await Transaksi.getAvailableTransactionMonths();

    if (!mounted) return;

    if (months.isEmpty) {
      SnackBarHelper.showWarning(context, 'Belum ada data transaksi.');
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Pilih Bulan Laporan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final date = months[index];
                  final label = DateFormat('MMMM yyyy', 'id_ID').format(date);

                  return ListTile(
                    title: Text(label, textAlign: TextAlign.center),
                    onTap: () {
                      // Create range for full month
                      final start = DateTime(date.year, date.month, 1);
                      final end = DateTime(date.year, date.month + 1, 0);

                      _applyFilter(
                        label,
                        DateTimeRange(start: start, end: end),
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  } catch (e) {
    if (mounted) {
      Log.insertLog('Gagal memuat data bulan: $e', isError: true);
      SnackBarHelper.showError(context, 'Gagal memuat data bulan: $e');
    }
  }
}
```

**Kode baru (tambahkan):**
```dart
Future<void> _showDateRangePicker() async {
  try {
    // Gunakan DatePicker untuk memilih rentang tanggal
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), // Tanggal awal minimum
      lastDate: DateTime.now(),  // Tanggal akhir maksimum
      initialDateRange: _selectedDateRange, // Gunakan range saat ini jika ada
      helpText: 'Pilih Rentang Tanggal',
      confirmText: 'Pilih',
      cancelText: 'Batal',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Format label untuk display
      final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
      final label = '${dateFormatter.format(picked.start)} - ${dateFormatter.format(picked.end)}';

      _applyFilter(label, picked);
    }
  } catch (e) {
    if (mounted) {
      Log.insertLog('Gagal membuka date picker: $e', isError: true);
      SnackBarHelper.showError(context, 'Gagal membuka date picker: $e');
    }
  }
}
```

#### 2.2 Update `_buildFilterHeader()` - Ganti ActionChip label

**Cari bagian ini:**
```dart
ActionChip(
  avatar: const Icon(Icons.calendar_view_month, size: 16),
  label: const Text('Pilih Bulan'),
  onPressed: _showMonthPicker,
  backgroundColor: theme.cardTheme.color,
  side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
),
```

**Ganti menjadi:**
```dart
ActionChip(
  avatar: const Icon(Icons.date_range, size: 16),
  label: const Text('Rentang Tanggal'),
  onPressed: _showDateRangePicker,
  backgroundColor: theme.cardTheme.color,
  side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
),
```

#### 2.3 (Opsional) Hapus import yang tidak perlu
Jika `Transaksi.getAvailableTransactionMonths()` tidak digunakan di tempat lain, hapus import atau abaikan saja (tidak critical).

---

### Tahap 3: Testing Manual

1. Jalankan aplikasi: `flutter run`
2. Navigasi ke halaman **Riwayat Transaksi**
3. Test skenario:
   - [ ] Klik "Rentang Tanggal" → DateRangePicker muncul
   - [ ] Pilih tanggal awal dan akhir → Filter diterapkan
   - [ ] Label filter berubah sesuai range yang dipilih
   - [ ] Data transaksi difilter sesuai range tanggal
   - [ ] Tombol filter lain tetap berfungsi
   - [ ] Scroll dan navigasi tetap normal

---

### Tahap 4: Commit & Tag Version

#### 4.1 Update Version di `pubspec.yaml`
Ubah version dari `1.2.6+2004` menjadi `1.2.7+2005`:
```yaml
version: 1.2.7+2005
```

#### 4.2 Update Version di `windows/installer.iss`
Ubah `MyAppVersion` dari `"1.2.6"` menjadi `"1.2.7"`:
```iss
#define MyAppVersion "1.2.7"
```

#### 4.3 Commit
```bash
git add .
git commit -m "feat(transaction): replace month picker with date range picker

- Changed 'Pilih Bulan' filter to 'Rentang Tanggal'
- Added _showDateRangePicker() using Flutter's showDateRangePicker
- Updated filter label display to show selected date range
- Updated version to 1.2.7"
```

#### 4.4 Tag & Push
```bash
git tag -a v1.2.7 -m "Release 1.2.7 - Date range filter for transactions"
git push origin feature/date-range-filter
git push origin v1.2.7
```

---

## 4. Checklist Implementasi

| No | Task | Status |
|----|------|--------|
| 1 | Buat branch `feature/date-range-filter` | ☐ |
| 2 | Implementasi `_showDateRangePicker()` | ☐ |
| 3 | Update ActionChip label di `_buildFilterHeader()` | ☐ |
| 4 | Testing manual di emulator/device | ☐ |
| 5 | Update version di `pubspec.yaml` | ☐ |
| 6 | Update version di `windows/installer.iss` | ☐ |
| 7 | Commit dengan message yang jelas | ☐ |
| 8 | Push tag `v1.2.7` | ☐ |

---

## 5. Catatan Penting

1. **Flutter's `showDateRangePicker`** sudah termasuk dalam framework, tidak perlu package tambahan.
2. Pastikan `context` valid dengan cek `mounted` sebelum menggunakan Navigator/State.
3. Format tanggal menggunakan locale Indonesia (`id_ID`) untuk konsistensi dengan UI lainnya.
4. `firstDate` diset ke `DateTime(2020)` sebagai batas minimum - sesuaikan jika perlu.
5. Jangan lupa build ulang setelah perubahan: `flutter build apk --release` (Android) atau sesuai target.

---

## 6. Estimasi Waktu
- Development: ~15-30 menit
- Testing: ~10 menit
- Total: ~30-45 menit