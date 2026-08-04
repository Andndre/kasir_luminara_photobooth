import 'dart:async';

import 'package:luminara_photobooth/core/helpers/app_log.dart';
import 'package:luminara_photobooth/core/services/midtrans_service.dart';

/// How a payment poll ended.
sealed class PollOutcome {
  const PollOutcome();
}

final class PaymentSettled extends PollOutcome {
  /// Raw Midtrans channel, e.g. `qris`, `gopay`, `bca_va`.
  final String? paymentType;
  const PaymentSettled(this.paymentType);
}

final class PaymentDeclined extends PollOutcome {
  final String reason;
  const PaymentDeclined(this.reason);
}

/// Gave up: the deadline passed without a verdict.
final class PaymentTimedOut extends PollOutcome {
  const PaymentTimedOut();
}

/// Stopped by the caller (screen closed, user cancelled).
final class PaymentAborted extends PollOutcome {
  const PaymentAborted();
}

/// Polls Midtrans until the payment resolves or [deadline] passes.
///
/// The previous implementation was a bare `Timer.periodic` with no stop
/// condition: if the customer walked away, it kept hitting the network every
/// 3s for the life of the process.
class PaymentPoller {
  PaymentPoller({
    MidtransService? service,
    this.interval = const Duration(seconds: 3),
    this.deadline = const Duration(minutes: 15),
  }) : _service = service ?? MidtransService();

  final MidtransService _service;
  final Duration interval;

  /// A Midtrans QRIS code expires well within this; polling past it is
  /// pointless.
  final Duration deadline;

  Timer? _timer;
  Completer<PollOutcome>? _completer;

  bool get isRunning => _timer != null;

  Future<PollOutcome> start(String orderId) {
    cancel();

    final completer = Completer<PollOutcome>();
    _completer = completer;
    final startedAt = DateTime.now();

    void finish(PollOutcome outcome) {
      // Detach first, or cancel() would complete this future with
      // PaymentAborted instead of the real outcome.
      _completer = null;
      cancel();
      if (!completer.isCompleted) completer.complete(outcome);
    }

    // Timer.periodic does not await its callback, so a slow request would
    // otherwise stack a second poll on top of the first.
    var inFlight = false;

    _timer = Timer.periodic(interval, (_) async {
      if (inFlight) return;
      inFlight = true;
      try {
        if (DateTime.now().difference(startedAt) > deadline) {
          AppLog.error('Polling pembayaran $orderId melewati batas waktu');
          finish(const PaymentTimedOut());
          return;
        }

        // The webhook can't reach us on a local network, so nudge the backend
        // to re-check before reading the status.
        await _service.syncTransaction(orderId);
        final result = await _service.checkStatus(orderId);

        switch (result.status) {
          case MidtransStatus.paid:
            finish(PaymentSettled(result.paymentType));
          case MidtransStatus.failed:
            finish(const PaymentDeclined('Pembayaran gagal'));
          case MidtransStatus.expired:
            finish(const PaymentDeclined('Pembayaran kadaluarsa'));
          case MidtransStatus.pending:
          case MidtransStatus.unknown:
          case MidtransStatus.unreachable:
            // Keep waiting; the deadline above is what stops us.
            break;
        }
      } finally {
        inFlight = false;
      }
    });

    return completer.future;
  }

  /// Stops polling. A pending [start] future completes with [PaymentAborted].
  void cancel() {
    _timer?.cancel();
    _timer = null;

    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(const PaymentAborted());
    }
  }
}
