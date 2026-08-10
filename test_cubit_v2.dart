import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/config/enums.dart';

void main() async {
  print('Starting test...');
  final repo = MockPredictionRepository();
  final cubit = PredictionCubit(repository: repo);
  
  print('Loading cubit...');
  await cubit.load();
  print('Leagues loaded: ${cubit.state.leagues.map((l) => l.id).join(", ")}');
  
  print('Loading sport basketball...');
  await cubit.loadSport(Sport.basketball);
  
  final fixtures = cubit.state.fixtures;
  final bball = fixtures.where((f) => f.sport == Sport.basketball).toList();
  print('Total basketball matches: ${bball.length}');
  
  for (final match in bball) {
    print('Match: ${match.id} | League: ${match.leagueId} | Teams: ${match.home.name} vs ${match.away.name} | Date: ${match.kickoff}');
  }
  
  print('Done.');
}
