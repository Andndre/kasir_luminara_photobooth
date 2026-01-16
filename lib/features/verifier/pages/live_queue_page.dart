import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:intl/intl.dart';

class LiveQueuePage extends StatelessWidget {
  const LiveQueuePage({super.key});

  @override
  /// Builds a live queue page.
  ///
  /// This page will show a list of current queue, and a refresh indicator
  /// on top of the page. If the queue is empty, it will show a message
  /// saying that there is no queue right now. If the queue is not empty, it
  /// will show a list of queue items, each item contains customer name,
  /// time when the queue is created, and the items in the queue.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antrean Real-time')),
      body: SafeArea(
        child: BlocBuilder<VerifierBloc, VerifierState>(
          builder: (context, state) {
            if (state.status == VerifierStatus.disconnected) {
              return const Center(
                child: Text(
                  'Belum terhubung ke server.\nSilakan ke menu Koneksi.',
                ),
              );
            }

            if (state.status == VerifierStatus.error) {
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
                          // ignore error
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                child: Text('${index + 1}'),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }
}
