import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';

class GuessDriverScreen extends StatefulWidget {
  const GuessDriverScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<GuessDriverScreen> createState() => _GuessDriverScreenState();
}

class _GuessDriverScreenState extends State<GuessDriverScreen> {
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
    final cubit = context.read<GuessDriverCubit>();
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
    return BlocConsumer<GuessDriverCubit, GuessDriverState>(
      listenWhen: (previous, current) =>
          previous.remainingHearts != current.remainingHearts &&
          current.remainingHearts > 0,
      listener: (_, _) {
        playSound(SoundEffect.cardReveal);
        HapticFeedback.lightImpact();
        if (mounted) setState(() => _damageSerial++);
      },
      builder: (context, state) {
        final target = state.targetRace;
        return DailyMysteryPlayLayout(
          title: 'GUESS THE DRIVER',
          subtitle:
              'ATTEMPT ${state.guesses.length + 1}/10 · ${state.remainingHearts} LIVES',
          accent: Cyber.pink,
          secondaryAccent: Cyber.cyan,
          icon: Icons.sports_motorsports_rounded,
          dossierLabel: 'PIT WALL // ENCRYPTED',
          dossierTitle: 'GRAND PRIX WINNER',
          dossierDescription:
              'Search the driver database and lock the winner for this race.',
          details: [
            DailyMysteryDetail(label: 'YEAR', value: target.year),
            DailyMysteryDetail(label: 'TRACK', value: target.trackName),
            DailyMysteryDetail(label: 'COUNTRY', value: target.country),
          ],
          searchLabel: 'SEARCH DRIVER DATABASE',
          options: context.read<GuessDriverCubit>().allDrivers,
          controller: _controller,
          focusNode: _focusNode,
          selected: _selected,
          guesses: state.guesses,
          remainingHearts: state.remainingHearts,
          maxHearts: GuessDriverCubit.maxHearts,
          damageSerial: _damageSerial,
          lockLabel: 'LOCK DRIVER',
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
