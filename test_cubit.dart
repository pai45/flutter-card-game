import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/config/enums.dart';

void main() async {
  final repo = MockPredictionRepository();
  final cubit = PredictionCubit(repository: repo);
  await cubit.load();
  await cubit.loadSport(Sport.basketball);
  
  final wnba = cubit.state.fixtures.where((f) => f.leagueId == 'wnba').toList();
  print('WNBA Matches found: ${wnba.length}');
}
