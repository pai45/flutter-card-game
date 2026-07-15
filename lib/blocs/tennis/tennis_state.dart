import '../../models/tennis.dart';

enum TennisFlowPhase { hub, selection, preview, match, result }

class TennisState {
  const TennisState({
    this.loading = true,
    this.profile = const TennisProfile(),
    this.phase = TennisFlowPhase.hub,
    this.selectedMode = TennisMode.quickMatch,
    this.trainingLesson = 1,
    this.config,
    this.resumeSnapshot,
    this.summary,
    this.reward = TennisReward.zero,
  });

  final bool loading;
  final TennisProfile profile;
  final TennisFlowPhase phase;
  final TennisMode selectedMode;
  final int trainingLesson;
  final TennisMatchConfig? config;
  final TennisMatchSnapshot? resumeSnapshot;
  final TennisMatchSummary? summary;
  final TennisReward reward;

  bool get canResume => resumeSnapshot != null;
  TennisPlayer get selectedPlayer => tennisPlayerById(profile.selectedPlayerId);
  TennisPlayer get selectedOpponent => tennisPlayerById(profile.lastOpponentId);

  TennisState copyWith({
    bool? loading,
    TennisProfile? profile,
    TennisFlowPhase? phase,
    TennisMode? selectedMode,
    int? trainingLesson,
    TennisMatchConfig? config,
    TennisMatchSnapshot? resumeSnapshot,
    TennisMatchSummary? summary,
    TennisReward? reward,
    bool clearConfig = false,
    bool clearResume = false,
    bool clearResult = false,
  }) => TennisState(
    loading: loading ?? this.loading,
    profile: profile ?? this.profile,
    phase: phase ?? this.phase,
    selectedMode: selectedMode ?? this.selectedMode,
    trainingLesson: trainingLesson ?? this.trainingLesson,
    config: clearConfig ? null : (config ?? this.config),
    resumeSnapshot: clearResume
        ? null
        : (resumeSnapshot ?? this.resumeSnapshot),
    summary: clearResult ? null : (summary ?? this.summary),
    reward: clearResult ? TennisReward.zero : (reward ?? this.reward),
  );
}
