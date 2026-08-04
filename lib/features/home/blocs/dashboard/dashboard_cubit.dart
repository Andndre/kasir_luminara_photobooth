import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:luminara_photobooth/core/blocs/async_state.dart';
import 'package:luminara_photobooth/core/core.dart';

/// Today's takings, queue length and package count for the home screen.
class DashboardCubit extends Cubit<AsyncState<DashboardStats>> {
  DashboardCubit({StatisticsRepository repository = const StatisticsRepository()})
    : _repository = repository,
      super(const AsyncLoading()) {
    dataRefresh.addListener(load);
  }

  final StatisticsRepository _repository;

  Future<void> load() async {
    emit(AsyncLoading(state.dataOrNull));
    final result = await _repository.today();
    if (!isClosed) emit(result.toAsyncState());
  }

  @override
  Future<void> close() {
    dataRefresh.removeListener(load);
    return super.close();
  }
}
