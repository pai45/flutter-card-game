import 'package:flutter/material.dart';
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
import '../../../widgets/unlock_celebration_host.dart';

/// Choosing a sport only previews its existing purchase sheet.
Future<void> showNextSportPicker(BuildContext context) async {
  final sports = context.read<GameBloc>().state.unlocks.lockedSports;
  if (sports.isEmpty) return;
  final sport = await showModalBottomSheet<Sport>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxWidth: 480,
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (context) => _UnlockSheetFrame(
      accent: Cyber.cyan,
      children: [
        Text('CHOOSE YOUR NEXT SPORT', style: Cyber.display(20)),
        const SizedBox(height: 8),
        Text(
          '50 Oz opens matches, picks and the first game.',
          style: Cyber.body(14),
        ),
        const SizedBox(height: 16),
        for (final sport in sports) ...[
          CyberPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sportModuleFor(sport).label.toUpperCase(),
                  style: Cyber.display(15),
                ),
                const SizedBox(height: 8),
                Text(
                  '${sportGameLadder[sport]!.length} games to discover',
                  style: Cyber.body(13),
                ),
                const SizedBox(height: 8),
                CyberObjectiveAction(
                  label: 'VIEW SPORT · 50 OZ',
                  icon: sportModuleFor(sport).icon,
                  accent: sportModuleFor(sport).accent,
                  onTap: () => Navigator.of(context).pop(sport),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
  if (sport != null && context.mounted) {
    await showSportUnlockSheet(context, sport);
  }
}

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
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: CyberKit.entrance),
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

class SportUnlockSheet extends StatefulWidget {
  const SportUnlockSheet({required this.sport, super.key});
  final Sport sport;

  @override
  State<SportUnlockSheet> createState() => _SportUnlockSheetState();
}

class _SportUnlockSheetState extends State<SportUnlockSheet> {
  bool _dismissed = false;

  void _close([bool purchased = false]) {
    if (_dismissed) return;
    _dismissed = true;
    Navigator.of(context).pop(purchased);
  }

  void _purchase() {
    if (_dismissed) return;
    final bloc = context.read<GameBloc>();
    if (bloc.state.coins < sportUnlockCostOz ||
        bloc.state.unlocks.isSportUnlocked(widget.sport)) {
      return;
    }
    bloc.add(SportUnlockPurchased(widget.sport));
    _close(true);
  }

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(widget.sport);
    final ladder = sportGameLadder[widget.sport]!;
    final coins = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    final owned = context.select<GameBloc, bool>(
      (bloc) => bloc.state.unlocks.isSportUnlocked(widget.sport),
    );
    final canAfford = coins >= sportUnlockCostOz;
    final label = module.label.toUpperCase();

    return CyberKitSheet(
      onClose: _close,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SPORT ACCESS',
            style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNLOCK',
                      style: Cyber.label(
                        12,
                        color: Cyber.muted,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Cyber.display(24, color: AppTheme.textContrast),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CyberSportEmblem(icon: module.icon, accent: module.accent),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Open $label matches, picks and ${ladder.first.title}. Play through its quest to unlock every game.',
            style: Cyber.body(14, color: Cyber.muted),
          ),
          const SizedBox(height: 24),
          CyberKitSection(
            label: 'YOUR GAME ROUTE',
            count: '${ladder.length} GAMES',
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < ladder.length; i++)
            CyberProgressionEntry(
              key: ValueKey('sport-unlock-game-${ladder[i].name}'),
              index: i + 1,
              title: ladder[i].title,
              icon: ladder[i].icon,
              detail: i == 0
                  ? 'Your first game. ${ladder[i].questRequirement}'
                  : 'AFTER ${ladder[i - 1].title}',
              featured: i == 0,
              last: i == ladder.length - 1,
            ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 12,
            children: [
              _UnlockBalance(label: 'YOUR BALANCE', value: '$coins OZ'),
              if (canAfford && !owned)
                _UnlockBalance(
                  label: 'AFTER UNLOCK',
                  value: '${coins - sportUnlockCostOz} OZ',
                ),
              const CyberStatusBadge(
                label: '$sportUnlockCostOz OZ',
                tone: CyberStatusTone.reward,
              ),
            ],
          ),
          const SizedBox(height: 16),
          CyberActionButton(
            key: const ValueKey('sport-unlock-cta'),
            label: owned
                ? 'SPORT ALREADY OPEN'
                : 'UNLOCK · $sportUnlockCostOz OZ',
            icon: Icons.lock_open_rounded,
            onPressed: canAfford && !owned ? _purchase : null,
            tapSound: SoundEffect.coinSpend,
          ),
          if (!canAfford && !owned) ...[
            const SizedBox(height: 12),
            Text(
              'NEED ${sportUnlockCostOz - coins} MORE OZ',
              style: Cyber.label(10, color: Cyber.amber, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            CyberActionButton(
              key: const ValueKey('sport-unlock-quests'),
              label: 'VIEW QUESTS',
              icon: Icons.flag_outlined,
              onPressed: () {
                if (_dismissed) return;
                _close();
                UnlockRevealGate.instance.openQuestHub?.call();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlockBalance extends StatelessWidget {
  const _UnlockBalance({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(
        value,
        style: Cyber.display(
          14,
          color: AppTheme.textContrast,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    ],
  );
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
        _SheetEyebrow(text: 'LOCKED GAME', accent: accent),
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
            Expanded(
              child: Text(
                'QUEST PROGRESS',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.6),
              ),
            ),
            const SizedBox(width: 8),
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
