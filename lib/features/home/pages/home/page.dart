import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';
import 'package:luminara_photobooth/core/preferences/app_state.dart';
import 'package:intl/intl.dart';
import 'package:luminara_photobooth/features/server/components/server_monitor.dart';
import 'package:luminara_photobooth/core/constants/app_mode.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _statistics = StatisticsRepository();
  late Future<Result<DashboardStats>> _statisticsFuture;

  @override
  void initState() {
    super.initState();
    _statisticsFuture = _statistics.today();

    // Listen untuk refresh setelah restore
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    // Cleanup listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().removeListener(_onAppStateChanged);
      }
    });
    super.dispose();
  }

  void _onAppStateChanged() {
    // Refresh statistics saat AppState memberi signal
    _refreshStatistics();
  }

  void _refreshStatistics() {
    setState(() {
      _statisticsFuture = _statistics.today();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.read<AppMode>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          mode == AppMode.server ? 'Server Dashboard' : 'Verifier Dashboard',
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatistics,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Result<DashboardStats>>(
          future: _statisticsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // A failed read shows zeroes rather than an error screen: the
            // dashboard is glanceable info, not something to block the app on.
            final statistics =
                snapshot.data?.valueOrNull ?? DashboardStats.empty;

            return LayoutBuilder(
              builder: (context, constraints) {
                // Enforce minimum width of 400px to prevent overflow on tiny windows
                const double minWidth = 400.0;
                final double contentWidth = constraints.maxWidth < minWidth
                    ? minWidth
                    : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: contentWidth,
                        maxWidth: contentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Dimens.dp16,
                          Dimens.dp8,
                          Dimens.dp16,
                          Dimens.dp16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Uang dulu. Status server teknis turun ke bawah.
                            HeroPanel(
                              label: _greeting(),
                              value: Currency.format(statistics.todayIncome),
                              meta:
                                  '${statistics.todayTransactions} transaksi · '
                                  '${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now())}',
                              icon: Icons.storefront_rounded,
                            ),
                            const SizedBox(height: Dimens.dp24),

                            const EyebrowText('Ringkasan Hari Ini'),
                            const SizedBox(height: Dimens.dp12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatTile(
                                    label: 'Antrean',
                                    value: '${statistics.queueCount}',
                                    hint: 'menunggu dilayani',
                                  ),
                                ),
                                const SizedBox(width: Dimens.dp12),
                                Expanded(
                                  child: _StatTile(
                                    label: 'Paket',
                                    value: '${statistics.productCount}',
                                    hint: 'tersedia',
                                  ),
                                ),
                              ],
                            ),

                            if (mode == AppMode.server) ...[
                              const SizedBox(height: Dimens.dp24),
                              const EyebrowText('Server'),
                              const SizedBox(height: Dimens.dp12),
                              const ServerMonitor(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }


  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 18) return 'Selamat Malam';
    if (hour >= 15) return 'Selamat Sore';
    if (hour >= 12) return 'Selamat Siang';
    return 'Selamat Pagi';
  }
}

/// Angka besar + label kecil. Tanpa ikon berwarna-warni — angkanya yang
/// harus terbaca dari jauh, bukan ikonnya.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Dimens.dp4),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: surfaces.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
