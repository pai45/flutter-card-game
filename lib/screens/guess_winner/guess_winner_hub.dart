import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_winner/guess_winner_cubit.dart';
import '../../config/enums.dart';
import '../../data/tennis_guess_data.dart';
import '../../services/secure_storage_service.dart';
import 'guess_winner_screen.dart';

class GuessWinnerTabContent extends StatelessWidget {
  const GuessWinnerTabContent({
    required this.onNavigate,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GuessWinnerCubit(
        grandSlams: grandSlams,
        allPlayers: tennisPlayers,
        storage: SecureGameStorage(),
      )..load(),
      child: GuessWinnerScreen(
        onBack: () => onNavigate(AppSection.predictions),
      ),
    );
  }
}
