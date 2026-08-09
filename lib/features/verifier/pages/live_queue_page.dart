import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:luminara_photobooth/features/transaction/pages/transaction_page.dart';
import 'package:intl/intl.dart';

/// Kartu antrean. Nomor antrean dibuat besar karena itu yang dicocokkan
/// petugas dengan tiket di tangan pelanggan, dari jarak berdiri.
class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.ticket,
    required this.fallbackNumber,
    required this.onTap,
  });

  final QueueTicket ticket;
  final int fallbackNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final items = ticket.items;
    final createdAt = ticket.createdAt;
    final timeStr = createdAt == null
        ? '-'
        : DateFormat('HH:mm').format(createdAt);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Dimens.dp12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: surfaces.brandTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${ticket.queueNumber ?? fallbackNumber}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: Dimens.dp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(timeStr, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: Dimens.dp8),
                if (items.isEmpty)
                  Text(ticket.summary, style: theme.textTheme.bodyMedium)
                else
                  ...items.map(
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: Dimens.dp4),
                      child: Row(
                        children: [
                          PackageMonogram(i.productName, size: 24),
                          const SizedBox(width: Dimens.dp8),
                          Expanded(
                            child: Text(
                              '${i.productName} ×${i.quantity}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Dimens.dp4),
                Row(
                  children: [
                    const StatusBadge(TransactionStatus.paid),
                    const SizedBox(width: Dimens.dp8),
                    Expanded(
                      child: Text(
                        ticket.uuid,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Antrean dan riwayat berdampingan.
///
/// Keduanya dibaca langsung dari server; verifier tidak menyimpan salinan
/// lokal apa pun.
class LiveQueuePage extends StatelessWidget {
  const LiveQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Antrean'),
          actions: [
            // Tombolnya eksplisit, tidak cuma tarik-ke-bawah: sejak polling
            // dibuang, menyegarkan jadi tindakan sadar dan tidak boleh
            // bergantung pada gestur yang harus ditebak dulu.
            IconButton(
              tooltip: 'Segarkan antrean',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => context.read<VerifierBloc>().add(RefreshQueue()),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Antrean'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _QueueTab(),
              // Dibaca dari server, bukan dari SQLite perangkat ini: verifier
              // sudah butuh internet untuk memindai tiket, jadi mereplikasi
              // database yang harus didamaikan tidak membeli apa pun.
              TransactionHistoryView(
                loader: TransactionHistoryView.fromServer,
                canDelete: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueTab extends StatefulWidget {
  const _QueueTab();

  @override
  State<_QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends State<_QueueTab> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Membuka tab ini adalah pemicu segar yang pertama, dan sampai sekarang
    // satu-satunya yang belum dipasang: nav bawah membangun ulang halamannya
    // tiap pindah tab, jadi daftar yang dilihat petugas bisa saja ditarik
    // berjam-jam lalu saat aplikasi dinyalakan.
    context.read<VerifierBloc>().add(RefreshQueue());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Kembali ke depan layar adalah saat paling mungkin daftarnya sudah basi:
  /// petugas baru mengangkat HP-nya dan sedang menatap layar ini.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<VerifierBloc>().add(RefreshQueue());
    }
  }

  void _showVerifyDialog(BuildContext context, QueueTicket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true, // bentuk & radius diambil dari bottomSheetTheme
      builder: (ctx) => _VerifyBottomSheet(
        ticket: ticket,
        onVerify: () {
          context.read<VerifierBloc>().add(VerifyTransaction(ticket.uuid));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VerifierBloc, VerifierState>(
      listenWhen: (previous, current) =>
          previous.verifySuccess != current.verifySuccess ||
          (previous.errorMessage != current.errorMessage &&
              current.errorMessage != null),
      listener: (context, state) {
        if (state.verifySuccess) {
          SnackBarHelper.showSuccess(context, 'Tiket berhasil diverifikasi');
        } else if (state.errorMessage != null && state.verifyingUuid == null) {
          // Satu-satunya kasus yang dilewati: antrean kosong DAN gagal — di
          // situ EmptyState sudah memajang pesan yang sama. Dulu syaratnya
          // `status == connected`, yang berarti segar-ulang yang gagal di atas
          // daftar berisi tidak berbunyi sama sekali: petugas menekan Segarkan
          // dan tidak terjadi apa-apa.
          final shownByEmptyState =
              state.status == VerifierStatus.error && state.queue.isEmpty;
          if (!shownByEmptyState) {
            SnackBarHelper.showError(context, state.errorMessage!);
          }
        }
      },
      child: BlocBuilder<VerifierBloc, VerifierState>(
        builder: (context, state) {
          // Hanya keadaan awal sebelum InitializeVerifier selesai; tidak ada
          // lagi tombol putus yang bisa membawanya ke sini.
          if (state.status == VerifierStatus.disconnected) {
            return const EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Menyiapkan antrean',
              message: 'Sebentar lagi.',
            );
          }

          if (state.status == VerifierStatus.error && state.queue.isEmpty) {
            return EmptyState(
              isError: true,
              icon: Icons.cloud_off_rounded,
              title: 'Gagal mengambil antrean',
              message: state.errorMessage,
              actionLabel: 'Coba Lagi',
              onAction: () => context.read<VerifierBloc>().add(RefreshQueue()),
            );
          }

          return Column(
            children: [
              _FreshnessBar(fetchedAt: state.queueFetchedAt),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    context.read<VerifierBloc>().add(RefreshQueue());
                  },
                  child: state.queue.isEmpty
                      ? const EmptyState(
                          icon: Icons.done_all_rounded,
                          title: 'Antrean kosong',
                          message: 'Semua tiket sudah dilayani.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(Dimens.dp16),
                          itemCount: state.queue.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Dimens.dp12),
                          itemBuilder: (context, index) {
                            final ticket = state.queue[index];
                            return _QueueCard(
                              ticket: ticket,
                              fallbackNumber: index + 1,
                              onTap: () => _showVerifyDialog(context, ticket),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Umur daftar antrean, dinyatakan terus-menerus.
///
/// Sejak polling dibuang, daftar ini bisa setua apa pun tanpa ada yang
/// berubah di layar. Prinsipnya sama dengan [CashierLeaseBanner]: keadaan
/// yang tidak bisa dipastikan tidak boleh terlihat sama dengan yang pasti.
class _FreshnessBar extends StatefulWidget {
  const _FreshnessBar({required this.fetchedAt});

  final DateTime? fetchedAt;

  /// Setelah selama ini, daftarnya diragukan dan bilahnya berubah kuning.
  static const stale = Duration(minutes: 2);

  @override
  State<_FreshnessBar> createState() => _FreshnessBarState();
}

class _FreshnessBarState extends State<_FreshnessBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Timer ini tidak menyentuh jaringan sama sekali — ia cuma membuat
    // labelnya menua di depan mata. Tanpanya "baru saja" akan tertulis
    // selamanya, yang justru kebohongan yang mau dihindari bilah ini.
    _tick = Timer.periodic(
      const Duration(seconds: 20),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fetchedAt = widget.fetchedAt;
    final age = fetchedAt == null
        ? null
        : DateTime.now().difference(fetchedAt);
    final isStale = age == null || age >= _FreshnessBar.stale;

    final color = isStale ? AppTokens.warning : context.surfaces.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.dp16,
        vertical: Dimens.dp8,
      ),
      color: isStale
          ? AppTokens.warning.withValues(alpha: 0.12)
          : context.surfaces.surfaceAlt,
      child: Row(
        children: [
          Icon(
            isStale ? Icons.history_rounded : Icons.check_circle_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: Dimens.dp8),
          Expanded(
            child: Text(
              queueAgeLabel(age),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (isStale)
            Text(
              'tarik ke bawah untuk menyegarkan',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
        ],
      ),
    );
  }

}

/// Umur antrean dalam kata-kata. Top-level supaya bisa diuji tanpa memompa
/// widget — kelas bilahnya sendiri privat.
String queueAgeLabel(Duration? age) {
  if (age == null) return 'Antrean belum pernah dimuat';
  if (age.inSeconds < 30) return 'Antrean baru saja diperbarui';
  if (age.inMinutes < 1) return 'Antrean diperbarui kurang dari semenit lalu';
  if (age.inMinutes < 60) {
    return 'Antrean diperbarui ${age.inMinutes} menit lalu';
  }
  return 'Antrean diperbarui lebih dari ${age.inHours} jam lalu';
}

class _VerifyBottomSheet extends StatelessWidget {
  final QueueTicket ticket;
  final VoidCallback onVerify;

  const _VerifyBottomSheet({required this.ticket, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    final items = ticket.items;

    return BlocListener<VerifierBloc, VerifierState>(
      listenWhen: (previous, current) =>
          previous.verifySuccess != current.verifySuccess &&
          current.verifySuccess,
      listener: (context, state) {
        if (state.verifySuccess) {
          Navigator.pop(context);
        }
      },
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final surfaces = context.surfaces;

          return Padding(
            // Tanpa padding bawah ini tombol VERIFIKASI duduk persis di bawah
            // bilah navigasi gestur dan tidak bisa ditekan.
            padding: EdgeInsets.fromLTRB(
              Dimens.dp24,
              0,
              Dimens.dp24,
              Dimens.dp24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaces.brandTint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${ticket.queueNumber ?? '-'}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimens.dp16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const EyebrowText('Konfirmasi Verifikasi'),
                          const SizedBox(height: Dimens.dp4),
                          Text(
                            ticket.customerName,
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.dp24),
                const EyebrowText('Layanan'),
                const SizedBox(height: Dimens.dp12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (items.isEmpty)
                          Text(ticket.summary, style: theme.textTheme.bodyLarge)
                        else
                          ...items.map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: Dimens.dp8,
                              ),
                              child: Row(
                                children: [
                                  PackageMonogram(i.productName, size: 32),
                                  const SizedBox(width: Dimens.dp12),
                                  Expanded(
                                    child: Text(
                                      '${i.productName} ×${i.quantity}',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.dp24),
                BlocBuilder<VerifierBloc, VerifierState>(
                  builder: (context, state) {
                    final isVerifying = state.verifyingUuid == ticket.uuid;

                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isVerifying ? null : onVerify,
                            child: isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('VERIFIKASI SEKARANG'),
                          ),
                        ),
                        const SizedBox(height: Dimens.dp8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: isVerifying
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
