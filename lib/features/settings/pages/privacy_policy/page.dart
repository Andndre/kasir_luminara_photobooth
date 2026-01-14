import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String routeName = '/privacy-policy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.privacy_tip, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Kebijakan Privasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kasir Mimba Bali',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            _buildSection('1. Informasi yang Kami Kumpulkan', [
              '• Data Transaksi: Informasi penjualan, produk, harga, dan pembayaran',
              '• Data Produk: Nama produk, kategori, stok, dan harga',
              '• Data Penggunaan: Statistik penggunaan aplikasi untuk perbaikan layanan',
              '• Data Perangkat: Informasi perangkat untuk kompatibilitas dan troubleshooting',
            ]),

            _buildSection('2. Bagaimana Kami Menggunakan Informasi', [
              '• Memproses transaksi penjualan',
              '• Mengelola inventori dan stok produk',
              '• Menghasilkan laporan penjualan dan statistik bisnis',
              '• Menyimpan riwayat transaksi untuk keperluan bisnis',
              '• Memperbaiki dan meningkatkan kualitas aplikasi',
            ]),

            _buildSection('3. Penyimpanan Data', [
              '• Lokal: Semua data disimpan secara lokal di perangkat Anda',
              '• Keamanan: Data dilindungi dengan enkripsi database SQLite',
              '• Backup: Kami menyarankan backup data secara berkala',
              '• Tidak ada Cloud: Data tidak dikirim ke server eksternal',
            ]),

            _buildSection('4. Berbagi Informasi', [
              '• Kami TIDAK membagikan data pribadi kepada pihak ketiga',
              '• Data hanya digunakan untuk operasional aplikasi',
              '• Tidak ada integrasi dengan platform analytics eksternal',
              '• Data tetap menjadi milik penuh pengguna',
            ]),

            _buildSection('5. Hak Pengguna', [
              '• Akses: Anda memiliki akses penuh ke semua data',
              '• Hapus: Anda dapat menghapus data kapan saja',
              '• Export: Data dapat diekspor untuk backup',
              '• Kontrol: Penuh kontrol atas data bisnis Anda',
            ]),

            _buildSection('6. Keamanan Data', [
              '• Enkripsi database lokal',
              '• Tidak ada transmisi data melalui internet',
              '• Perlindungan dengan password perangkat',
              '• Update keamanan berkala',
            ]),

            _buildSection('7. Penggunaan Printer & Bluetooth', [
              '• Akses Bluetooth hanya untuk koneksi printer thermal',
              '• Tidak menyimpan informasi perangkat Bluetooth lain',
              '• Data print tidak disimpan setelah pencetakan',
            ]),

            _buildSection('8. Perubahan Kebijakan', [
              '• Kebijakan dapat diperbarui seiring update aplikasi',
              '• Perubahan akan diberitahukan melalui update aplikasi',
              '• Versi terbaru selalu tersedia di aplikasi',
            ]),

            _buildSection('9. Kontak', [
              'Jika ada pertanyaan tentang kebijakan privasi ini:',
              '• Email: agungandre687@gmail.com',
            ]),

            const SizedBox(height: 24),

            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Terakhir diperbarui: Oktober 2025',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dengan menggunakan aplikasi Kasir Ini, Anda menyetujui kebijakan privasi ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
