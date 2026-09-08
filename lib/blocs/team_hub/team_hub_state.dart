import '../../models/team_hub.dart';

enum TeamHubStatus { loading, loaded, error }

class TeamHubState {
  const TeamHubState({
    this.status = TeamHubStatus.loading,
    this.data,
    this.refreshing = false,
    this.refreshFailed = false,
  });

  final TeamHubStatus status;
  final TeamHubData? data;
  final bool refreshing;
  final bool refreshFailed;

  TeamHubState copyWith({
    TeamHubStatus? status,
    TeamHubData? data,
    bool? refreshing,
    bool? refreshFailed,
  }) => TeamHubState(
    status: status ?? this.status,
    data: data ?? this.data,
    refreshing: refreshing ?? this.refreshing,
    refreshFailed: refreshFailed ?? this.refreshFailed,
  );
}
