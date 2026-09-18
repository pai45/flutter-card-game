import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../config/game_ladder.dart';
import '../../../config/sport_modules.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Offers a locked sport for [sportUnlockCostOz]. Resolves `true` once the
/// purchase is dispatched; the SPORT UNLOCKED reveal then plays at the app
/// root. Previews the sport's whole game ladder so the player sees what the
/// Oz buys, not just a price.
Future<bool> showSportUnlockSheet(BuildContext context, Sport sport) async {
  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Cyber.bg.withValues(alpha: 0.78),
    barrierLabel: 'Dismiss sport unlock',
    constraints: BoxConstraints(
      maxWidth: 480,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<GameBloc>(),
      child: SportUnlockSheet(sport: sport),
    ),
  );
  return unlocked ?? false;
}

/// Explains a locked game: which quest step opens it, with a CTA straight to
/// the game that clears that step. A game whose whole sport is locked hands
/// over to [showSportUnlockSheet].
Future<void> showLockedGameSheet(
  BuildContext context,
  ArcadeGame game, {
  required ValueChanged<ArcadeGame> onPlay,
}) async {
  final unlocks = context.read<GameBloc>().state.unlocks;
  if (!unlocks.isSportUnlocked(game.sport)) {
    await showSportUnlockSheet(context, game.sport);
    return;
  }
  final step = unlocks.currentStep(game.sport);
  final play = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Cyber.bg.withValues(alpha: 0.78),
    barrierLabel: 'Dismiss locked game',
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (_) => _LockedGameSheet(
      game: game,
      step: step,
      cleared: unlocks.stepsCleared(game.sport),
    ),
  );
  if (play == true && step != null) onPlay(step);
}

class SportUnlockSheet extends StatelessWidget {
  const SportUnlockSheet({required this.sport, super.key});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(sport);
    final accent = module.accent;
    final ladder = sportGameLadder[sport]!;
    final coins = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    final canAfford = coins >= sportUnlockCostOz;
    final label = module.label.toUpperCase();

    return _UnlockSheetFrame(
      accent: accent,
      children: [
        _SheetEyebrow(text: 'LOCKED SPORT // $label', accent: accent),
        const SizedBox(height: 14),
        Row(
          children: [
            _IconPlate(icon: module.icon, accent: accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UNLOCK $label',
                    style: Cyber.display(22, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Matches, picks and ${ladder.length} games - with its own '
                    "Beginner's Quest.",
                    style: Cyber.body(13, color: Cyber.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionLabel(label: 'GAME LADDER'),
        const SizedBox(height: 8),
        for (var i = 0; i < ladder.length; i++)
          _LadderRow(
            index: i,
            game: ladder[i],
            accent: accent,
            status: i == 0 ? 'OPENS NOW' : 'QUEST STEP $i',
            open: i == 0,
          ),
        const SizedBox(height: 16),
        _BalanceRow(coins: coins),
        const SizedBox(height: 16),
        HudCtaButton(
          key: const ValueKey('sport-unlock-cta'),
          label: 'UNLOCK · $sportUnlockCostOz OZ',
          icon: Icons.lock_open_rounded,
          accent: accent,
          height: 58,
          enabled: canAfford,
          glow: canAfford,
          tapSound: SoundEffect.coinSpend,
          onTap: canAfford
              ? () {
                  HapticFeedback.mediumImpact();
                  context.read<GameBloc>().add(SportUnlockPurchased(sport));
                  Navigator.of(context).pop(true);
                }
              : null,
        ),
        if (!canAfford) ...[
          const SizedBox(height: 10),
          Text(
            'NEED ${sportUnlockCostOz - coins} MORE OZ - CLEAR YOUR '
            "BEGINNER'S QUEST FOR +$beginnerQuestCompleteOz OZ",
            textAlign: TextAlign.center,
            style: Cyber.label(10, color: Cyber.amber, letterSpacing: 1.2),
          ),
        ],
      ],
    );
  }
}

class _LockedGameSheet extends StatelessWidget {
  const _LockedGameSheet({
    required this.game,
    required this.step,
    required this.cleared,
  });

  final ArcadeGame game;
  final ArcadeGame? step;
  final int cleared;

  @override
  Widget build(BuildContext context) {
    const accent = Cyber.amber;
    final ladder = sportGameLadder[game.sport]!;
    final step = this.step;
    return _UnlockSheetFrame(
      accent: accent,
      children: [
        _SheetEyebrow(
          text: "LOCKED // BEGINNER'S QUEST STEP ${game.ladderIndex}",
          accent: accent,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _IconPlate(icon: game.icon, accent: Cyber.muted, locked: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: Cyber.display(20, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step == null
                        ? 'Keep playing to open it.'
                        : game.ladderIndex == step.ladderIndex + 1
                        ? 'Finish one ${step.title} run to unlock it - win or '
                              'lose.'
                        : 'Unlocks after ${ladder[game.ladderIndex - 1].title}. '
                              'Next up: ${step.title}.',
                    style: Cyber.body(13, color: Cyber.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'QUEST PROGRESS',
              style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.6),
            ),
            const Spacer(),
            Text(
              '$cleared / ${ladder.length}',
              style: Cyber.display(
                12,
                color: accent,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CyberProgressBar(value: cleared / ladder.length, accent: accent),
        if (step != null) ...[
          const SizedBox(height: 20),
          HudCtaButton(
            key: const ValueKey('locked-game-play-step'),
            label: 'PLAY ${step.title}',
            icon: Icons.play_arrow_rounded,
            accent: accent,
            height: 56,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ],
    );
  }
}

/// Chamfered HUD sheet shell shared by the unlock sheets (same frame as the
/// streak reminder).
class _UnlockSheetFrame extends StatelessWidget {
  const _UnlockSheetFrame({required this.accent, required this.children});

  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Material(
          type: MaterialType.transparency,
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 22, smallCut: 6),
            child: CustomPaint(
              foregroundPainter: HudSheetFramePainter(
                bigCut: 22,
                smallCut: 6,
                accent: accent,
              ),
              child: ColoredBox(
                color: Cyber.card,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          color: Cyber.line.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetEyebrow extends StatelessWidget {
  const _SheetEyebrow({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_rounded, size: 13, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(10, color: accent, letterSpacing: 1.8),
          ),
        ),
      ],
    );
  }
}

class _IconPlate extends StatelessWidget {
  const _IconPlate({
    required this.icon,
    required this.accent,
    this.locked = false,
  });

  final IconData icon;
  final Color accent;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipPath(
            clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  accent.withValues(alpha: 0.1),
                  Cyber.panel,
                ),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
          ),
          if (locked)
            const Positioned(
              right: -4,
              bottom: -4,
              child: Icon(Icons.lock_rounded, size: 18, color: Cyber.amber),
            ),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.index,
    required this.game,
    required this.accent,
    required this.status,
    required this.open,
  });

  final int index;
  final ArcadeGame game;
  final Color accent;
  final String status;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final tint = open ? accent : Cyber.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(
            color: open ? accent.withValues(alpha: 0.5) : Cyber.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Text(
              '${index + 1}'.padLeft(2, '0'),
              style: Cyber.display(
                11,
                color: tint,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 10),
            Icon(open ? game.icon : Icons.lock_outline, size: 16, color: tint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  11,
                  color: open ? Colors.white : Cyber.muted,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Text(
              status,
              style: Cyber.label(9, color: tint, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final after = coins - sportUnlockCostOz;
    final numbers = Cyber.display(
      13,
      color: Colors.white,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Row(
      children: [
        Text(
          'BALANCE',
          style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.6),
        ),
        const Spacer(),
        Text('$coins OZ', style: numbers),
        if (after >= 0) ...[
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 14, color: Cyber.muted),
          const SizedBox(width: 8),
          Text('$after OZ', style: numbers.copyWith(color: Cyber.gold)),
        ],
      ],
    );
  }
}
