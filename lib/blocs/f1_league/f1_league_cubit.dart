import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/f1_league_data.dart';
import '../../services/espn_f1_league_service.dart';

class F1LeagueState {
  const F1LeagueState({
    this.data,
    this.refreshing = false,
    this.snapshot = true,
    this.failed = false,
  });
  final F1LeagueData? data;
  final bool refreshing;
  final bool snapshot;
  final bool failed;
}

class F1LeagueCubit extends Cubit<F1LeagueState> {
  F1LeagueCubit({EspnF1LeagueService service = const EspnF1LeagueService()})
    : _service = service,
      super(const F1LeagueState());
  final EspnF1LeagueService _service;

  Future<void> load() async {
    if (state.refreshing) return;
    emit(const F1LeagueState(refreshing: true));
    try {
      final data = await _service.bundled();
      if (isClosed) return;
      emit(F1LeagueState(data: data));
    } catch (_) {
      if (isClosed) return;
      emit(const F1LeagueState());
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (state.refreshing || isClosed) return;
    final previous = state;
    emit(
      F1LeagueState(
        data: previous.data,
        refreshing: true,
        snapshot: previous.snapshot,
      ),
    );
    try {
      final data = await _service.fetch();
      if (!isClosed) emit(F1LeagueState(data: data, snapshot: false));
    } catch (_) {
      if (!isClosed) {
        emit(
          F1LeagueState(
            data: previous.data,
            snapshot: previous.snapshot,
            failed: true,
          ),
        );
      }
    }
  }
}
