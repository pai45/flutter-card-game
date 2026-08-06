import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/daily_mystery_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';

class GuessDriverScreen extends StatefulWidget {
  const GuessDriverScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<GuessDriverScreen> createState() => _GuessDriverScreenState();
}

class _GuessDriverScreenState extends State<GuessDriverScreen> {
  static const _audioProfile = DailyMysteryAudioProfile.driver;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _selected;
  int _damageSerial = 0;

  @override
  void initState() {
    super.initState();
    AudioController.instance.enterScene(AudioScene.mystery);
  }

  @override
  void dispose() {
    AudioController.instance.leaveScene(AudioScene.mystery);
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

  Future<void> _unlockTeamHint() async {
    final cubit = context.read<GuessDriverCubit>();
    final game = context.read<GameBloc>();
    final cost = GuessDriverCubit.teamHintCost;
    if (game.state.coins < cost) {
      await showCyberConfirmDialog(
        context,
        title: 'COINS REQUIRED',
        message: 'You need $cost coins to decrypt the team scan.',
        confirmLabel: 'RETURN',
        cancelLabel: 'CLOSE',
        destructive: true,
      );
      return;
    }
    final confirmed = await showCyberConfirmDialog(
      context,
      title: 'UNLOCK TEAM INTEL?',
      message:
          'Spend $cost coins to reveal this driver\'s team. It will not consume a life.',
      confirmLabel: 'SPEND $cost',
      cancelLabel: 'KEEP COINS',
    );
    if (!confirmed || !mounted) return;
    if (context.read<GameBloc>().state.coins < cost) return;
    final unlocked = await cubit.unlockTeamHint();
    if (!mounted || !unlocked) return;
    game.add(
      CoinsSpent(
        cost,
        source: OzCoinTransactionSource.guessDriverHint,
        title: 'GUESS DRIVER TEAM HINT',
        subtitle: cubit.state.targetRace.teamName,
      ),
    );
    playSound(SoundEffect.coinSpend);
    playSound(_audioProfile.hint);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuessDriverCubit, GuessDriverState>(
      listenWhen: (previous, current) =>
          previous.remainingHearts != current.remainingHearts &&
          current.remainingHearts > 0,
      listener: (_, _) {
        playSound(_audioProfile.wrong);
        HapticFeedback.lightImpact();
        if (mounted) setState(() => _damageSerial++);
      },
      builder: (context, state) {
        final target = state.targetRace;
        final coins = context.select<GameBloc, int>((bloc) => bloc.state.coins);
        return DailyMysteryPlayLayout(
          title: 'GUESS THE DRIVER',
          // Lives are owned by the action dock's meter — don't restate them here.
          subtitle: 'ATTEMPT ${state.guesses.length + 1} / 10',
          accent: Cyber.pink,
          secondaryAccent: Cyber.cyan,
          icon: Icons.sports_motorsports_rounded,
          dossierLabel: 'PIT WALL // ENCRYPTED',
          dossierTitle: 'GRAND PRIX WINNER',
          targetName: target.driverName,
          caseCode: 'CASE ${state.activeDayKey}',
          backdropPainter: const F1MysterySignalPainter(accent: Cyber.pink),
          details: [
            DailyMysteryDetail(label: 'YEAR', value: target.year),
            DailyMysteryDetail(label: 'TRACK', value: target.trackName),
            DailyMysteryDetail(label: 'COUNTRY', value: target.country),
          ],
          extraPanel: DailyMysteryCoinHint(
            label: 'TEAM',
            value: target.teamName.toUpperCase(),
            revealed: state.teamHintRevealed,
            affordable: coins >= GuessDriverCubit.teamHintCost,
            cost: GuessDriverCubit.teamHintCost,
            onTap: _unlockTeamHint,
          ),
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
          audioProfile: _audioProfile,
          onBack: widget.onBack,
          onSelected: (value) {
            playSound(_audioProfile.select);
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
