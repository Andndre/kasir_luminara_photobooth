import 'package:flutter/foundation.dart';

/// Fires when the database has been replaced wholesale (restore from backup),
/// so open screens reload instead of showing rows that no longer exist.
///
/// Screens used to listen to `AppState` for this, which also notifies on every
/// theme toggle — so each theme switch reloaded every list in the app.
class DataRefreshNotifier extends ChangeNotifier {
  DataRefreshNotifier._();

  /// Call after any operation that rewrites the whole database.
  void invalidate() => notifyListeners();
}

/// App-wide instance. A singleton rather than a provider because the restore
/// service is not part of the widget tree.
final dataRefresh = DataRefreshNotifier._();
