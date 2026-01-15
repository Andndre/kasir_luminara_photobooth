import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String routeName = '/privacy-policy';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Dimens.dp16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(Dimens.radius),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.privacy_tip, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Kebijakan Privasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Luminara Photobooth',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
  
              // Content
              _buildSection(context, '1. Informasi yang Kami Kumpulkan', [
                '• Data Transaksi: Informasi penjualan, nama pelanggan, paket yang dipilih, dan harga.',
                '• Data Perangkat: Informasi teknis for koneksi server lokal dan pairing QR.',
                '• Data Jaringan: Alamat IP lokal (LAN) digunakan hanya untuk menghubungkan Kasir dan Verifikator.',
              ]),
  
              _buildSection(context, '2. Penggunaan Informasi', [
                '• Memproses transaksi dan verifikasi tiket di lokasi (offline).',
                '• Menghasilkan laporan pemasukan dan riwayat transaksi.',
                '• Menjaga koneksi antara perangkat server dan client dalam jaringan lokal.',
              ]),
  
              _buildSection(context, '3. Penyimpanan & Keamanan', [
                '• Lokal: Seluruh data bisnis disimpan secara lokal di perangkat Anda (SQLite).',
                '• Privasi: Kami tidak mengumpulkan atau mengirim data Anda ke server cloud pihak ketiga.',
                '• Background Service: Pada Android, aplikasi menggunakan Foreground Service agar server tetap aktif saat di latar belakang.',
              ]),
  
              _buildSection(context, '4. Koneksi Jaringan & Lokasi', [
                '• Izin Lokasi/Bluetooth: Digunakan semata-mata untuk mendeteksi printer thermal dan mendapatkan IP Wifi untuk server lokal.',
                '• Offline: Aplikasi dirancang untuk bekerja tanpa koneksi internet (Local Network Only).',
              ]),
  
              _buildSection(context, '5. Hak Anda', [
                '• Anda memiliki kontrol penuh atas data Anda.',
                '• Data dapat dihapus secara permanen melalui pengaturan aplikasi.',
                '• Laporan transaksi dapat diekspor ke format Excel (.xlsx) untuk keperluan backup.',
              ]),
  
              _buildSection(context, '6. Kontak', [
                'Jika ada pertanyaan mengenai kebijakan privasi ini:',
                '• Email: agungandre687@gmail.com',
              ]),
  
              const SizedBox(height: 24),
  
              // Footer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(Dimens.radius),
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Terakhir diperbarui: Januari 2026',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Dengan menggunakan aplikasi Luminara Photobooth, Anda menyetujui kebijakan privasi ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> items) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(Dimens.radius),
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
