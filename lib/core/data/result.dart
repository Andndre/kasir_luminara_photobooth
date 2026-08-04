/// Typed success/failure wrapper, so callers must handle the error branch
/// instead of relying on an untyped `throw` reaching some outer try/catch.
///
/// Use [runCatching] at the persistence boundary; above that, pattern-match:
///
/// ```dart
/// switch (await repo.all()) {
///   case Ok(:final value): render(value);
///   case Err(:final message): showError(message);
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// The value on success, or `null` on failure. For when the caller genuinely
  /// has nothing to do about the error (e.g. best-effort background refresh).
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  bool get isOk => this is Ok<T>;

  R fold<R>({
    required R Function(T value) ok,
    required R Function(String message, Object error) err,
  }) => switch (this) {
    Ok(:final value) => ok(value),
    Err(:final message, :final error) => err(message, error),
  };
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  /// Human-readable, already safe to show in a snackbar.
  final String message;

  /// The original exception, kept for logging.
  final Object error;
  final StackTrace stackTrace;

  const Err(this.message, this.error, this.stackTrace);

  /// Re-type a failure so it can be returned from a function with a different
  /// success type without unwrapping and rewrapping.
  Err<R> cast<R>() => Err<R>(message, error, stackTrace);
}

/// Runs [body] and converts any thrown object into an [Err] carrying [context]
/// as the user-facing message.
Future<Result<T>> runCatching<T>(
  String context,
  Future<T> Function() body,
) async {
  try {
    return Ok(await body());
  } catch (error, stackTrace) {
    return Err('$context: $error', error, stackTrace);
  }
}
