import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_bloc.dart';
import 'package:luminara_photobooth/features/verifier/blocs/verifier_state.dart';
import 'package:intl/intl.dart';

class LiveQueuePage extends StatelessWidget {
  const LiveQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrean Real-time'),
      ),
      body: BlocBuilder<VerifierBloc, VerifierState>(
        builder: (context, state) {
          if (state.status == VerifierStatus.disconnected) {
            return const Center(
              child: Text('Belum terhubung ke server.\nSilakan ke menu Koneksi.'),
            );
          }

          if (state.queue.isEmpty) {
            return const Center(
              child: Text('Tidak ada antrean saat ini.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<VerifierBloc>().add(RefreshQueue());
            },
            child: ListView.builder(
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final item = state.queue[index];
                String timeStr = '-';
                try {
                  if (item['created_at'] != null) {
                    timeStr = DateFormat('HH:mm').format(DateTime.parse(item['created_at']));
                  }
                } catch (e) {
                  // ignore error
                }

                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(item['customer_name'] ?? 'Pelanggan'),
                  subtitle: Text(item['product_name'] ?? '-'),
                  trailing: Text(timeStr),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
