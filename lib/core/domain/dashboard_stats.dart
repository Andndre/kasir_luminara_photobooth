import 'package:equatable/equatable.dart';

/// Numbers shown on the home dashboard.
///
/// Replaces the old `Map<String, dynamic>` where every read was an untyped
/// lookup with a `?? 0` fallback hiding typos in the key name.
class DashboardStats extends Equatable {
  final int todayIncome;
  final int todayTransactions;

  /// Tickets paid but not yet redeemed.
  final int queueCount;

  final int productCount;

  const DashboardStats({
    required this.todayIncome,
    required this.todayTransactions,
    required this.queueCount,
    required this.productCount,
  });

  static const empty = DashboardStats(
    todayIncome: 0,
    todayTransactions: 0,
    queueCount: 0,
    productCount: 0,
  );

  @override
  List<Object?> get props => [
    todayIncome,
    todayTransactions,
    queueCount,
    productCount,
  ];
}
