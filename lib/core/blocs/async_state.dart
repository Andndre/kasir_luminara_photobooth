import 'package:equatable/equatable.dart';

import '../data/result.dart';

/// The three states every data-loading screen actually has.
///
/// Replaces the `bool isLoading` + `List<T> items` + `String? error` triple
/// that each screen used to carry in its own `setState`, where nothing stopped
/// "loading and failed and has data" from being true at once.
///
/// Switch on it in the UI and the compiler checks you handled every case:
///
/// ```dart
/// switch (state) {
///   case AsyncLoading(): return const CircularProgressIndicator();
///   case AsyncFailed(:final message): return EmptyState(message: message);
///   case AsyncReady(:final value): return ListView(...);
/// }
/// ```
sealed class AsyncState<T> extends Equatable {
  const AsyncState();

  /// Current data if there is any. Non-null while [AsyncReady], and also while
  /// [AsyncLoading] on a refresh, so lists don't blink to a spinner.
  T? get dataOrNull => switch (this) {
    AsyncReady(:final value) => value,
    AsyncLoading(:final previous) => previous,
    AsyncFailed() => null,
  };

  @override
  List<Object?> get props => [dataOrNull];
}

final class AsyncLoading<T> extends AsyncState<T> {
  /// Kept during a refresh so the screen can show the old list plus a spinner
  /// instead of clearing itself.
  final T? previous;

  const AsyncLoading([this.previous]);

  @override
  List<Object?> get props => [previous, 'loading'];
}

final class AsyncReady<T> extends AsyncState<T> {
  final T value;
  const AsyncReady(this.value);

  @override
  List<Object?> get props => [value];
}

final class AsyncFailed<T> extends AsyncState<T> {
  final String message;
  const AsyncFailed(this.message);

  @override
  List<Object?> get props => [message];
}

/// Bridges a repository [Result] into the matching [AsyncState].
extension ResultToAsyncState<T> on Result<T> {
  AsyncState<T> toAsyncState() => switch (this) {
    Ok(:final value) => AsyncReady(value),
    Err(:final message) => AsyncFailed(message),
  };
}
