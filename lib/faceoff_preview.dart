// TEMPORARY verification entrypoint — renders the shootout face-off in isolation
// so it can be screenshotted without navigating the lobby (web pushed-route
// hit-test quirk). Delete after verifying. Build:
//   flutter build web --release -t lib/faceoff_preview.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/shootout/shootout_bloc.dart';
import 'blocs/shootout/shootout_state.dart';
import 'config/theme.dart';
import 'models/cards.dart';
import 'models/progression.dart';
import 'screens/shootout/widgets/shootout_lineup_phase.dart';

void main() {
  final playerKeeper = goalkeepers[0];
  final playerShooters = <PlayerCard>[
    attackers[0],
    attackers[1],
    defenders[0],
    defenders[1],
    playerKeeper,
  ];
  final cpu = generateShootoutOpponent(
    4,
    attackers,
    defenders,
    goalkeepers,
    random: Random(7),
  );
  final state = ShootoutState.initial(
    playerShooters: playerShooters,
    playerKeeper: playerKeeper,
    cpuShooters: cpu.shooters,
    cpuKeeper: cpu.keeper,
    cpuLevel: 4,
    opponentName: 'Maya Santos',
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: BlocProvider<ShootoutBloc>(
        create: (_) => ShootoutBloc(
          playerShooters: playerShooters,
          playerKeeper: playerKeeper,
          cpuShooters: cpu.shooters,
          cpuKeeper: cpu.keeper,
          cpuLevel: 4,
          opponentName: 'Maya Santos',
        ),
        child: ShootoutLineupPhase(state: state, onQuit: () {}),
      ),
    ),
  );
}
