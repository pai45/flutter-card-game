import '../../models/league_stat_leaders.dart';

enum LeagueStatsStatus { loading, loaded, error }

class LeagueStatsState {
  const LeagueStatsState({
    this.status = LeagueStatsStatus.loading,
    this.snapshot = LeagueStatsSnapshot.empty,
    this.categoryIndex = 0,
    this.groupIndex = 0,
    this.resolvingCategory = false,
  });

  final LeagueStatsStatus status;
  final LeagueStatsSnapshot snapshot;

  /// Selected leaderboard tab.
  final int categoryIndex;

  /// Selected standings group (conference) tab.
  final int groupIndex;

  /// True while the selected board's athlete names are being fetched.
  final bool resolvingCategory;

  bool get hasStandings => snapshot.groups.isNotEmpty;
  bool get hasLeaders => snapshot.categories.isNotEmpty;

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
    bool? resolvingCategory,
  }) => LeagueStatsState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    categoryIndex: categoryIndex ?? this.categoryIndex,
    groupIndex: groupIndex ?? this.groupIndex,
    resolvingCategory: resolvingCategory ?? this.resolvingCategory,
  );
}
