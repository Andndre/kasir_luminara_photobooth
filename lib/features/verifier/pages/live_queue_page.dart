import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/model/log.dart';

class LiveQueuePage extends StatelessWidget {
  const LiveQueuePage({super.key});

  void _showVerifyDialog(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VerifyBottomSheet(
        item: item,
        onVerify: () {
          context.read<VerifierBloc>().add(VerifyTransaction(item['uuid']));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Real-time')),
      body: SafeArea(
        child: BlocListener<VerifierBloc, VerifierState>(
          listenWhen: (previous, current) =>
              previous.verifySuccess != current.verifySuccess ||
              (previous.errorMessage != current.errorMessage &&
                  current.errorMessage != null),
          listener: (context, state) {
            if (state.verifySuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Berhasil diverifikasi!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state.errorMessage != null &&
                state.verifyingUuid == null &&
                state.status == VerifierStatus.connected) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: BlocBuilder<VerifierBloc, VerifierState>(
            builder: (context, state) {
              if (state.status == VerifierStatus.disconnected) {
                return const Center(
                  child: Text(
                    'Belum terhubung ke server.\nSilakan ke menu Koneksi.',
                  ),
                );
              }

              if (state.status == VerifierStatus.error && state.queue.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Gagal mengambil data:\n${state.errorMessage}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () =>
                              context.read<VerifierBloc>().add(RefreshQueue()),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<VerifierBloc>().add(RefreshQueue());
                },
                child: state.queue.isEmpty
                    ? const Center(child: Text('Tidak ada antrean saat ini.'))
                    : ListView.builder(
                        itemCount: state.queue.length,
                        itemBuilder: (context, index) {
                          final item = state.queue[index];
                          final items = (item['items'] as List?) ?? [];

                          String timeStr = '-';
                          try {
                            if (item['created_at'] != null) {
                              timeStr = DateFormat(
                                'HH:mm',
                              ).format(DateTime.parse(item['created_at']));
                            }
                          } catch (e) {
                            Log.insertLog(
                              'Error parsing time: $e',
                              isError: true,
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _showVerifyDialog(context, item),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      '#${item['queue_number'] ?? (index + 1)}',
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['customer_name'] ?? 'Pelanggan',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (items.isEmpty)
                                          Text(item['product_name'] ?? '-')
                                        else
                                          ...items.map(
                                            (i) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2,
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_outline,
                                                    size: 14,
                                                    color: Colors.green,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      '${i['product_name']} x${i['quantity']}',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${item['uuid']}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VerifyBottomSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onVerify;

  const _VerifyBottomSheet({
    required this.item,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final items = (item['items'] as List?) ?? [];

    return BlocListener<VerifierBloc, VerifierState>(
      listenWhen: (previous, current) =>
          previous.verifySuccess != current.verifySuccess &&
          current.verifySuccess,
      listener: (context, state) {
        if (state.verifySuccess) {
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    '#${item['queue_number'] ?? '-'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfirmasi Verifikasi',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        item['customer_name'] ?? 'Pelanggan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Layanan/Produk:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (items.isEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.shopping_bag_outlined),
                        title: Text(item['product_name'] ?? '-'),
                      )
                    else
                      ...items.map(
                        (i) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text('${i['product_name']} x${i['quantity']}'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            BlocBuilder<VerifierBloc, VerifierState>(
              builder: (context, state) {
                final isVerifying = state.verifyingUuid == item['uuid'];

                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : onVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'VERIFIKASI SEKARANG',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed:
                            isVerifying ? null : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
