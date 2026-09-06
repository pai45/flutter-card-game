import '../../models/league_stat_leaders.dart';

enum LeagueStatsStatus { loading, loaded, error }

class LeagueStatsState {
  const LeagueStatsState({
    this.status = LeagueStatsStatus.loading,
    this.snapshot = LeagueStatsSnapshot.empty,
    this.categoryIndex = 0,
    this.groupIndex = 0,
    this.statGroupIndex = 0,
    this.statIndex = 0,
    this.resolvingCategory = false,
    this.refreshingLive = false,
    this.loadingTeamStats = false,
  });

  final LeagueStatsStatus status;
  final LeagueStatsSnapshot snapshot;

  /// Selected leaderboard tab.
  final int categoryIndex;

  /// Selected standings group (conference) tab.
  final int groupIndex;

  /// Selected STATS category (ATTACK / DEFENCE / KEEPING / DISCIPLINE).
  final int statGroupIndex;

  /// Selected stat board within the current STATS category.
  final int statIndex;

  /// True while the selected board's athlete names are being fetched.
  final bool resolvingCategory;

  /// True while the live feed is being layered over the bundled package. The
  /// hub stays fully usable throughout — this only drives a quiet indicator.
  final bool refreshingLive;

  /// True while the STATS tab's per-club season statistics are being fetched.
  /// Only ever true for leagues the bundled package doesn't already cover.
  final bool loadingTeamStats;

  bool get hasStandings => snapshot.groups.isNotEmpty;
  bool get hasLeaders => snapshot.categories.isNotEmpty;
  bool get hasTeamStats => snapshot.hasTeamStats;

  StandingsGroup? get selectedGroup {
    if (groupIndex < 0 || groupIndex >= snapshot.groups.length) return null;
    return snapshot.groups[groupIndex];
  }

  StatLeaderCategory? get selectedCategory {
    if (categoryIndex < 0 || categoryIndex >= snapshot.categories.length) {
      return null;
    }
    return snapshot.categories[categoryIndex];
  }

  LeagueStatsState copyWith({
    LeagueStatsStatus? status,
    LeagueStatsSnapshot? snapshot,
    int? categoryIndex,
    int? groupIndex,
    int? statGroupIndex,
    int? statIndex,
    bool? resolvingCategory,
    bool? refreshingLive,
    bool? loadingTeamStats,
  }) => LeagueStatsState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    categoryIndex: categoryIndex ?? this.categoryIndex,
    groupIndex: groupIndex ?? this.groupIndex,
    statGroupIndex: statGroupIndex ?? this.statGroupIndex,
    statIndex: statIndex ?? this.statIndex,
    resolvingCategory: resolvingCategory ?? this.resolvingCategory,
    refreshingLive: refreshingLive ?? this.refreshingLive,
    loadingTeamStats: loadingTeamStats ?? this.loadingTeamStats,
  );
}
