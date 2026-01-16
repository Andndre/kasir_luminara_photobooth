import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/core/helpers/snackbar_helper.dart';
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
                  ? const Center(child: Text('Tidak ada log.'))
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                log.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: log.isError ? Colors.red : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
