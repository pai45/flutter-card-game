import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_bingo/football_bingo_cubit.dart';
import '../../blocs/football_bingo/football_bingo_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/football_bingo.dart';
import '../../models/oz_coin_ledger.dart';
import '../../utils/sound_effects.dart';
import '../shop/shop_screen.dart' show CoinIcon;

class FootballBingoScreen extends StatefulWidget {
  const FootballBingoScreen({
    required this.onBack,
    required this.onCompleted,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onCompleted;

  @override
  State<FootballBingoScreen> createState() => _FootballBingoScreenState();
}

class _FootballBingoScreenState extends State<FootballBingoScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _showCompletion = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _selectCell(String cellId) async {
    final cubit = context.read<FootballBingoCubit>();
    final state = cubit.state;
    if (state.needsLifeline) {
      _showMessage('Buy a lifeline to keep playing.');
      return;
    }
    final correct = await cubit.selectCell(cellId);
    playSound(correct ? SoundEffect.cardSlam : SoundEffect.redCard);
    if (correct) {
      HapticFeedback.mediumImpact();
      if (cubit.state.completed) {
        setState(() => _showCompletion = true);
        await Future<void>.delayed(const Duration(milliseconds: 1900));
        if (!mounted) return;
        widget.onCompleted();
      }
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _buyLifeline() async {
    final game = context.read<GameBloc>();
    final bought = await context.read<FootballBingoCubit>().buyLifeline(
      game.state.coins,
    );
    if (!bought) {
      _showMessage('Need 25 coins for a lifeline.');
      return;
    }
    game.add(
      CoinsSpent(
        kFootballBingoLifelineCost,
        source: OzCoinTransactionSource.footballBingoLifeline,
        title: 'BINGO LIFELINE',
        subtitle: '+1 LIFE',
      ),
    );
    playSound(SoundEffect.coins);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: _BingoHeader(onBack: widget.onBack),
      body: BlocBuilder<FootballBingoCubit, FootballBingoState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Cyber.amber),
            );
          }
          return Stack(
            children: [
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        children: [
                          _StatusStrip(state: state, now: _now),
                          const SizedBox(height: 14),
                          _BingoGrid(state: state, onCellTap: _selectCell),
                          const SizedBox(height: 18),
                          _PlayerPanel(state: state),
                          if (state.completed && !_showCompletion) ...[
                            const SizedBox(height: 16),
                            const _CompletePanel(),
                          ],
                        ],
                      ),
                    ),
                    _LifelineDock(state: state, onBuy: _buyLifeline),
                  ],
                ),
              ),
              if (_showCompletion)
                const Positioned.fill(child: _CompletionOverlay()),
            ],
          );
        },
      ),
    );
  }
}

class _BingoHeader extends StatelessWidget implements PreferredSizeWidget {
  const _BingoHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 66,
      backgroundColor: const Color(0xff070b14),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderMuted)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to matches',
              onPressed: () {
                playSound(SoundEffect.uiTap);
                onBack();
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BACK TO BINGO',
                    style: Cyber.label(12, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'BINGO GRID',
                    style: Cyber.display(20, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            const Icon(Icons.grid_3x3, color: Cyber.amber, size: 24),
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state, required this.now});

  final FootballBingoState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = footballBingoStatus(state.progress, now);
    final timer = state.readOnly
        ? 'VIEW'
        : state.completed
        ? formatFootballBingoCountdown(status.remaining)
        : 'LIVE';
    return Row(
      children: [
        Expanded(
          child: _FlatPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.view_module, color: Cyber.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.puzzle.title.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(11, color: Colors.white),
                  ),
                ),
                Text(
                  '${state.progress.solvedCellIds.length}/9',
                  style: Cyber.display(14, color: Cyber.amber),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _TimerBlock(
          label: state.readOnly
              ? 'ARCHIVE'
              : state.completed
              ? 'NEXT'
              : 'DAILY',
          value: timer,
        ),
      ],
    );
  }
}

class _TimerBlock extends StatelessWidget {
  const _TimerBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 48,
      decoration: BoxDecoration(
        color: Cyber.panel2,
        border: Border.all(color: Cyber.amber),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
          const SizedBox(height: 3),
          Text(value, style: Cyber.display(13, color: Cyber.amber)),
        ],
      ),
    );
  }
}

class _BingoGrid extends StatelessWidget {
  const _BingoGrid({required this.state, required this.onCellTap});

  final FootballBingoState state;
  final ValueChanged<String> onCellTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff080c16),
        border: Border.all(color: AppTheme.borderMuted),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 64, height: 54),
              for (final column in state.puzzle.columns)
                Expanded(child: _AxisBadge(axis: column, country: true)),
            ],
          ),
          for (var row = 0; row < kFootballBingoGridSize; row++)
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 58,
                  child: _AxisBadge(axis: state.puzzle.rows[row]),
                ),
                for (var column = 0; column < kFootballBingoGridSize; column++)
                  Expanded(
                    child: _GridCell(
                      cell: state.puzzle.cellAt(row, column),
                      solved: state.solvedCellIds.contains(
                        state.puzzle.cellAt(row, column).id,
                      ),
                      revealAnswer: state.readOnly,
                      wrong:
                          state.lastAnswerCorrect == false &&
                          state.lastTappedCellId ==
                              state.puzzle.cellAt(row, column).id,
                      disabled: state.completed || state.needsLifeline,
                      onTap: onCellTap,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AxisBadge extends StatelessWidget {
  const _AxisBadge({required this.axis, this.country = false});

  final FootballBingoAxis axis;
  final bool country;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: country ? 48 : 52,
      margin: const EdgeInsets.all(3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: country ? const Color(0xff152036) : const Color(0xff182033),
        border: Border.all(color: country ? Cyber.amber : Cyber.cyan),
      ),
      child: Text(
        axis.shortLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Cyber.display(12, color: Colors.white),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.cell,
    required this.solved,
    required this.revealAnswer,
    required this.wrong,
    required this.disabled,
    required this.onTap,
  });

  final FootballBingoCell cell;
  final bool solved;
  final bool revealAnswer;
  final bool wrong;
  final bool disabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final fill = solved
        ? Cyber.lime
        : revealAnswer
        ? const Color(0xff142135)
        : wrong
        ? const Color(0xff4b1118)
        : const Color(0xff111827);
    final border = solved
        ? Cyber.lime
        : revealAnswer
        ? Cyber.cyan
        : wrong
        ? Cyber.red
        : AppTheme.borderMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled || solved || revealAnswer ? null : () => onTap(cell.id),
      child: AnimatedContainer(
        key: ValueKey('bingo-cell-${cell.id}'),
        duration: const Duration(milliseconds: 160),
        height: 58,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: wrong ? 2 : 1),
        ),
        child: solved && !revealAnswer
            ? const Icon(Icons.check, color: AppTheme.darkInk, size: 24)
            : Text(
                revealAnswer ? _answerLabel(cell.playerId) : 'EMPTY',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  revealAnswer ? 8 : 8,
                  color: revealAnswer ? Colors.white : Cyber.muted,
                ),
              ),
      ),
    );
  }

  String _answerLabel(String playerId) {
    return allPlayerCards
            .where((player) => player.id == playerId)
            .firstOrNull
            ?.shortName ??
        'PLAYER';
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.state});

  final FootballBingoState state;

  @override
  Widget build(BuildContext context) {
    final player = state.currentPlayer;
    if (player == null) {
      return _FlatPanel(
        child: Column(
          children: [
            Text(
              state.readOnly ? 'ARCHIVE ANSWER GRID' : 'GRID COMPLETE',
              style: Cyber.display(15, color: Cyber.amber),
            ),
            const SizedBox(height: 6),
            Text(
              state.readOnly
                  ? 'Past daily grids are view-only.'
                  : 'Return home for the next daily grid.',
              textAlign: TextAlign.center,
              style: Cyber.body(12, color: Cyber.muted),
            ),
          ],
        ),
      );
    }
    final portrait = player.resolvedPortraitAsset;
    return Column(
      children: [
        Text('ACTIVE PLAYER', style: Cyber.label(10, color: Cyber.muted)),
        const SizedBox(height: 10),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xff101827),
            border: Border.all(color: Cyber.amber),
          ),
          child: portrait == null
              ? Icon(player.icon, size: 46, color: Cyber.amber)
              : Image.asset(portrait, fit: BoxFit.cover),
        ),
        const SizedBox(height: 10),
        Text(
          player.name,
          textAlign: TextAlign.center,
          style: Cyber.display(15, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '${player.countryCode} | ${player.position}',
          style: Cyber.label(10, color: Cyber.muted),
        ),
      ],
    );
  }
}

class _CompletePanel extends StatelessWidget {
  const _CompletePanel();

  @override
  Widget build(BuildContext context) {
    return _FlatPanel(
      borderColor: Cyber.lime,
      child: Column(
        children: [
          const Icon(Icons.verified, color: Cyber.lime, size: 30),
          const SizedBox(height: 8),
          Text('GRID COMPLETE', style: Cyber.display(16, color: Cyber.lime)),
          const SizedBox(height: 6),
          Text(
            'Tomorrow unlocks the next run.',
            style: Cyber.body(12, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

class _LifelineDock extends StatelessWidget {
  const _LifelineDock({required this.state, required this.onBuy});

  final FootballBingoState state;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final needsBuy = state.needsLifeline;
    if (state.readOnly || state.completed) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xff070b14),
          border: Border(top: BorderSide(color: AppTheme.borderMuted)),
        ),
        child: needsBuy
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBuy,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Cyber.amber,
                    border: Border.all(color: Cyber.amber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 18,
                        color: AppTheme.darkInk,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+1 LIFELINE',
                        style: Cyber.display(13, color: AppTheme.darkInk),
                      ),
                      const SizedBox(width: 10),
                      const CoinIcon(size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$kFootballBingoLifelineCost',
                        style: Cyber.display(13, color: AppTheme.darkInk),
                      ),
                    ],
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < kFootballBingoStartingLifelines; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        Icons.favorite,
                        color: i < state.progress.lifelines
                            ? Cyber.red
                            : Cyber.muted.withValues(alpha: 0.35),
                        size: 23,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CompletionOverlay extends StatelessWidget {
  const _CompletionOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xee070b14),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1400),
          builder: (context, value, child) {
            final count = (value * 9).clamp(0, 9).floor();
            return _FlatPanel(
              borderColor: Cyber.lime,
              child: SizedBox(
                width: 260,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GRID COMPLETE',
                      style: Cyber.display(18, color: Cyber.lime),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$count/9',
                      style: Cyber.display(28, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < 9; i++)
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i < count ? Cyber.lime : Cyber.panel2,
                              border: Border.all(
                                color: i < count
                                    ? Cyber.lime
                                    : AppTheme.borderMuted,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 18,
                              color: i < count ? AppTheme.darkInk : Cyber.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'RETURNING HOME',
                      style: Cyber.label(10, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FlatPanel extends StatelessWidget {
  const _FlatPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor = AppTheme.borderMuted,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Cyber.panel,
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
