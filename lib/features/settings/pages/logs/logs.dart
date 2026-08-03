import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/model/log.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Log> _logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => isLoading = true);
    try {
      final logs = await Log.getAllLogs();
      setState(() {
        _logs = logs;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        SnackBarHelper.showError(context, 'Error loading logs: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                  ? const EmptyState(
                      icon: Icons.article_outlined,
                      title: 'Tidak ada log',
                      message: 'Kejadian dan error aplikasi akan tercatat di sini.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLogs,
                      child: isDesktop
                          ? GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 400,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 130,
                                  ),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _ItemSection(log);
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16.0),
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _ItemSection(log);
                              },
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemCount: _logs.length,
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ItemSection(Log log) {
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
          Text(
            log.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: log.isError ? surfaces.onDangerTint : null,
            ),
          ),
        ],
      ),
    );
  }
}
