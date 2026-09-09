// Isolated real-data preview: flutter run -t tool/f1_league_preview.dart
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/screens/predictions/league_detail_screen.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
          ),
          BlocProvider(
            create: (_) =>
                PredictionCubit(MockPredictionRepository(), SecureGameStorage())
                  ..load(),
          ),
          BlocProvider(
            create: (_) =>
                PicksCubit(MockPickRepository(), SecureGameStorage())..load(),
          ),
        ],
        child: const LeagueDetailScreen(
          league: League(
            id: 'f1',
            name: 'Formula 1',
            shortCode: 'F1',
            accent: Cyber.cyan,
          ),
        ),
      ),
    ),
  );
}
