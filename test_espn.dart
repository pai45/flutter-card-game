import 'package:card_game/services/espn_score_service.dart';
import 'package:card_game/config/enums.dart';

void main() async {
  final service = EspnScoreService();
  print('Fetching basketball...');
  final matches = await service.fetchDynamicMatchesForSport(Sport.basketball);
  print('Total dynamic basketball matches: ${matches.length}');
  for (final match in matches) {
    print('${match.leagueId}: ${match.home.name} vs ${match.away.name} @ ${match.kickoff}');
  }
}
