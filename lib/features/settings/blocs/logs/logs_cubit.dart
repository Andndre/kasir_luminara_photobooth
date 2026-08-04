import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';

/// Read-only view of the `logs` table.
class LogsCubit extends Cubit<AsyncState<List<LogEntry>>> {
  LogsCubit() : super(const AsyncLoading());

  Future<void> load() async {
    emit(AsyncLoading(state.dataOrNull));
    emit(AsyncReady(await AppLog.recent()));
  }

  Future<void> clear() async {
    await AppLog.clear();
    await load();
  }
}
