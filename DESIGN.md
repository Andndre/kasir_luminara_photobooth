# DESIGN.md — Luminara Photobooth (Aplikasi Kasir)

Sistem desain untuk redesign UI aplikasi Flutter. Dokumen ini **preskriptif**: nilai di sini langsung dipakai jadi token Dart, bukan sekadar inspirasi.

**Turunan dari:** identitas **Editorial Wine & Gold** milik luminarabali.com. Nilainya diambil dari sumbernya langsung — `resources/css/app.css` (`.catalog`) dan `resources/views/booking.blade.php` — bukan dari tabel divisi di `DESIGN.md` web yang sudah tertinggal dari situs live.
**Referensi layout:** mockup POS bernuansa kartu besar + bottom nav mengambang. Warnanya **tidak** dipakai; ritme layout, hierarki angka, dan nav mengambangnya dipakai.
**Beda penting dari referensi:** produk di aplikasi ini **tidak punya foto**. Semua kartu paket didesain typographic-first (§7).

---

## 1. Prinsip

1. **Angka dulu, dekorasi belakangan.** Total, nomor antrean, dan harga adalah elemen terbesar di layarnya masing-masing. Operator membacanya sambil berdiri.
2. **Satu bahasa visual.** Tidak ada lagi `Colors.green` / `Colors.grey[600]` di file layar. Semua warna berasal dari `AppTokens` atau `Theme.of(context).colorScheme`.
3. **Terang & gelap setara.** Booth event gelap. Dark mode bukan pelengkap — dan setiap properti tema wajib kembar (§10), kalau timpang aplikasi crash saat ganti tema.
4. **Tenang, bukan ramai.** Gradien hanya untuk 1 elemen hero per layar. Sisanya permukaan datar + border tipis.
5. **Sentuhan besar.** Target minimum 48×48. Stepper qty dan tombol bayar lebih besar lagi.
6. **Offline total.** Tidak ada aset remote. Ikon = Material Icons yang sudah ada.

---

## 2. Token Warna

### 2.1 Brand — Wine & Gold

| Token | Hex | Asal | Pakai untuk |
|---|---|---|---|
| `brand600` | `#5B1A2B` | `--cat-wine` | **Primary**: tombol utama, indikator aktif, avatar antrean |
| `wine700` | `#461320` | web `hover:` | Pressed state |
| `wine800` | `#3A0F1C` | — | Ujung gelap gradien hero |
| `brand400` | `#A63B52` | — | Primary di dark mode (wine murni terlalu gelap di atas dasar gelap) |
| `brand300` | `#C2566E` | — | Teks/ikon aksen di dark mode |
| `accent600` | `#B08D3C` | `--cat-gold` | **Gold**: label eyebrow, garis, sorotan |
| `accent500` | `#C9A227` | — | Gold terang |
| `accent400` | `#E7C97A` | web slab | Gold di atas wine / dark mode |
| `hairline` | `rgba(176,141,60,.35)` | `--cat-hair` | Border kartu & pemisah di light mode |

**Gradien hero** (hanya 1 per layar): `[#6B1E33 → #461320]` (light), `[#5B1A2B → #2A0B14]` (dark).
Gold **tidak** dipakai sebagai ujung gradien — campurannya dengan wine jadi lumpur. Gold hanya untuk teks label kecil dan garis di atas panel wine.

### 2.2 Netral — Krem & Tinta

| Token | Light | Dark |
|---|---|---|
| `bgBase` (scaffold) | `#F7F3EC` *(`--cat-ground`)* | `#14100F` |
| `bgSurface` (kartu) | `#FBF7F1` *(`--cat-ivory`)* | `#1E1917` |
| `bgSurfaceAlt` (input, kartu bertingkat) | `#F1EADF` | `#2A2320` |
| `border` | `rgba(176,141,60,.35)` | `#332B27` |
| `borderStrong` | `rgba(176,141,60,.55)` | `rgba(176,141,60,.25)` |
| `textPrimary` | `#1A1412` *(`--cat-ink`)* | `#F7F3EC` |
| `textSecondary` | `#6B625C` | `#B5A99E` |
| `textMuted` | `#9A8F86` | `#857A70` |
| `brandTint` | `#F4E8EA` | `#2E1219` |

Beda krem (`#F7F3EC`) dan ivory (`#FBF7F1`) sangat tipis — itu memang disengaja di web. Pemisah kartu dipikul oleh **garis rambut emas + bayangan lembut**, bukan oleh kontras latar. Dark mode dasarnya cokelat-tinta, bukan abu netral, supaya tetap satu keluarga dengan krem.

### 2.3 Semantik

| Peran | Solid | Tint (bg badge) | Teks di atas tint |
|---|---|---|---|
| Sukses / `COMPLETED` | `#166534` | light `#DCFCE7` · dark `#10321E` | light `#166534` · dark `#86D8A5` |
| Menunggu / `PAID` | `#92400E` | light `#FEF3C7` · dark `#3A2A0B` | light `#92400E` · dark `#E7C97A` |
| Bahaya / `CANCELLED` / hapus | `#DC2626` | light `#FEE2E2` · dark `#3D1414` | light `#991B1B` · dark `#F0A3A3` |
| Info / netral | `#2F5D62` | light `#E3EDEE` · dark `#12292B` | light `#2F5D62` · dark `#8FBFC4` |

Status pill light mode mengikuti pola web (`bg-emerald-100 text-emerald-800`, `bg-amber-100 text-amber-800`).

> **Perubahan semantik yang disengaja:** sekarang `PAID` hijau dan `COMPLETED` biru. Dibalik jadi **`PAID` = amber (menunggu dilayani, butuh aksi)** dan **`COMPLETED` = hijau (selesai)**. Ini lebih jujur secara alur kerja: yang hijau adalah yang sudah beres.

### 2.4 Palet aksen paket (pengganti thumbnail)

Enam warna hangat/editorial, dipilih deterministik dari nama paket (§7):

`#5B1A2B` wine · `#B08D3C` gold · `#A14A2A` terracotta · `#5F6B3A` olive · `#2F5D62` deep teal · `#6E3B5C` plum

Kartu paket memakai versi tint-nya (alpha 12% di light, 22% di dark) sebagai latar monogram.

### 2.5 Snippet token Dart

Sudah terimplementasi di `lib/core/preferences/tokens.dart`:

- **`AppTokens`** — warna yang sama di kedua tema (wine, gold, semantik solid, aksen paket, `heroGradient`, `packageAccent`).
- **`AppSurfaces extends ThemeExtension`** — warna yang berbeda per tema (permukaan, border, teks, tint). `copyWith` + `lerp` wajib lengkap; lihat §10.

Pemakaian: `context.surfaces.warningTint` (extension `AppSurfacesX` di file yang sama).

---

## 3. Tipografi

Web memakai **Playfair Display** (judul, serif) + **Instrument Sans** (body). Keduanya di-load dari Google Fonts CDN — aplikasi ini offline-first, jadi harus di-bundle sebagai `.ttf`.

**Status saat ini: masih Poppins.** File font brand belum ada di repo dan tidak ikut di project web (CDN). Untuk menukarnya:

1. Unduh `PlayfairDisplay-{Regular,SemiBold,Bold}.ttf` dan `InstrumentSans-{Regular,Medium,SemiBold,Bold}.ttf`.
2. Taruh di `assets/fonts/playfair/` dan `assets/fonts/instrument/`, daftarkan di `pubspec.yaml`.
3. Di `app_theme.dart`: ganti `const family = 'Poppins'` jadi dua konstanta — `bodyFamily = 'Instrument Sans'` dan `headingFamily = 'Playfair Display'`, lalu pakai `headingFamily` pada `displaySmall`/`headlineLarge`/`headlineMedium`/`headlineSmall` saja.

**Jangan** pakai serif untuk angka uang, badge, atau label form — Playfair jelek di ukuran kecil dan angka tabularnya lemah. Serif hanya untuk judul layar dan angka hero.

**Eyebrow label** (pola `--cat-eyebrow` dari web): UPPERCASE, `letter-spacing: .22em`, 11 px, warna gold. Dipakai untuk judul section ("KINERJA HARI INI", "RINGKASAN PESANAN") menggantikan judul tebal biasa.

| Style | Ukuran / Berat | Tracking | Pakai untuk |
|---|---|---|---|
| `displayNumber` | 40 / w700 | -1.0 | Nomor antrean di dialog sukses |
| `headlineLarge` | 28 / w700 | -0.5 | Total pemasukan, TOTAL di kasir |
| `headlineMedium` | 22 / w600 | -0.3 | Judul layar |
| `titleLarge` | 18 / w600 | -0.2 | Judul kartu, nama paket |
| `titleMedium` | 15 / w600 | 0 | Judul list tile, tombol |
| `bodyLarge` | 15 / w400 | 0 | Body |
| `bodyMedium` | 13 / w400 | 0 | Body sekunder |
| `labelLarge` | 13 / w600 | 0.2 | Label tombol |
| `labelMedium` | 12 / w500 | 0.3 | Label form, caption |
| `labelSmall` | 11 / w600 | 0.6 | Badge status (UPPERCASE) |

**Angka uang**: selalu `FontFeature.tabularFigures()` supaya kolom harga tidak goyang.

```dart
const money = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
```

**Aturan hierarki:** maksimal satu elemen `headlineLarge` ke atas per layar.

---

## 4. Spasi, Radius, Elevasi

### Spasi
Skala 4: `4, 8, 12, 16, 20, 24, 32, 40, 48`.
- Padding layar: **20** (mobile), **32** (desktop ≥ 1000).
- Padding dalam kartu: **16**, kartu hero **20–24**.
- Jarak antar kartu di list: **12**. Antar grup/section: **28**.

### Radius — **ganti total dari `Dimens.radius = 4`**

| Token | Nilai | Pakai |
|---|---|---|
| `rSm` | 10 | Chip, badge, input kecil |
| `rXs` | 6 | Badge status |
| `rSm` | 10 | Elemen kecil di dalam kartu |
| `rMd` | 14 | Input, kartu kecil berdiri sendiri |
| `rLg` | 18 | Kartu, dialog, bottom sheet (atas) |
| `rXl` | 24 | Kartu hero |
| `rFull` | 999 | Avatar, pil, FAB, **semua tombol** |

**Tombol berbentuk pil** (`StadiumBorder`), mengikuti CTA di web ("Pilih Portal Divisi", "Lihat Divisi"). Ini sinyal brand yang kuat — jangan diganti jadi sudut membulat biasa.

**Rumus konsentris** — `Dimens.inner(luar, padding)`, yaitu `luar = dalam + padding`:

> Berlaku **hanya untuk elemen yang benar-benar menempel di sudut dalam wadahnya.** Di aplikasi ini praktis cuma satu: pil aktif di dalam bar nav (pil tinggi 44 → radius 22, padding bar 8, jadi radius bar 30).

Elemen yang mengambang di tengah — badge, avatar, tombol, monogram — **tidak** ikut rumus ini. Memaksakannya menghasilkan bentuk yang justru terlihat salah. Untuk elemen bulat pakai `rFull`, dan persoalan radius selesai tanpa hitung-hitungan.

### Elevasi
`elevation: 0` di semua tempat. Kedalaman dibuat dengan **border + shadow ambient berwarna**:

```dart
// Light: bayangan tinta hangat (mengikuti web: 0 20px 40px -15px rgba(26,20,18,.12))
BoxShadow(color: Color(0x1F1A1412), blurRadius: 24, offset: Offset(0, 8));
// + Border.all(color: surfaces.border)  →  garis rambut emas

// Dark: TIDAK ADA shadow (tak terlihat). Cukup border #332B27.
```

Pakai `context.surfaces.cardShadow` — sudah otomatis kosong di dark mode.
Kartu hero (gradien wine) dapat bayangan lebih dalam: `Color(0x2E1A1412)`, blur `28`, offset `(0, 12)`.

---

## 5. Motion

- Durasi standar **180 ms**, kurva `Curves.easeOutCubic`.
- Transisi halaman: fade + slide-up 12 px.
- Tekan tombol: `scale 0.97` (`AnimatedScale`, 120 ms).
- **Buang** animasi `Curves.elasticOut` di bottom nav — diganti indikator pill yang bergeser 180 ms.
- Loading list = **skeleton shimmer** (kotak `surfaceAlt` beranimasi), bukan `CircularProgressIndicator` di tengah layar kosong. Spinner hanya untuk aksi modal (connect printer, cetak, verifikasi).

---

## 6. Komponen Inti

### 6.1 `AppCard`
Latar `bgSurface`, radius `rLg`, border 1px `border`, shadow ambient, padding 16. Varian:
- `AppCard.flat` — tanpa shadow (untuk kartu di dalam kartu).
- `AppCard.tappable` — ditambah `InkWell` + ripple `brand600 @ 8%`.

### 6.2 `HeroPanel`
Gradien brand, radius `rXl`, padding 20–24, teks putih, glow. **Satu per layar.** Isi: label kecil (putih 70%), angka besar, baris meta.

### 6.3 Tombol

| Varian | Bentuk |
|---|---|
| Primary | Fill `brand600`, teks putih, radius `rMd`, tinggi 52 (48 untuk yang sekunder), shadow brand 20% |
| Primary besar (bayar) | Tinggi **60**, `labelLarge` 16, lebar penuh |
| Secondary | Fill `surfaceAlt`, teks `textPrimary`, border `border` |
| Ghost | Transparan, teks `brand600` |
| Danger | Teks/border `danger`; fill merah **hanya** untuk konfirmasi hapus di dalam dialog |
| Icon button | 44×44, radius `rFull`, ripple tint |

### 6.4 Bottom Navigation (mobile) — pola dari referensi
Bar **mengambang**: margin 16 kiri/kanan, padding dalam 8, radius 30 (konsentris dengan pil), latar `bgSurface` + garis rambut + shadow ambient.

Item aktif = **pil** `brandTint` dengan **label di samping ikon** (bukan di bawahnya); item non-aktif = ikon saja `textMuted`. Label menyusut lewat `widthFactor` 1→0 supaya lebar bar tidak melompat saat pindah tab. `NavigationBar` bawaan tidak bisa begini — komponennya custom (`FloatingNavBar`).

**Jarak ke tepi bawah** (`FloatingNavBar.bottomGapFor`) — `SafeArea` polos bikin bar menggantung di HP gesture:

| Inset bawah | Kondisi | Jarak |
|---|---|---|
| 0 | tanpa system nav | 12 |
| ≤ 34 | gesture pill (Android 24, iPhone 34) | 45% inset, minimum 10 |
| > 34 | tombol navigasi 3-tombol (± 48) | inset + 4, supaya bar tidak tertimpa |

FAB tetap `centerDocked`, diameter 60, radius `rFull`, gradien brand, ikon 28 putih, glow brand 30%.

### 6.5 NavigationRail (desktop)
Lebar 88, latar `bgSurface`, border kanan 1px. Logo di atas (margin 24), FAB di bawah. Indikator terpilih = kotak `brandTint` radius `rMd`, ikon `brand600`, label 11 `w600`.

### 6.6 Chip filter — segmented track
Mengikuti pola brand doc: satu track `surfaceAlt` radius `rFull` padding 4, item aktif jadi pill `bgSurface` + shadow tipis + teks `brand600 w600`; non-aktif teks `textSecondary`. Untuk filter yang bisa meluber (rentang tanggal), pakai `ActionChip` terpisah di kanan track.

### 6.7 Badge status
Tinggi 22, radius `rSm`, padding H 8, `labelSmall` UPPERCASE, warna dari §2.3. Selalu tint + teks, **tidak pernah** fill jenuh.

### 6.8 Stepper qty
Tinggi 44, radius `rFull`, latar `surfaceAlt`. Tombol −/+ 40×40 (target sentuh 48 dengan padding), angka lebar minimum 32 tabular. Saat qty > 0: seluruh stepper berlatar `brandTint`, tombol `+` fill `brand600` putih.

### 6.9 Input
Tinggi 52, radius `rMd`, fill `surfaceAlt`, border transparan → fokus: border `brand600` 1.5px + ring `brand600 @ 15%` (pakai `BoxShadow` spread 3). Label melayang `labelMedium` warna `brand600` saat fokus.

### 6.10 Empty state
Ikon 56 dalam lingkaran `surfaceAlt` 96px → judul `titleMedium` → satu baris `bodyMedium` `textSecondary` → (opsional) tombol ghost. Rata tengah, maksimum lebar 280.

### 6.11 Error state
Sama seperti empty, tapi lingkaran `dangerTint`, ikon `danger`, plus tombol secondary "Coba Lagi".

### 6.12 Dialog & Bottom Sheet
Dialog: radius `rLg`, padding 24, tanpa elevation Material default (`backgroundColor: bgSurface`, `elevation: 0`, `shadowColor` ambient). Judul `titleLarge`, aksi rata kanan; aksi destruktif paling kiri berwarna `danger`.
Bottom sheet: radius atas `rXl`, drag handle 40×4 `borderStrong`, padding 24.

### 6.13 Skeleton
Kotak `surfaceAlt` radius `rSm`, animasi opacity 0.5 → 1.0, 900 ms bolak-balik.

---

## 7. Kartu Paket Tanpa Gambar

Masalah: referensi mengandalkan foto makanan; produk di sini hanya punya **nama + harga**. Solusinya bukan placeholder abu-abu, tapi kartu yang memang dirancang typographic.

**Anatomi (grid desktop / list mobile):**

```
┌──────────────────────────────────────────┐
│ ┌──────┐                                 │
│ │  SP  │  Self Photo 15 Menit            │   ← monogram 52×52, radius rMd,
│ └──────┘  Paket                          │     bg = aksen @12%, teks aksen w700 18
│                                          │
│  Rp 50.000            [ −   2   + ]      │   ← harga titleLarge tabular,
└──────────────────────────────────────────┘     stepper kanan
```

**Monogram:** ambil huruf pertama dari maksimal 2 kata pertama nama paket (`"Self Photo 15 Menit"` → `SP`; `"Wide Angle"` → `WA`; satu kata → 2 huruf pertama).

**Warna aksen deterministik**, supaya paket yang sama selalu berwarna sama di semua layar:

```dart
Color packageAccent(String name) =>
    AppTokens.packageAccents[name.hashCode.abs() % AppTokens.packageAccents.length];
```

**State terpilih (qty > 0):** border 1.5px warna aksen, latar kartu = aksen @ 6%, dan badge bulat kecil berisi qty di sudut kanan atas monogram.

Pola monogram yang sama dipakai ulang di ringkasan pesanan, daftar antrean, dan detail transaksi — jadi paket punya identitas visual konsisten tanpa satu pun file gambar.

---

## 8. Redesign Per Layar

### 8.1 Kasir — layar terpenting

**Desktop (2 kolom, kanan sticky 460px):**

```
┌─ Transaksi Baru ────────────────────────────┬──────────────────────────────┐
│  [ Cari paket…                          ]   │  ┌─ HeroPanel ────────────┐  │
│                                             │  │ TOTAL PEMBAYARAN       │  │
│  ┌────────────┐ ┌────────────┐              │  │ Rp 125.000             │  │
│  │ SP  Self…  │ │ WA  Wide…  │              │  │ 3 item · TUNAI         │  │
│  │ Rp50.000   │ │ Rp75.000   │              │  └────────────────────────┘  │
│  │ [− 2 +]    │ │ [− 0 +]    │              │                              │
│  └────────────┘ └────────────┘              │  Nama Pelanggan (opsional)   │
│  ┌────────────┐ ┌────────────┐              │  [                        ]  │
│  │ …          │ │ …          │              │                              │
│  └────────────┘ └────────────┘              │  Metode Pembayaran           │
│                                             │  ( TUNAI │ NON-TUNAI )       │
│                                             │                              │
│                                             │  Ringkasan                   │
│                                             │  SP Self Photo ×2  Rp100.000 │
│                                             │  WA Wide Angle ×1  Rp 25.000 │
│                                             │  ──────────────────────────  │
│                                             │  [    BAYAR & CETAK      ]   │  ← h60
└─────────────────────────────────────────────┴──────────────────────────────┘
```

Perubahan kunci: **total dipromosikan ke HeroPanel di atas** (bukan baris kecil di bawah ringkasan), grid paket 2 kolom menggantikan list satu kolom, search box ditambahkan (saat ini tidak ada di layar kasir padahal ada di layar Produk).

**Mobile:** grid paket 2 kolom mengisi layar; **bottom bar ringkas** yang menempel di bawah (mengikuti pola "2 Items / $05.75 / Next" pada referensi):

```
┌──────────────────────────────────────┐
│ ⌃  3 item · Rp 125.000    [ Lanjut ] │   ← tap ⌃ membuka sheet ringkasan
└──────────────────────────────────────┘
```
`Lanjut` membuka bottom sheet checkout (nama, metode, ringkasan, tombol bayar) — bukan menumpuk semuanya di satu kolom panjang seperti sekarang.

### 8.2 Beranda Server

Urutan baru — bisnis dulu, teknis belakangan:

```
HeroPanel:  Selamat Pagi · Rabu, 4 Feb 2026
            Rp 1.250.000
            12 transaksi hari ini

[ Antrean ]   [ Tiket Selesai ]   [ Paket ]      ← 3 stat card ringkas
     8               4                6

Server                                    ● ONLINE
192.168.1.5 : 3000 · 2 perangkat   [ Pairing QR ]   ← kartu compact 1 baris + ikon
```

Perubahan kunci: ServerMonitor turun ke bawah dan dipadatkan jadi satu kartu status (badge titik warna + ringkasan satu baris). Saat offline, kartu ini melebar dan menampilkan tombol primary "Nyalakan Server". Kartu "Mode Aplikasi" dibuang dari statistik — pindah jadi teks kecil di Setelan.

### 8.3 Transaksi

```
HeroPanel: Total Pemasukan (Hari Ini)  ·  Rp 1.250.000  ·  12 transaksi
[ Semua │ Hari Ini │ Kemarin │ Bulan Ini ]  [ 📅 Rentang ]     ← segmented track

┌ #12  Budi Santoso                       Rp 45.000 ┐
│      SP Self Photo ×1 · TUNAI                     │
│      04 Feb · 14:20            [ PAID ]           │
└───────────────────────────────────────────────────┘
```
Nomor antrean jadi avatar `brandTint` di kiri. Di **desktop ≥ 1000 px** gunakan **tabel** (Antrean · Pelanggan · Item · Metode · Waktu · Status · Total), bukan grid kartu — kepadatan data desktop yang selama ini terbuang.

### 8.4 Produk
Grid kartu monogram (§7) tanpa stepper; aksi Edit/Hapus muncul sebagai ikon di kanan (desktop: on-hover; mobile: selalu tampil). Tombol tambah = FAB kecil ekstensi "Tambah Paket" di kanan bawah konten.

### 8.5 Setelan
Grup kartu, bukan list telanjang: tiap grup = `AppCard` dengan judul di luar kartu (`labelMedium`, `textMuted`, UPPERCASE). Header profil jadi baris ringkas (ikon app 48 + nama + versi). Tombol "Keluar Aplikasi" = ghost danger, bukan outline penuh.

### 8.6 Beranda Verifier
HeroPanel berubah warna sesuai koneksi: terhubung → gradien brand; terputus → gradien tinta netral (`#3D332F → #1A1412`) dengan tombol "Hubungkan" di dalamnya. Grid Menu Cepat jadi 2×2 kartu dengan halo ikon `brandTint`. Chip status koneksi di AppBar memakai badge titik + teks (§6.7).

### 8.7 Antrean Live
Kartu antrean: avatar nomor antrean besar (48, `brandTint`, angka `titleLarge`), nama, waktu, daftar item dengan monogram mini, badge `PAID`. Tap → bottom sheet verifikasi. Item yang baru masuk lewat WebSocket muncul dengan animasi slide-in + kilat `brandTint` 600 ms.

### 8.8 Scanner
Kamera fullscreen + overlay: area gelap 55% dengan **lubang bidik 260×260** radius `rLg`, sudut siku brand 3px sepanjang 28px, garis pemindai beranimasi vertikal. Instruksi di bawah lubang dengan latar pill hitam 60% supaya terbaca di atas video apa pun. Hasil scan = **bottom sheet**, bukan AlertDialog: ikon besar sukses/gagal, data pelanggan, item, tombol lebar penuh.

### 8.9 Dialog Pembayaran Tunai
Total tagihan di panel `brandTint` radius `rLg`; chip nominal jadi grid 3 kolom tinggi 48; input manual besar (`headlineMedium`, tabular); baris kembalian menonjol — hijau bila cukup, merah bila kurang, dengan `AnimatedSwitcher` saat nilainya berubah.

### 8.10 Dialog Pembayaran Berhasil
Fokus tunggal: **nomor antrean**.
```
        ✓  (lingkaran successTint 72)
        ANTREAN
        #12                  ← displayNumber 40
        Budi Santoso
   ┌─────────────────┐
   │   [ QR 180px ]  │       ← kartu putih radius rLg, selalu putih di dark mode
   └─────────────────┘
   Total  Rp 125.000 · Kembali Rp 5.000
   [        Selesai        ]
```
QR **wajib** di atas latar putih murni di kedua tema — QR gelap tidak terbaca scanner.

---

## 9. Struk Thermal

Tidak berubah desainnya (ESC/POS 58/80 mm, teks + QR). Yang selaras dengan redesign hanya hierarki teks: nomor antrean dicetak paling besar (`size2`), lalu kode tiket, lalu rincian. Jangan menambah elemen grafis.

---

## 10. Aturan Dark Mode & Paritas Tema (wajib)

Melanggar ini = crash `Failed to interpolate TextStyles` saat ganti tema.

1. `LightTheme` dan `DarkTheme` harus mendefinisikan **himpunan properti yang identik** — setiap `TextStyle`, border, `hintStyle`, `labelStyle`, `contentPadding` ada di keduanya.
2. Setiap `TextStyle` menyebut `fontFamily: 'Poppins'` secara eksplisit, meski sudah ada di `ThemeData.fontFamily`.
3. `AppSurfaces` (`ThemeExtension`) wajib mengimplementasikan `lerp()` untuk **semua** field; field yang di-`lerp` dengan `?? other.x` menyebabkan lompatan warna saat animasi tema.
4. Dark mode: **tanpa** `BoxShadow`; kedalaman lewat border.
5. Yang selalu putih apa pun temanya: latar QR code, area cetak preview.
6. Kontras teks minimum 4.5:1 terhadap latarnya. `textMuted` dark (`#64748B`) hanya untuk teks non-esensial.

---

## 11. Peta Implementasi

| Berkas | Aksi |
|---|---|
| `lib/core/preferences/tokens.dart` | **Baru** — `AppTokens` + `AppSurfaces` ThemeExtension |
| `lib/core/preferences/colors.dart` | Deprecate; `AppColors.primary` → alias `AppTokens.brand600` selama migrasi |
| `lib/core/preferences/dimens.dart` | Tambah `rSm/rMd/rLg/rXl/rFull`; `radius = 4` ditinggalkan |
| `lib/core/preferences/theme/{light,dark}_theme.dart` | Tulis ulang dengan token + daftarkan `AppSurfaces` di `extensions` |
| `lib/core/components/` | **Baru**: `app_card.dart`, `hero_panel.dart`, `status_badge.dart`, `qty_stepper.dart`, `segmented_filter.dart`, `empty_state.dart`, `error_state.dart`, `skeleton.dart`, `package_monogram.dart` |
| `lib/features/home/pages/main/main.dart` | Bottom nav → `NavigationBar` mengambang; buang `_NavItem` + animasi elastic |
| `lib/features/kasir/pages/kasir.dart` | Grid paket + HeroPanel total + sheet checkout mobile |
| `lib/features/home/pages/home/page.dart` | Urutan ulang; ServerMonitor dipadatkan |
| `lib/features/transaction/pages/index/` | Segmented filter + tabel desktop |
| `lib/features/verifier/pages/scanner_page.dart` | Overlay bidik + hasil jadi bottom sheet |
| Semua layar | Hapus `Colors.*` literal → token |

**Urutan kerja yang disarankan:** token & tema → komponen inti → Kasir → Beranda Server → Transaksi → Verifier → sisanya. Setiap tahap harus tetap bisa `flutter analyze` bersih dan tema bisa di-toggle tanpa crash.

---

## 12. Jangan

- Jangan pakai glassmorphism/`backdrop-blur` di list yang panjang — mahal di Android kelas bawah. Blur hanya di bottom nav mengambang.
- Jangan menambah paket animasi (Lottie/Rive). Cukup widget animasi bawaan.
- Jangan pakai `Colors.green/red/blue` langsung di file layar.
- Jangan pakai gradien lebih dari satu elemen per layar.
- Jangan mengecilkan target sentuh di bawah 48 px demi kepadatan.
- Jangan menghapus kemampuan yang ada (export Excel, backup/restore, ukuran kertas, pairing QR, ganti mode) demi tampilan lebih bersih.
