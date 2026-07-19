import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/enums.dart';
import '../../data/f1_guess_data.dart';
import '../../services/secure_storage_service.dart';
import 'guess_driver_screen.dart';

class GuessDriverTabContent extends StatelessWidget {
  const GuessDriverTabContent({
    required this.onNavigate,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GuessDriverCubit(
        races: f1Races,
        allDrivers: f1Drivers,
        storage: SecureGameStorage(),
      )..load(),
      child: GuessDriverScreen(
        onBack: () => onNavigate(AppSection.predictions),
      ),
    );
  }
}
