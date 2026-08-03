# PRD — Luminara Photobooth (untuk Redesign UI)

**Versi aplikasi saat ini:** 1.2.8+2006
**Platform:** Flutter (Android, Windows, Linux)
**Bahasa UI:** Bahasa Indonesia (beberapa string masih Inggris — lihat §9)
**Tujuan dokumen:** memberi konteks lengkap produk + inventaris layar/komponen supaya UI bisa didesain ulang tanpa mengubah alur bisnis.

---

## 1. Ringkasan Produk

Luminara Photobooth adalah sistem POS + manajemen antrean untuk usaha photobooth. Aplikasi jalan di jaringan lokal (LAN), tanpa internet, kecuali saat pakai pembayaran non-tunai Midtrans.

Satu aplikasi, dua peran yang bisa ditukar kapan saja tanpa restart:

| Peran | Dipakai oleh | Fungsi |
|---|---|---|
| **Server (Kasir)** | Operator kasir di meja depan | Jual paket, terima pembayaran, cetak tiket QR, host server HTTP/WebSocket di port 3000 |
| **Client (Verifier)** | Petugas di booth | Terhubung ke server via IP/QR, lihat antrean live, scan tiket pelanggan untuk redeem |

### Alur bisnis inti

```
Pelanggan pesan paket
  → Kasir pilih paket + qty, isi nama (opsional), pilih TUNAI / NON-TUNAI
  → Bayar (dialog uang tunai + kembalian, atau WebView Midtrans)
  → Transaksi tersimpan, dapat NOMOR ANTREAN harian + kode tiket 8 karakter
  → Struk thermal tercetak (berisi QR), laci kas terbuka bila tunai
  → Server broadcast REFRESH_QUEUE ke semua Verifier
  → Petugas booth scan QR tiket → status PAID jadi COMPLETED
```

### Target pengguna

Pemilik photobooth, EO, studio foto. Operator bukan orang teknis; dipakai berdiri, cepat, sering di ruangan terang/gelap, kadang di tablet Android, kadang di laptop Windows.

---

## 2. Konteks Pemakaian (penting untuk desain)

| Faktor | Kondisi nyata |
|---|---|
| Perangkat kasir | Laptop/mini PC Windows atau Linux, layar 13"–24", pakai mouse |
| Perangkat verifier | HP/tablet Android, dipegang satu tangan, kamera dipakai untuk scan |
| Pencahayaan | Booth event sering gelap → dark mode dipakai serius, bukan pelengkap |
| Kecepatan | Antrean panjang saat event. Transaksi ideal < 15 detik dari buka kasir sampai struk keluar |
| Sentuhan | Beberapa unit kasir pakai layar sentuh → target sentuh minimal 44×44 |
| Koneksi | Tidak ada internet. Semua data lokal SQLite |

---

## 3. Peta Navigasi & Inventaris Layar

Breakpoint saat ini: **> 700 px = desktop** (NavigationRail kiri), **≤ 700 px = mobile** (BottomAppBar + FAB tengah bertakik). Konten dibatasi `maxWidth: 1200`.

### 3.1 Umum (kedua mode)

| Layar | File | Isi |
|---|---|---|
| **Splash** | `lib/features/settings/pages/splash/pages.dart` | Logo, judul "Luminara Photobooth", LinearProgressIndicator, teks status. Delay ~2.5 detik |
| **Mode Selection** | `lib/features/mode_selection/mode_selection_page.dart` | Dua kartu besar: SERVER (KASIR) dan CLIENT (VERIFIER), masing-masing ikon + deskripsi. Lebar kartu fix 400 |
| **Setelan** | `lib/features/settings/pages/index/page.dart` | Header profil (ikon app, nama app, versi+build), grup: Pengaturan Perangkat (Printer, Metode Pembayaran + Switch), Tampilan (Mode Gelap + Switch), Info Lainnya (Kebijakan Privasi, Backup & Restore, Logs), tombol outline merah "Keluar Aplikasi" |
| **Printer** | `lib/features/settings/pages/printer/page.dart` | Banner status koneksi (hijau/merah), tombol "Print Test Receipt", list perangkat Bluetooth ter-pair; tiap item punya SegmentedButton ukuran kertas 58mm/80mm per printer |
| **Backup & Restore** | `lib/features/settings/pages/backup/page.dart` | Dua kartu: Backup (export JSON) dan Restore (import JSON, peringatan merah data terhapus) |
| **Logs** | `lib/features/settings/pages/logs/logs.dart` | Daftar log timestamp + pesan; pesan error berwarna merah. Grid di desktop, list di mobile |
| **Kebijakan Privasi** | `lib/features/settings/pages/privacy_policy/page.dart` | Teks statis |

### 3.2 Mode Server (Kasir) — 4 tab + FAB

| Tab | Layar | Isi utama |
|---|---|---|
| 1. Beranda | `lib/features/home/pages/home/page.dart` | **ServerMonitor** (status server, IP, port, jumlah client, tombol Start Server / Pairing QR) + banner sapaan bergradien (Selamat Pagi/Siang/Sore/Malam + tanggal) + "Kinerja Hari Ini" (kartu Pemasukan, kartu Antrean) + "Statistik Cepat" (Total Produk, Mode Aplikasi) |
| 2. Transaksi | `lib/features/transaction/pages/index/page.dart` | Kartu total pemasukan bergradien, baris chip filter (Semua Data / Hari Ini / Kemarin / Bulan Ini / Rentang Tanggal), daftar transaksi. Aksi AppBar: Export Excel, Refresh |
| 3. Produk | `lib/features/product/pages/index/page.dart` | Search box, daftar paket (nama + harga, aksi edit/hapus), tombol + di AppBar → dialog tambah |
| 4. Setelan | (§3.1) | |
| **FAB** | `lib/features/kasir/pages/kasir.dart` | Buka layar Kasir (transaksi baru) |

**Layar Kasir** (paling penting, paling sering dipakai):
- Desktop: dua kolom — kiri daftar paket dengan stepper qty (− angka +), kanan kartu checkout lebar 450.
- Mobile: paket di atas, checkout menumpuk di bawah.
- Checkout berisi: input Nama (opsional) → SegmentedButton TUNAI / NON-TUNAI → ringkasan pesanan → TOTAL PEMBAYARAN → tombol besar "BAYAR" / "BAYAR & CETAK TIKET".

### 3.3 Mode Client (Verifier) — 4 tab + FAB

| Tab | Layar | Isi utama |
|---|---|---|
| 1. Beranda | `lib/features/verifier/pages/home/page.dart` | Chip status koneksi di AppBar (Online/Connecting/Error/Offline), banner gradien status server, grid "Menu Cepat" 4 kartu (Scan Tiket, Antrean Live, Status Koneksi, Pengaturan) |
| 2. Antrean | `lib/features/verifier/pages/live_queue_page.dart` | Daftar tiket PAID real-time: avatar nomor antrean, nama pelanggan, jam, rincian item, kode UUID. Tap → bottom sheet konfirmasi verifikasi |
| 3. Koneksi | `lib/features/verifier/pages/handshake_page.dart` | Bila belum terhubung: input Server IP + tombol Hubungkan + "ATAU" + Scan Pairing QR. Bila terhubung: info IP + tombol Putuskan Koneksi |
| 4. Setelan | (§3.1) | |
| **FAB** | `lib/features/verifier/pages/scanner_page.dart` | Kamera fullscreen `MobileScanner`, hasil muncul sebagai dialog VALID (hijau) / TIDAK VALID (merah) |

---

## 4. Dialog & Sheet (bagian yang paling sering dilihat operator)

| Dialog | Konteks | Isi |
|---|---|---|
| **Pembayaran Tunai** | Kasir, setelah tekan BAYAR | Box total tagihan, ChoiceChip saran nominal (uang pas + pembulatan 5rb/10rb/20rb/50rb/100rb, maks 6 opsi), input manual, baris Kembalian (merah bila kurang), tombol BAYAR & CETAK |
| **Pembayaran Berhasil** | Setelah transaksi tersimpan | Ikon centang, **ANTRIAN #n** besar, bayar & kembalian (bila tunai), QR tiket 200×200, total, nama pelanggan, rincian item, tombol Selesai |
| **Detail Transaksi** | Tap item di tab Transaksi | Nomor antrean, kode, Order ID Midtrans (bila ada), nama, metode, status, waktu buat/redeem, rincian item, total, bayar/kembali, QR 150×150. Aksi: Hapus (merah), Cetak Tiket, Tutup |
| **Pairing QR** | ServerMonitor | QR berisi `IP:PORT` + teks IP:PORT |
| **Verifikasi tiket** (bottom sheet) | Antrean Live | Avatar nomor antrean, nama, daftar layanan, tombol VERIFIKASI SEKARANG (dengan state loading), Batal |
| **Hasil Scan** | Scanner | Ikon besar hijau/merah, data pelanggan, paket dibeli, banner konfirmasi COMPLETED, tombol OK lebar penuh |
| **WebView Midtrans** | Non-tunai + Midtrans aktif | Dialog di Android, jendela pop-up di Windows/Linux. Status di-polling tiap 3 detik |
| Konfirmasi hapus produk / transaksi, Restore data, Putuskan koneksi, Keluar aplikasi | — | AlertDialog standar, aksi destruktif merah |

---

## 5. Status & State yang Harus Punya Representasi Visual

- **Server:** offline / online (IP, port, jumlah client terhubung), error message.
- **Verifier:** disconnected / connecting / connected / error.
- **Printer:** connected (nama printer) / not connected; ukuran kertas 58mm atau 80mm per printer.
- **Transaksi:** `PAID` (hijau), `COMPLETED` (biru), `CANCELLED` (merah).
- **Metode bayar:** TUNAI, NON-TUNAI, QRIS, GoPay, ShopeePay, Akulaku, Kredivo, Bank Transfer (VA) — teks bisa panjang, harus muat.
- **Loading:** ada di hampir semua layar (list, dialog printing, connecting, verifying).
- **Empty state:** "Belum ada transaksi", "Tidak ada paket.", "Tidak ada antrean saat ini.", "Tidak ada log.", "Belum ada produk dipilih", "No paired bluetooth devices found".
- **Error state:** gagal ambil antrean (ikon cloud_off + tombol Coba Lagi), gagal cetak, gagal export, ErrorWidget global (layar merah "Terjadi Kesalahan UI!").

---

## 6. Sistem Desain Saat Ini (baseline yang boleh diganti)

**Warna** — `lib/core/preferences/colors.dart`
- Primary `#3059E8` (biru)
- Merah `#EB4755`, Kuning `#FFD101`, Oranye `#FF722C`
- Teks disabled `#A6A6A6`, background terang `#FAFAFA`

**Tipografi** — Poppins (bundled). Skala: 32 / 24 / 20 / 16 / 14 / 12.

**Bentuk** — `Dimens.radius = 4.0` (sangat kecil), `radiusMedium = 8.0`. Spasi kelipatan 4 (dp4…dp50), default 16.

**Material 3** aktif, tapi banyak widget masih di-styling manual per layar (warna hardcode `Colors.green`, `Colors.blue`, `Colors.grey[600]`, gradien lokal). Ini salah satu masalah utama yang perlu dibereskan redesign.

---

## 7. Masalah UI yang Ingin Diperbaiki

1. **Tidak konsisten.** Tiap layar bikin kartunya sendiri (shadow, radius, padding beda-beda). Kartu statistik di Beranda, kartu menu di Verifier, dan kartu transaksi tidak satu bahasa.
2. **Warna hardcode.** `Colors.green/blue/red/grey` tersebar di banyak file, jadi dark mode kelihatan tambal sulam dan kontras kadang gagal.
3. **Radius 4px terasa kaku** dibanding gaya aplikasi POS modern.
4. **Hierarki lemah di layar Kasir.** Total pembayaran dan tombol bayar kurang dominan; qty stepper kecil untuk layar sentuh.
5. **Beranda Server penuh tapi kurang informatif** — cuma 4 angka, tanpa tren/grafik, sementara ServerMonitor teknis mendominasi bagian atas.
6. **Nomor antrean** — informasi terpenting bagi pelanggan — hanya muncul di dialog, ukurannya belum menonjol di daftar antrean/transaksi.
7. **Bottom navigation mobile** memakai label 8px yang hampir tidak terbaca dan animasi `elasticOut` yang berlebihan.
8. **Bahasa campur** Indonesia–Inggris ("Server Dashboard", "Start Server", "Pairing QR", "Connected to…", "Select Mode").
9. **Kepadatan desktop rendah** — layout mobile diregangkan ke lebar 1200 tanpa memanfaatkan ruang (mis. tabel transaksi).

---

## 8. Sasaran Redesign

**Harus:**
- Satu design system: token warna, tipografi, radius, elevation, spacing — semua layar memakainya.
- Light & dark mode paritas penuh (dark mode dipakai di booth gelap).
- Layar Kasir bisa diselesaikan cepat, tombol dan angka besar, ramah layar sentuh.
- Nomor antrean & status tiket terbaca dari jarak pandang berdiri.
- Responsif nyata: mobile (≤700), tablet, desktop lebar — bukan sekadar meregangkan.
- Semua state di §5 punya tampilan yang dirancang, termasuk empty & error.
- Konsisten Bahasa Indonesia.

**Boleh:**
- Ganti palet, tipografi, radius, gaya ikon, pola navigasi (selama tab/aksi §3 tetap terjangkau).
- Rombak layout Beranda, tambahkan visualisasi data ringkas.

**Jangan:**
- Mengubah alur bisnis, jumlah langkah pembayaran, atau isi data tiket/struk.
- Menghapus kemampuan: export Excel, backup/restore, pilih ukuran kertas printer, pairing QR, mode gelap, ganti mode server/client.
- Mengandalkan komponen yang butuh internet (ikon remote, font web runtime, ilustrasi CDN).

---

## 9. Batasan Teknis untuk Desainer

| Batasan | Konsekuensi desain |
|---|---|
| Flutter Material 3 | Pakai komponen Material yang ada bila memungkinkan; custom painting mahal untuk dirawat |
| Offline penuh | Semua aset (font, ikon, ilustrasi) harus di-bundle |
| Font ter-bundle: Poppins + CustomIcons | Ganti font berarti menambah file `.ttf` ke `assets/fonts/` |
| Dark & light theme harus punya properti identik | Bila light punya `hintStyle`, dark wajib punya juga — kalau tidak, aplikasi crash saat ganti tema |
| Struk thermal 58mm / 80mm ESC/POS | Tidak bisa didesain grafis bebas: hanya teks monospace, QR, dan garis |
| Kamera fullscreen untuk scanner | Overlay scanner harus kontras di atas video apa pun |
| Desktop pakai mouse, `dragDevices` mouse tidak diaktifkan | Jangan mengandalkan gestur swipe di desktop |
| Nomor antrean reset harian, kode tiket 8 karakter A–Z0–9 | Slot teks: `#123` dan `A1B2C3D4` |
| Mata uang Rupiah tanpa desimal (`Rp 1.250.000`) | Angka bisa panjang, hindari kolom sempit |

---

## 10. Deliverable yang Diharapkan dari Redesign

1. **Token & style guide**: palet light/dark, skala tipografi, radius, elevation, spacing, ukuran ikon.
2. **Komponen inti**: app bar, navigation rail + bottom nav, kartu statistik, kartu transaksi/antrean, stepper qty, chip filter, chip status, banner status koneksi, tombol primer/destruktif, empty state, error state, dialog, bottom sheet.
3. **Mockup layar** (light + dark, mobile + desktop) untuk: Kasir, Beranda Server, Transaksi, Produk, Setelan, Beranda Verifier, Antrean Live, Koneksi, Scanner, dan 3 dialog kunci (Pembayaran Tunai, Pembayaran Berhasil, Hasil Scan).
4. Catatan pemetaan ke widget Flutter agar implementasi tidak menebak.

Referensi tampilan saat ini: `docs/screenshots/` (dashboard, transaction, products, scanner, settings).
