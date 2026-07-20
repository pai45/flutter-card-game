import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_winner/guess_winner_cubit.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';

class GuessWinnerScreen extends StatefulWidget {
  const GuessWinnerScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<GuessWinnerScreen> createState() => _GuessWinnerScreenState();
}

class _GuessWinnerScreenState extends State<GuessWinnerScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _selected;
  int _damageSerial = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<GuessWinnerCubit>();
    final selected = _selected;
    if (selected == null) {
      cubit.skip();
      return;
    }
    cubit.submitGuess(selected);
    if (!mounted) return;
    setState(() {
      _selected = null;
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuessWinnerCubit, GuessWinnerState>(
      listenWhen: (previous, current) =>
          previous.remainingHearts != current.remainingHearts &&
          current.remainingHearts > 0,
      listener: (_, _) {
        playSound(SoundEffect.tennisNet);
        HapticFeedback.lightImpact();
        if (mounted) setState(() => _damageSerial++);
      },
      builder: (context, state) {
        final target = state.targetGrandSlam;
        return DailyMysteryPlayLayout(
          title: 'GUESS THE WINNER',
          subtitle:
              'ATTEMPT ${state.guesses.length + 1}/10 · ${state.remainingHearts} LIVES',
          accent: Cyber.lime,
          secondaryAccent: Cyber.cyan,
          icon: Icons.sports_tennis_rounded,
          dossierLabel: 'COURT INTEL // ENCRYPTED',
          dossierTitle: 'GRAND SLAM CHAMPION',
          dossierDescription:
              'Search the champion database and lock the winner for this final.',
          details: [
            DailyMysteryDetail(label: 'YEAR', value: target.year),
            DailyMysteryDetail(label: 'TOURNAMENT', value: target.tournament),
            DailyMysteryDetail(label: 'CATEGORY', value: target.category),
          ],
          searchLabel: 'SEARCH CHAMPION DATABASE',
          options: context.read<GuessWinnerCubit>().allPlayers,
          controller: _controller,
          focusNode: _focusNode,
          selected: _selected,
          guesses: state.guesses,
          remainingHearts: state.remainingHearts,
          maxHearts: GuessWinnerCubit.maxHearts,
          damageSerial: _damageSerial,
          lockLabel: 'LOCK WINNER',
          onBack: widget.onBack,
          onSelected: (value) {
            playSound(SoundEffect.cardSelect);
            HapticFeedback.selectionClick();
            setState(() => _selected = value);
          },
          onCleared: () => setState(() => _selected = null),
          onSubmit: _submit,
        );
      },
    );
  }
}
