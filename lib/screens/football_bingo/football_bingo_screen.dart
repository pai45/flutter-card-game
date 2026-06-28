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
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/team_logo.dart';
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
  final _stackKey = GlobalKey();
  final _activePlayerKey = GlobalKey();
  final Map<String, GlobalKey> _cellKeys = {};
  final Set<String> _settlingCellIds = {};
  _BingoPlayerFlight? _flight;

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
    if (_flight != null) return;
    final cubit = context.read<FootballBingoCubit>();
    final state = cubit.state;
    if (state.needsLifeline) {
      _showMessage('Buy a lifeline to keep playing.');
      return;
    }
    final playerToPlace = state.currentPlayer;
    final startRect = _rectFor(_activePlayerKey);
    final endRect = _rectFor(_cellKey(cellId));
    final correct = await cubit.selectCell(cellId);
    if (correct) {
      HapticFeedback.mediumImpact();
      if (playerToPlace != null) {
        setState(() {
          _settlingCellIds.add(cellId);
        });
        await _runPlacementFlight(
          player: playerToPlace,
          cellId: cellId,
          start: startRect,
          end: endRect,
        );
      }
      if (cubit.state.completed) {
        await _showCompletedAndReturn();
      }
    } else {
      playSound(SoundEffect.redCard);
      HapticFeedback.heavyImpact();
    }
  }

  GlobalKey _cellKey(String cellId) =>
      _cellKeys.putIfAbsent(cellId, GlobalKey.new);

  Rect? _rectFor(GlobalKey key) {
    final stackContext = _stackKey.currentContext;
    final targetContext = key.currentContext;
    if (stackContext == null || targetContext == null) return null;
    final stack = stackContext.findRenderObject();
    final target = targetContext.findRenderObject();
    if (stack is! RenderBox || target is! RenderBox || !target.hasSize) {
      return null;
    }
    final offset = target.localToGlobal(Offset.zero, ancestor: stack);
    return offset & target.size;
  }

  Future<void> _runPlacementFlight({
    required PlayerCard player,
    required String cellId,
    required Rect? start,
    required Rect? end,
  }) async {
    if (start == null || end == null) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    } else {
      setState(() => _flight = _BingoPlayerFlight(player, start, end));
      playSound(SoundEffect.cardSelect);
      await Future<void>.delayed(const Duration(milliseconds: 620));
    }
    if (!mounted) return;
    setState(() {
      _flight = null;
      _settlingCellIds.remove(cellId);
    });
  }

  Future<void> _showCompletedAndReturn() async {
    if (!mounted) return;
    setState(() => _showCompletion = true);
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
            key: _stackKey,
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
                          _BingoGrid(
                            state: state,
                            settlingCellIds: _settlingCellIds,
                            cellKeyFor: _cellKey,
                            onCellTap: _selectCell,
                          ),
                          const SizedBox(height: 18),
                          _PlayerPanel(
                            state: state,
                            portraitKey: _activePlayerKey,
                          ),
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
                Positioned.fill(
                  child: _CompletionOverlay(onDone: widget.onCompleted),
                ),
              if (_flight != null) _FlightLayer(flight: _flight!),
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
  const _BingoGrid({
    required this.state,
    required this.settlingCellIds,
    required this.cellKeyFor,
    required this.onCellTap,
  });

  final FootballBingoState state;
  final Set<String> settlingCellIds;
  final GlobalKey Function(String cellId) cellKeyFor;
  final ValueChanged<String> onCellTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        const gridPadding = EdgeInsets.symmetric(horizontal: 2, vertical: 4);
        final availableWidth = constraints.maxWidth - gridPadding.horizontal;
        final rawCell =
            (availableWidth - gap * 4) / (kFootballBingoGridSize + 1);
        final cellSize = rawCell.clamp(58.0, 92.0).toDouble();
        return Padding(
          padding: gridPadding,
          child: Center(
            child: SizedBox(
              width: cellSize * (kFootballBingoGridSize + 1) + gap * 4,
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: cellSize, height: cellSize),
                      const SizedBox(width: gap),
                      for (final column in state.puzzle.columns) ...[
                        _AxisBadge(axis: column, size: cellSize),
                        const SizedBox(width: gap),
                      ],
                    ],
                  ),
                  const SizedBox(height: gap),
                  for (var row = 0; row < kFootballBingoGridSize; row++) ...[
                    Row(
                      children: [
                        _AxisBadge(
                          axis: state.puzzle.rows[row],
                          size: cellSize,
                        ),
                        const SizedBox(width: gap),
                        for (
                          var column = 0;
                          column < kFootballBingoGridSize;
                          column++
                        ) ...[
                          _GridCell(
                            key: cellKeyFor(
                              state.puzzle.cellAt(row, column).id,
                            ),
                            cell: state.puzzle.cellAt(row, column),
                            size: cellSize,
                            solved: state.solvedCellIds.contains(
                              state.puzzle.cellAt(row, column).id,
                            ),
                            settling: settlingCellIds.contains(
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
                          const SizedBox(width: gap),
                        ],
                      ],
                    ),
                    if (row != kFootballBingoGridSize - 1)
                      const SizedBox(height: gap),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AxisBadge extends StatelessWidget {
  const _AxisBadge({required this.axis, required this.size});

  final FootballBingoAxis axis;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: TeamLogo(
          team: _clubTeam(axis),
          width: size * 0.82,
          height: size * 0.82,
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    super.key,
    required this.cell,
    required this.size,
    required this.solved,
    required this.settling,
    required this.revealAnswer,
    required this.wrong,
    required this.disabled,
    required this.onTap,
  });

  final FootballBingoCell cell;
  final double size;
  final bool solved;
  final bool settling;
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
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: wrong ? 2 : 1),
        ),
        child: solved && !settling
            ? _SolvedPortrait(playerId: cell.playerId)
            : Text(
                revealAnswer ? 'SOLVED' : 'EMPTY',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(8, color: Cyber.muted),
              ),
      ),
    );
  }
}

class _SolvedPortrait extends StatelessWidget {
  const _SolvedPortrait({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final player = allPlayerCards
        .where((candidate) => candidate.id == playerId)
        .firstOrNull;
    final portrait = player?.resolvedPortraitAsset;
    if (player == null || portrait == null) {
      return Icon(player?.icon ?? Icons.check, color: AppTheme.darkInk);
    }
    return ClipRect(
      child: Image.asset(
        portrait,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _BingoPlayerFlight {
  const _BingoPlayerFlight(this.player, this.start, this.end);

  final PlayerCard player;
  final Rect start;
  final Rect end;
}

class _FlightLayer extends StatelessWidget {
  const _FlightLayer({required this.flight});

  final _BingoPlayerFlight flight;

  @override
  Widget build(BuildContext context) {
    final portrait = flight.player.resolvedPortraitAsset;
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 560),
          curve: Curves.easeInOutCubic,
          builder: (context, value, child) {
            final rect = Rect.lerp(flight.start, flight.end, value)!;
            final lift = Curves.easeOut.transform(1 - (2 * value - 1).abs());
            return Stack(
              children: [
                Positioned(
                  left: rect.left,
                  top: rect.top - 18 * lift,
                  width: rect.width,
                  height: rect.height,
                  child: Transform.scale(
                    scale: 1 + 0.08 * lift,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Cyber.amber, width: 2),
                        boxShadow: Cyber.glow(
                          Cyber.amber,
                          alpha: 0.22,
                          blur: 18,
                        ),
                      ),
                      child: ClipRect(
                        child: portrait == null
                            ? Icon(flight.player.icon, color: Cyber.amber)
                            : Image.asset(portrait, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

SportTeam _clubTeam(FootballBingoAxis axis) {
  return SportTeam(
    id: axis.id,
    name: axis.label,
    shortName: axis.shortLabel,
    color: _clubColors[axis.id] ?? Cyber.cyan,
  );
}

const _clubColors = <String, Color>{
  'psg': Color(0xff0b1f5e),
  'barca': Color(0xff9b1238),
  'realmadrid': Color(0xfff5f0d7),
  'manutd': Color(0xffd71920),
  'mancity': Color(0xff74acde),
  'chelsea': Color(0xff034694),
  'bayern': Color(0xffdc052d),
  'liverpool': Color(0xffc8102e),
  'arsenal': Color(0xffef0107),
};

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.state, required this.portraitKey});

  final FootballBingoState state;
  final GlobalKey portraitKey;

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
          key: portraitKey,
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
          player.position,
          textAlign: TextAlign.center,
          style: Cyber.display(15, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          player.trait.toUpperCase(),
          textAlign: TextAlign.center,
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

class _CompletionOverlay extends StatefulWidget {
  const _CompletionOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<_CompletionOverlay> {
  bool _summary = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.whoosh);
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _summary) return;
    _showSummary();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _done) return;
    _finish();
  }

  void _showSummary() {
    playSound(SoundEffect.matchWin);
    setState(() => _summary = true);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _handleTap() {
    if (_summary) {
      _finish();
    } else {
      _showSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ColoredBox(
        color: const Color(0xf6070b14),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            builder: (context, summaryValue, child) {
              final count = (_summary ? 9 : summaryValue * 9)
                  .clamp(0, 9)
                  .floor();
              return _FlatPanel(
                borderColor: Cyber.lime,
                child: SizedBox(
                  width: 280,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _summary ? 'DAILY LOGGED' : 'GRID COMPLETE',
                        textAlign: TextAlign.center,
                        style: Cyber.display(
                          18,
                          color: _summary ? Cyber.amber : Cyber.lime,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$count/9',
                        style: Cyber.display(30, color: Colors.white),
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
                                color: i < count
                                    ? AppTheme.darkInk
                                    : Cyber.muted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _summary ? 'TAP TO CONTINUE' : 'TAP TO REVEAL',
                          key: ValueKey(_summary),
                          style: Cyber.label(10, color: Cyber.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
