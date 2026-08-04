import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/features/settings/blocs/logs/logs_cubit.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => LogsCubit()..load(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Logs'),
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0,
          foregroundColor: theme.appBarTheme.foregroundColor,
        ),
        body: SafeArea(
          child: BlocBuilder<LogsCubit, AsyncState<List<LogEntry>>>(
            builder: (context, state) => switch (state) {
              AsyncLoading(previous: null) => const Center(
                child: CircularProgressIndicator(),
              ),
              AsyncFailed(:final message) => EmptyState(
                isError: true,
                icon: Icons.article_outlined,
                title: 'Gagal memuat log',
                message: message,
                actionLabel: 'Coba Lagi',
                onAction: () => context.read<LogsCubit>().load(),
              ),
              _ => _LogList(logs: state.dataOrNull ?? const []),
            },
          ),
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.logs});

  final List<LogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: 'Tidak ada log',
        message: 'Kejadian dan error aplikasi akan tercatat di sini.',
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return RefreshIndicator(
      onRefresh: () => context.read<LogsCubit>().load(),
      child: isDesktop
          ? GridView.builder(
              padding: const EdgeInsets.all(Dimens.dp16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                crossAxisSpacing: Dimens.dp16,
                mainAxisSpacing: Dimens.dp16,
                mainAxisExtent: 130,
              ),
              itemCount: logs.length,
              itemBuilder: (context, index) => _LogCard(logs[index]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(Dimens.dp16),
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: Dimens.dp12),
              itemBuilder: (context, index) => _LogCard(logs[index]),
            ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard(this.log);

  final LogEntry log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return AppCard(
      padding: const EdgeInsets.all(Dimens.dp12),
      // Error ditandai lewat latar tint, bukan teks merah — teks merah di
      // atas krem kontrasnya lemah dan sulit dibaca.
      color: log.isError ? surfaces.dangerTint : null,
      borderColor: log.isError ? Colors.transparent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (log.isError) ...[
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: surfaces.onDangerTint,
                ),
                const SizedBox(width: Dimens.dp4),
              ],
              Text(
                DateFormat('dd MMM yyyy · HH:mm:ss').format(log.timestamp),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: log.isError
                      ? surfaces.onDangerTint
                      : surfaces.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.dp8),
          // Kartu di grid desktop punya tinggi tetap; pesan panjang harus
          // dipotong, bukan meluber keluar kartu.
          Flexible(
            child: Text(
              log.message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: log.isError ? surfaces.onDangerTint : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
