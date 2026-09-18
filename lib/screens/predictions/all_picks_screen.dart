import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../config/theme.dart';
import '../../models/picks.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'picks_home_view.dart';
import 'widgets/standings_table.dart' show DetailTopBar;

class AllPicksScreen extends StatelessWidget {
  const AllPicksScreen({super.key});

  /// Opens ALL PICKS on one market type with the browse filters reset, so the
  /// list matches the open count a Trends category square advertised.
  static void openFiltered(BuildContext context, PickMarketType type) {
    context.read<PicksCubit>()
      ..setSportFilter(PickSportFilter.all)
      ..setStatusFilter(PickMarketStatusFilter.open)
      ..setTypeFilter(type);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AllPicksScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('all-picks-screen'),
      backgroundColor: Cyber.bg,
      body: const CyberPlainBackground(
        child: SafeArea(
          child: Column(
            children: [
              DetailTopBar(title: 'ALL PICKS'),
              Expanded(child: PicksHomeView(animateIntro: false)),
            ],
          ),
        ),
      ),
    );
  }
}
