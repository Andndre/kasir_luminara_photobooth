/// Satu tempat yang menerjemahkan status HTTP jadi kalimat untuk kasir.
///
/// Ada karena 7 Agustus 2026 sebuah 403 sampai ke layar sebagai "Server tidak
/// dapat dihubungi" — padahal servernya menjawab, dan yang menolak justru
/// firewall di depannya. Salah label itu mengirim orang memburu masalah
/// jaringan selama satu malam.
///
/// Tiga pemanggil menyalin logika ini sendiri-sendiri sebelumnya; kalau
/// dibiarkan, yang satu diperbaiki dan dua lainnya tetap berbohong.
String serverErrorMessage(int statusCode) => switch (statusCode) {
  401 => 'Sesi berakhir, silakan masuk lagi',

  // Tidak satu pun rute /pos/* menjawab 403 dari Laravel. Kalau muncul,
  // penolaknya ada di depan Laravel — Cloudflare atau firewall hosting — dan
  // biasanya memblokir seluruh jaringan venue, bukan akun ini.
  403 =>
    'Ditolak firewall server (403), bukan masalah akun. '
        'Coba lewat jaringan lain, misalnya hotspot HP.',

  429 => 'Terlalu banyak permintaan. Tunggu semenit lalu coba lagi.',
  >= 500 && < 600 => 'Server sedang bermasalah ($statusCode)',
  _ => 'Server menolak permintaan ($statusCode)',
};
