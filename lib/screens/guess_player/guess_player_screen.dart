import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/guess_player.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_tooltip.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/team_logo.dart';
import 'widgets/guess_player_result_view.dart';

class GuessPlayerScreen extends StatefulWidget {
  const GuessPlayerScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<GuessPlayerScreen> createState() => _GuessPlayerScreenState();
}

class _GuessPlayerScreenState extends State<GuessPlayerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  PlayerCard? _selectedPlayer;
  int? _xpBefore;

  static const int _extraAttemptCost = 25;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selected = _selectedPlayer;
    if (selected == null) return;
    _xpBefore ??= context.read<GameBloc>().state.progression.totalXP;
    await context.read<GuessPlayerCubit>().submitGuess(selected);
    if (!mounted) return;
    setState(() {
      _selectedPlayer = null;
      _searchController.clear();
    });
    _searchFocus.requestFocus();
  }

  Future<void> _giveUp() async {
    final confirmed = await showCyberConfirmDialog(
      context,
      title: 'Declassify this player?',
      message:
          'Giving up ends today\'s mystery with no score or XP. You can still review every clue.',
      confirmLabel: 'Give up',
      cancelLabel: 'Keep scanning',
      destructive: true,
    );
    if (confirmed && mounted) {
      _xpBefore ??= context.read<GameBloc>().state.progression.totalXP;
      await context.read<GuessPlayerCubit>().giveUp();
    }
  }

  Future<void> _unlockHint(GuessPlayerHintType type) async {
    final cubit = context.read<GuessPlayerCubit>();
    if (cubit.state.hasHint(type)) return;
    final game = context.read<GameBloc>();
    if (game.state.coins < _IntelHintMarket.coinCost) {
      await showCyberConfirmDialog(
        context,
        title: 'INTEL FUNDS LOW',
        message:
            'This scan needs ${_IntelHintMarket.coinCost} coins. Earn more coins, then return to this career route.',
        confirmLabel: 'RETURN',
        cancelLabel: 'CLOSE',
        destructive: true,
      );
      return;
    }
    final label = _hintLabel(type, cubit.sport);
    final confirmed = await showCyberConfirmDialog(
      context,
      title: 'UNLOCK $label?',
      message:
          'Spend ${_IntelHintMarket.coinCost} coins to decrypt this player-profile scan. It will not consume an attempt.',
      confirmLabel: 'SPEND ${_IntelHintMarket.coinCost}',
      cancelLabel: 'KEEP COINS',
    );
    if (!confirmed || !mounted) return;

    // Recheck after the dialog in case another wallet action settled while it
    // was open. The cubit writes the scan first so a completed purchase is
    // never hidden by navigation or an app restart.
    if (context.read<GameBloc>().state.coins < _IntelHintMarket.coinCost) {
      return;
    }
    final unlocked = await cubit.unlockHint(type);
    if (mounted && unlocked) {
      context.read<GameBloc>().add(
        CoinsSpent(
          _IntelHintMarket.coinCost,
          source: OzCoinTransactionSource.guessPlayerHint,
          title: 'CAREER INTEL HINT',
          subtitle: label,
        ),
      );
      playSound(SoundEffect.cardReveal);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _buyExtraAttempt() async {
    final game = context.read<GameBloc>();
    if (game.state.coins < _extraAttemptCost) {
      await showCyberConfirmDialog(
        context,
        title: 'COINS REQUIRED',
        message:
            'You need $_extraAttemptCost coins to restore one more guess on this mystery.',
        confirmLabel: 'RETURN',
        cancelLabel: 'CLOSE',
        destructive: true,
      );
      return;
    }
    final bought = await context.read<GuessPlayerCubit>().buyExtraAttempt();
    if (!mounted || !bought) return;
    game.add(
      CoinsSpent(
        _extraAttemptCost,
        source: OzCoinTransactionSource.guessPlayerExtraAttempt,
        title: 'GUESS PLAYER EXTRA ATTEMPT',
        subtitle: '+1 GUESS',
      ),
    );
    playSound(SoundEffect.coins);
    HapticFeedback.mediumImpact();
  }

  void _handleFeedback(GuessPlayerState state) {
    switch (state.feedback) {
      case GuessPlayerSubmissionFeedback.wrong:
        playSound(
          state.activeRecord?.status == GuessPlayerResultStatus.lost
              ? SoundEffect.matchLose
              : SoundEffect.cardReveal,
        );
        HapticFeedback.lightImpact();
      case GuessPlayerSubmissionFeedback.correct:
        playSound(SoundEffect.matchWin);
        HapticFeedback.mediumImpact();
      case GuessPlayerSubmissionFeedback.duplicate:
        HapticFeedback.selectionClick();
      case GuessPlayerSubmissionFeedback.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuessPlayerCubit, GuessPlayerState>(
      listenWhen: (previous, current) =>
          previous.feedbackSerial != current.feedbackSerial,
      listener: (_, state) => _handleFeedback(state),
      builder: (context, state) {
        final review = state.viewMode == GuessPlayerViewMode.review;
        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) widget.onBack();
          },
          child: GameScaffold(
            title: review ? 'INTEL DEBRIEF' : 'GUESS THE PLAYER',
            subtitle: review
                ? state.activeDayKey
                : 'CLUE ${state.revealedClueCount}/6 · ${state.attemptsRemaining} TRIES',
            leading: CyberTooltip(
              message: review ? 'NAV // MYSTERY HOME' : 'NAV // SAVE AND LEAVE',
              triggerMode: TooltipTriggerMode.longPress,
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
              ),
            ),
            rightSlot: CyberChip(
              label: review ? 'REVIEW' : 'LIVE',
              color: review ? Cyber.muted : Cyber.magenta,
            ),
            compactHeader: !review && MediaQuery.sizeOf(context).width < 600,
            child: review
                ? GuessPlayerResultView(
                    state: state,
                    xpBefore: _xpBefore,
                    onHome: widget.onBack,
                  )
                : _PlayView(
                    state: state,
                    selectedPlayer: _selectedPlayer,
                    searchController: _searchController,
                    searchFocus: _searchFocus,
                    onSelected: (player) {
                      playSound(SoundEffect.cardSelect);
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPlayer = player);
                    },
                    onCleared: () => setState(() => _selectedPlayer = null),
                    onSubmit: _submit,
                    onGiveUp: _giveUp,
                    onBuyExtraAttempt: _buyExtraAttempt,
                    onUnlockHint: _unlockHint,
                  ),
          ),
        );
      },
    );
  }
}

class _PlayView extends StatelessWidget {
  const _PlayView({
    required this.state,
    required this.selectedPlayer,
    required this.searchController,
    required this.searchFocus,
    required this.onSelected,
    required this.onCleared,
    required this.onSubmit,
    required this.onGiveUp,
    required this.onBuyExtraAttempt,
    required this.onUnlockHint,
  });

  final GuessPlayerState state;
  final PlayerCard? selectedPlayer;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<PlayerCard> onSelected;
  final VoidCallback onCleared;
  final VoidCallback onSubmit;
  final VoidCallback onGiveUp;
  final VoidCallback onBuyExtraAttempt;
  final ValueChanged<GuessPlayerHintType> onUnlockHint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final sectionGap = compact ? 8.0 : 16.0;
        final databaseGap = compact ? 8.0 : 24.0;

        return Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 8 : 16,
                  16,
                  compact ? 8 : 20,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MysteryBay(state: state, compact: compact),
                          SizedBox(height: sectionGap),
                          _ClueTimeline(
                            state: state,
                            compact: compact,
                            onUnlockHint: onUnlockHint,
                          ),
                          SizedBox(height: databaseGap),
                          _PlayerSearch(
                            controller: searchController,
                            focusNode: searchFocus,
                            selectedPlayer: selectedPlayer,
                            compact: compact,
                            onSelected: onSelected,
                            onCleared: onCleared,
                            onSubmitted: onSubmit,
                            onGiveUp: onGiveUp,
                          ),
                          if (state.guesses.isNotEmpty) ...[
                            SizedBox(height: compact ? 8 : 12),
                            _GuessLog(guesses: state.guesses),
                          ],
                          if (state.feedback ==
                              GuessPlayerSubmissionFeedback.duplicate) ...[
                            const SizedBox(height: 8),
                            Text(
                              'PLAYER ALREADY SCANNED · NO ATTEMPT USED',
                              textAlign: TextAlign.center,
                              style: Cyber.label(9, color: Cyber.amber),
                            ),
                          ],
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: Cyber.body(11, color: Cyber.danger),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _ActionDock(
              selected: selectedPlayer != null,
              saving: state.saving,
              compact: compact,
              potentialXp: state.potentialXp,
              attemptsRemaining: state.attemptsRemaining,
              maxAttempts: GuessPlayerCubit.maxAttempts,
              extraAttemptCost: _GuessPlayerScreenState._extraAttemptCost,
              onSubmit: onSubmit,
              onGiveUp: onGiveUp,
              onBuyExtraAttempt: onBuyExtraAttempt,
            ),
          ],
        );
      },
    );
  }
}

class _MysteryBay extends StatelessWidget {
  const _MysteryBay({required this.state, this.compact = false});

  final GuessPlayerState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final portrait = state.targetPlayer?.resolvedPortraitAsset;
    final silhouetteAvailable =
        state.revealedClueCount >= 5 && portrait != null;
    return CyberPanel(
      accent: Cyber.border,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 12,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 48 : 68,
            height: compact ? 48 : 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.bg2,
              border: Border.all(color: Cyber.borderSubtle),
            ),
            child: silhouetteAvailable
                ? ClipRect(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Cyber.bg2,
                        BlendMode.saturation,
                      ),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Image.asset(
                          portrait,
                          width: compact ? 48 : 68,
                          height: compact ? 48 : 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.person_search_rounded,
                            color: Cyber.muted,
                            size: compact ? 26 : 36,
                          ),
                        ),
                      ),
                    ),
                  )
                : Icon(
                    Icons.fingerprint_rounded,
                    color: Cyber.magenta,
                    size: compact ? 28 : 38,
                  ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  silhouetteAvailable
                      ? 'SILHOUETTE TRACE FOUND'
                      : 'IDENTITY ENCRYPTED',
                  style: Cyber.display(
                    compact ? 10.5 : 13,
                    color: silhouetteAvailable
                        ? Cyber.amber
                        : AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),
                Text(
                  silhouetteAvailable
                      ? 'Visual trace ready for a final read.'
                      : 'Submit a player to unlock the next career stop.',
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(
                    compact ? 9.5 : 11.5,
                    color: Cyber.muted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          CyberChip(
            label: state.puzzle?.difficulty.name.toUpperCase() ?? 'CLASSIFIED',
            color: Cyber.magenta,
          ),
        ],
      ),
    );
  }
}

class _ClueTimeline extends StatelessWidget {
  const _ClueTimeline({
    required this.state,
    required this.compact,
    required this.onUnlockHint,
  });

  final GuessPlayerState state;
  final bool compact;
  final ValueChanged<GuessPlayerHintType> onUnlockHint;

  @override
  Widget build(BuildContext context) {
    final clues = state.puzzle?.clues ?? const <GuessPlayerClue>[];
    return Semantics(
      label:
          'Career route. Clue ${state.revealedClueCount} of 6. ${state.attemptsRemaining} attempts remaining.',
      child: CyberPanel(
        accent: Cyber.magenta,
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 14,
          compact ? 8 : 12,
          compact ? 10 : 14,
          compact ? 8 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CAREER PATH',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(10, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ROUTE // ${state.revealedClueCount}/6',
                  style: Cyber.label(7.5, color: Cyber.magenta),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 10),
            _CareerRouteStrip(state: state, clues: clues, compact: compact),
            SizedBox(height: compact ? 8 : 14),
            _IntelHintMarket(
              state: state,
              compact: compact,
              onUnlock: onUnlockHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _CareerRouteStrip extends StatelessWidget {
  const _CareerRouteStrip({
    required this.state,
    required this.clues,
    required this.compact,
  });

  final GuessPlayerState state;
  final List<GuessPlayerClue> clues;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sport = context.read<GuessPlayerCubit>().sport;
    return LayoutBuilder(
      builder: (context, constraints) {
        final connectorWidth = constraints.maxWidth < 350 ? 8.0 : 10.0;
        final availableForNodes = constraints.maxWidth - (connectorWidth * 5);
        final nodeWidth = (availableForNodes / 6).clamp(35.0, 50.0);
        final badgeSize = (nodeWidth - 4).clamp(31.0, compact ? 43.0 : 48.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < 6; index++) ...[
              SizedBox(
                width: nodeWidth,
                child: _CareerRouteNode(
                  key: ValueKey('career-route-node-$index'),
                  index: index,
                  clue: index < clues.length ? clues[index] : null,
                  revealed: index < state.revealedClueCount,
                  newest: index == state.revealedClueCount - 1,
                  badgeSize: badgeSize,
                  sport: sport,
                  compact: compact,
                ),
              ),
              if (index < 5)
                SizedBox(
                  width: connectorWidth,
                  height: badgeSize * 0.86,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: connectorWidth + 1,
                    color: index < state.revealedClueCount - 1
                        ? Cyber.cyan
                        : Cyber.muted,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _CareerRouteNode extends StatelessWidget {
  const _CareerRouteNode({
    required this.index,
    required this.clue,
    required this.revealed,
    required this.newest,
    required this.badgeSize,
    required this.sport,
    required this.compact,
    super.key,
  });

  final int index;
  final GuessPlayerClue? clue;
  final bool revealed;
  final bool newest;
  final double badgeSize;
  final Sport sport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final year = clue?.year;
    final isCareerStop = year != null;
    final teamName = clue?.value ?? 'Unknown team';
    final team = SportTeam(
      id: 'career-${sport.name}-$teamName',
      name: teamName,
      shortName: _teamInitials(teamName),
      color: Cyber.muted,
    );
    final semanticsLabel = revealed
        ? isCareerStop
              ? 'Career stop ${index + 1}. $teamName. Joined in $year.'
              : 'Career route ${index + 1}. Route complete.'
        : isCareerStop
        ? 'Career stop ${index + 1} hidden. Joined in $year.'
        : 'Career stop ${index + 1} hidden.';

    return Semantics(
      label: semanticsLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CyberTooltip(
            message: revealed ? teamName : 'Encrypted team',
            accentColor: revealed ? Cyber.cyan : Cyber.magenta,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              child: SizedBox(
                key: ValueKey('$index-$revealed'),
                width: badgeSize,
                height: badgeSize,
                child: revealed
                    ? isCareerStop
                          ? TeamLogo(
                              team: team,
                              width: badgeSize,
                              height: badgeSize,
                              sport: sport,
                            )
                          : Icon(
                              Icons.sports_score_rounded,
                              size: badgeSize * 0.48,
                              color: Cyber.cyan,
                            )
                    : CustomPaint(
                        painter: _LockedCareerLogoPainter(
                          borderColor: newest
                              ? Cyber.magenta
                              : Cyber.borderSubtle,
                        ),
                        child: Center(
                          child: Text(
                            '?',
                            style: Cyber.display(
                              badgeSize * 0.42,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          SizedBox(
            height: compact ? 10 : 12,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                year?.toString() ?? '—',
                maxLines: 1,
                style: Cyber.display(
                  7.5,
                  color: revealed ? Cyber.cyan : Cyber.muted,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCareerLogoPainter extends CustomPainter {
  const _LockedCareerLogoPainter({required this.borderColor});

  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height * 0.9;
    final shadowOffset = size.height - bodyHeight;
    final rect = Rect.fromLTWH(0, 0, size.width, bodyHeight);
    final path = buildOctagonPath(rect, cutRatio: 0.15);

    canvas.drawPath(
      path.shift(Offset(0, shadowOffset)),
      Paint()..color = Cyber.bg.withValues(alpha: 0.62),
    );
    canvas.drawPath(path, Paint()..color = Cyber.muted.withValues(alpha: 0.22));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _LockedCareerLogoPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor;
}

String _teamInitials(String teamName) {
  const ignored = <String>{'fc', 'cf', 'club', 'bc', 'cc'};
  final words = RegExp(
    '[A-Za-z0-9]+',
  ).allMatches(teamName).map((match) => match.group(0)!).toList();
  final meaningful = words
      .where((word) => !ignored.contains(word.toLowerCase()))
      .toList();
  final source = meaningful.isEmpty ? words : meaningful;
  if (source.isEmpty) return '?';
  if (source.length == 1) {
    final end = source.first.length > 3 ? 3 : source.first.length;
    return source.first.substring(0, end).toUpperCase();
  }
  return source.take(3).map((word) => word[0]).join().toUpperCase();
}

class _IntelHintMarket extends StatelessWidget {
  const _IntelHintMarket({
    required this.state,
    required this.compact,
    required this.onUnlock,
  });

  static const int coinCost = 25;

  final GuessPlayerState state;
  final bool compact;
  final ValueChanged<GuessPlayerHintType> onUnlock;

  @override
  Widget build(BuildContext context) {
    final sport = context.read<GuessPlayerCubit>().sport;
    final balance = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'INTEL // $coinCost COINS EACH',
          style: Cyber.label(7, color: Cyber.muted),
        ),
        SizedBox(height: compact ? 4 : 8),
        Row(
          children: [
            for (final type in const [
              GuessPlayerHintType.position,
              GuessPlayerHintType.affiliation,
            ]) ...[
              Expanded(
                child: _IntelHintTile(
                  type: type,
                  label: _hintLabel(type, sport),
                  value: _hintValue(type, state.targetPlayer),
                  revealed: state.hasHint(type),
                  affordable: balance >= coinCost,
                  compact: compact,
                  onTap: () => onUnlock(type),
                ),
              ),
              if (type == GuessPlayerHintType.position)
                const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _IntelHintTile extends StatelessWidget {
  const _IntelHintTile({
    required this.type,
    required this.label,
    required this.value,
    required this.revealed,
    required this.affordable,
    required this.compact,
    required this.onTap,
  });

  final GuessPlayerHintType type;
  final String label;
  final String value;
  final bool revealed;
  final bool affordable;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = revealed
        ? Cyber.cyan
        : affordable
        ? Cyber.muted
        : Cyber.danger;
    final status = revealed ? 'DECRYPTED' : '25 COINS';
    return Semantics(
      button: !revealed,
      label: revealed
          ? '$label hint decrypted. $value.'
          : '$label hint. Unlock for 25 coins.',
      child: InkWell(
        onTap: revealed ? null : onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 40 : 52),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: revealed ? Cyber.cyan.withValues(alpha: 0.08) : Cyber.panel2,
            border: Border.all(
              color: revealed
                  ? Cyber.cyan.withValues(alpha: 0.55)
                  : Cyber.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(6.5, color: Cyber.muted),
              ),
              SizedBox(height: compact ? 4 : 6),
              Row(
                children: [
                  Icon(
                    revealed ? Icons.visibility_rounded : Icons.lock_outline,
                    size: 11,
                    color: accent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      revealed ? value : status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(7.5, color: accent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSearch extends StatelessWidget {
  const _PlayerSearch({
    required this.controller,
    required this.focusNode,
    required this.selectedPlayer,
    required this.compact,
    required this.onSelected,
    required this.onCleared,
    required this.onSubmitted,
    required this.onGiveUp,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final PlayerCard? selectedPlayer;
  final bool compact;
  final ValueChanged<PlayerCard> onSelected;
  final VoidCallback onCleared;
  final VoidCallback onSubmitted;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GuessPlayerCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PLAYER DATABASE',
                style: Cyber.label(7.5, color: Cyber.muted),
              ),
            ),
            Semantics(
              button: true,
              label: 'Give up and reveal player',
              child: InkWell(
                onTap: onGiveUp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'GIVE UP',
                    style: Cyber.label(7, color: Cyber.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        RawAutocomplete<PlayerCard>(
          textEditingController: controller,
          focusNode: focusNode,
          displayStringForOption: (option) => option.name,
          optionsBuilder: (value) => cubit.searchPlayers(value.text),
          onSelected: onSelected,
          fieldViewBuilder:
              (context, textController, fieldFocus, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: fieldFocus,
                  textInputAction: TextInputAction.search,
                  style: Cyber.body(
                    12,
                    color: AppTheme.textPrimary,
                    weight: FontWeight.w700,
                  ),
                  onChanged: (_) {
                    if (selectedPlayer != null) onCleared();
                  },
                  onSubmitted: (_) {
                    if (selectedPlayer != null) {
                      onSubmitted();
                    } else {
                      onFieldSubmitted();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'SEARCH PLAYER',
                    hintStyle: Cyber.label(8, color: Cyber.muted),
                    filled: true,
                    fillColor: Cyber.panel,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: compact ? 10 : 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Cyber.cyan,
                    ),
                    suffixIcon: selectedPlayer != null
                        ? const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Cyber.cyan,
                          )
                        : textController.text.isEmpty
                        ? null
                        : CyberTooltip(
                            message: 'DATABASE // CLEAR SEARCH',
                            triggerMode: TooltipTriggerMode.longPress,
                            child: IconButton(
                              onPressed: () {
                                textController.clear();
                                onCleared();
                                fieldFocus.requestFocus();
                              },
                              icon: const Icon(Icons.close, color: Cyber.muted),
                            ),
                          ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Cyber.borderSubtle),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Cyber.borderSubtle),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: Cyber.cyan, width: 1.5),
                    ),
                  ),
                );
              },
          optionsViewBuilder: (context, select, options) {
            final items = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Cyber.bg.withValues(alpha: 0),
                child: Container(
                  width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 430),
                  constraints: const BoxConstraints(maxHeight: 196),
                  decoration: BoxDecoration(
                    color: Cyber.panel,
                    border: Border.all(
                      color: Cyber.cyan.withValues(alpha: 0.55),
                    ),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Cyber.borderSubtle),
                    itemBuilder: (context, index) {
                      final player = items[index];
                      final highlighted =
                          AutocompleteHighlightedOption.of(context) == index;
                      return Semantics(
                        button: true,
                        selected: highlighted,
                        label: 'Select ${player.name}',
                        child: InkWell(
                          onTap: () => select(player),
                          child: ColoredBox(
                            color: highlighted
                                ? Cyber.cyan.withValues(alpha: 0.1)
                                : Cyber.bg.withValues(alpha: 0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    player.icon,
                                    color: highlighted
                                        ? Cyber.magenta
                                        : Cyber.cyan,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      player.name,
                                      style: Cyber.body(
                                        12,
                                        color: AppTheme.textPrimary,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    player.position,
                                    style: Cyber.label(8, color: Cyber.muted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _GuessLog extends StatelessWidget {
  const _GuessLog({required this.guesses});

  final List<PlayerCard> guesses;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var index = 0; index < guesses.length; index++)
            CyberChip(
              label: '${index + 1} · ${guesses[index].shortName}',
              color: Cyber.danger,
            ),
        ],
      ),
    );
  }
}

String _hintLabel(GuessPlayerHintType type, Sport sport) => switch (type) {
  GuessPlayerHintType.position => 'POSITION',
  GuessPlayerHintType.affiliation =>
    sport == Sport.football ? 'NATIONALITY' : 'TEAM',
};

String _hintValue(GuessPlayerHintType type, PlayerCard? player) {
  if (player == null) return 'INTEL UNAVAILABLE';
  return switch (type) {
    GuessPlayerHintType.position => player.position.toUpperCase(),
    GuessPlayerHintType.affiliation => player.country.toUpperCase(),
  };
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({
    required this.selected,
    required this.saving,
    required this.compact,
    required this.potentialXp,
    required this.attemptsRemaining,
    required this.maxAttempts,
    required this.extraAttemptCost,
    required this.onSubmit,
    required this.onGiveUp,
    required this.onBuyExtraAttempt,
  });

  final bool selected;
  final bool saving;
  final bool compact;
  final int potentialXp;
  final int attemptsRemaining;
  final int maxAttempts;
  final int extraAttemptCost;
  final VoidCallback onSubmit;
  final VoidCallback onGiveUp;
  final VoidCallback onBuyExtraAttempt;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final ctaHeight = compact && enlargedText ? 56.0 : (compact ? 52.0 : 66.0);
    final exhausted = attemptsRemaining <= 0;
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, compact ? 8 : 14),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Cyber.borderSubtle)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GuessHeartMeter(
                attemptsRemaining: attemptsRemaining,
                maxAttempts: maxAttempts,
              ),
              SizedBox(height: compact ? 8 : 12),
              if (exhausted)
                _ExhaustedAttemptActions(
                  saving: saving,
                  cost: extraAttemptCost,
                  onBuy: onBuyExtraAttempt,
                  onGiveUp: onGiveUp,
                )
              else ...[
                HudCtaButton(
                  label: saving ? 'SAVING INTEL...' : 'LOCK PLAYER',
                  helper: selected && !compact
                      ? 'CURRENT PAYOUT · +$potentialXp XP'
                      : null,
                  icon: Icons.lock_rounded,
                  height: ctaHeight,
                  accent: Cyber.cyan,
                  tapSound: SoundEffect.commit,
                  enabled: selected && !saving,
                  onTap: onSubmit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuessHeartMeter extends StatelessWidget {
  const _GuessHeartMeter({
    required this.attemptsRemaining,
    required this.maxAttempts,
  });

  final int attemptsRemaining;
  final int maxAttempts;

  @override
  Widget build(BuildContext context) {
    final remaining = attemptsRemaining.clamp(0, maxAttempts);
    return Semantics(
      label: '$remaining of $maxAttempts guesses remaining',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < maxAttempts; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                key: ValueKey('guess-player-heart-$index'),
                Icons.favorite,
                size: 21,
                color: index < remaining
                    ? Cyber.red
                    : Cyber.muted.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExhaustedAttemptActions extends StatelessWidget {
  const _ExhaustedAttemptActions({
    required this.saving,
    required this.cost,
    required this.onBuy,
    required this.onGiveUp,
  });

  final bool saving;
  final int cost;
  final VoidCallback onBuy;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No guesses remaining. Buy one more guess or give up.',
      child: Column(
        children: [
          Text('NO GUESSES LEFT', style: Cyber.label(8.5, color: Cyber.danger)),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: HudCtaButton(
                  key: const ValueKey('guess-player-buy-extra-attempt'),
                  label: saving ? 'RESTORING...' : '+1 GUESS  //  $cost COINS',
                  icon: Icons.favorite,
                  height: 48,
                  accent: Cyber.amber,
                  tapSound: SoundEffect.coins,
                  enabled: !saving,
                  onTap: onBuy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalmDangerButton(
                  key: const ValueKey('guess-player-give-up-exhausted'),
                  label: 'GIVE UP',
                  enabled: !saving,
                  onTap: onGiveUp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalmDangerButton extends StatelessWidget {
  const _CalmDangerButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(
              color: enabled
                  ? Cyber.danger.withValues(alpha: 0.65)
                  : Cyber.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: Cyber.display(
              11,
              color: enabled ? Cyber.danger : Cyber.muted,
            ),
          ),
        ),
      ),
    );
  }
}
