import 'dart:math';

import 'package:flutter/material.dart';

import '../blocs/game/game_state.dart';
import '../config/theme.dart';
import '../config/tutorial_steps.dart';
import '../models/cards.dart';
import '../models/match.dart';
import '../screens/match_history/match_history_pages.dart';
import '../utils/label_helpers.dart';
import 'cyber/cyber_widgets.dart';
import 'game_scaffold.dart';
import 'info_widgets.dart';
import 'spotlight_walkthrough.dart';
import 'tutorial.dart';

class StadiumBackground extends StatefulWidget {
  const StadiumBackground({super.key});

  @override
  State<StadiumBackground> createState() => _StadiumBackgroundState();
}

class _StadiumBackgroundState extends State<StadiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Held opacity passed straight to Image.paint so the dim is applied while the
  // bitmap is drawn — no per-frame saveLayer like an Opacity widget would force.
  static const _dim = AlwaysStoppedAnimation<double>(0.20);

  @override
  Widget build(BuildContext context) {
    // Isolated in its own layer so the slow ambient scale never repaints (or
    // gets repainted by) the foreground phase animations sitting above it.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final scale = 1.0 + 0.025 * sin(_ctrl.value * 2 * pi);
          return Transform.scale(scale: scale, child: child);
        },
        child: Image.asset(
          'assets/backgrounds/match_stadium.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          opacity: _dim,
          // Fall back to the original stadium art if the new match
          // background hasn't been added to assets/backgrounds/ yet.
          errorBuilder: (_, _, _) => Image.asset(
            'assets/backgrounds/home_stadium.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            opacity: _dim,
          ),
        ),
      ),
    );
  }
}

class PhaseList extends StatelessWidget {
  const PhaseList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, index) => children[index],
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemCount: children.length,
    );
  }
}

class MatchPhaseScaffold extends StatelessWidget {
  const MatchPhaseScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onQuit,
    this.state,
    this.scoreLabel,
    this.tutorialKey,
    this.tutorialSteps = const [],
    this.spotlightKey,
    this.spotlightSteps = const [],
    this.spotlightEnabled = true,
    this.spotlightDelay = Duration.zero,
    this.spotlightOnComplete,
    this.spotlightInteractiveKeys = const [],
    this.spotlightCardAnchor = SpotlightCardAnchor.auto,
    this.spotlightCardBottomInset = 24,
    this.bottomAction,
    this.bottomActionKey,
    this.showStadium = true,
    this.centerContent = false,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Match state for the round meter + header score. Null for non-match
  /// flows (the standalone shootout passes a [scoreLabel] instead.)
  final GameState? state;
  final List<Widget> children;
  final VoidCallback onQuit;
  final String? scoreLabel;
  final String? tutorialKey;
  final List<TutorialStepData> tutorialSteps;
  final String? spotlightKey;
  final List<SpotlightStep> spotlightSteps;
  final bool spotlightEnabled;
  final Duration spotlightDelay;
  final VoidCallback? spotlightOnComplete;
  final List<GlobalKey> spotlightInteractiveKeys;
  final SpotlightCardAnchor spotlightCardAnchor;
  final double spotlightCardBottomInset;
  final Widget? bottomAction;
  final GlobalKey? bottomActionKey;

  /// Whether to lay the ambient stadium image behind the content. Off for
  /// non-match flows that want a clean HUD backdrop (e.g. the shootout lineup).
  final bool showStadium;

  /// Vertically centre the content in the visible band (between header and the
  /// docked action) instead of top-aligning it. For compact "moment" screens
  /// like the shootout face-off; still scrolls if it can't fit.
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    // No score to show when neither a label nor match state is supplied.
    final showScore = scoreLabel != null || state != null;
    // Lift the docked action + scroll tail above the gesture/nav bar; the
    // full-bleed StadiumBackground keeps reaching the screen edge (we opt out of
    // GameScaffold's own bottom SafeArea).
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return GameScaffold(
      title: title,
      subtitle: null,
      showShop: false,
      compactHeader: true,
      grain: true,
      safeAreaBottom: false,
      titleUnderlay:
          scoreLabel == null &&
              state != null &&
              state!.currentRound >= 1 &&
              state!.currentRound <= 4
          ? _RoundProgressMeter(currentRound: state!.currentRound)
          : null,
      rightSlot: showScore
          ? MatchHeaderScore(
              label: scoreLabel,
              playerScore: state?.playerScore ?? 0,
              opponentScore: state?.opponentScore ?? 0,
            )
          : null,
      leading: IconButton(
        onPressed: onQuit,
        icon: const Icon(Icons.close, color: Cyber.cyan),
      ),
      child: Stack(
        children: [
          if (showStadium) const Positioned.fill(child: StadiumBackground()),
          if (centerContent)
            _CenteredPhaseBody(
              bottomInset: bottomInset,
              hasBottomAction: bottomAction != null,
              children: children,
            )
          else
            ListView.separated(
              clipBehavior: Clip.none,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                (bottomAction == null ? 16 : 128) + bottomInset,
              ),
              itemBuilder: (_, index) => children[index],
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemCount: children.length,
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: Cyber.cyan.withValues(alpha: 0.16),
              ),
            ),
          ),
          if (tutorialKey != null)
            TutorialTip(keyName: tutorialKey!, steps: tutorialSteps),
          if (spotlightKey != null && spotlightSteps.isNotEmpty)
            SpotlightTutorial(
              keyName: spotlightKey!,
              steps: spotlightSteps,
              enabled: spotlightEnabled,
              startDelay: spotlightDelay,
              onComplete: spotlightOnComplete,
              interactiveKeys: spotlightInteractiveKeys,
              cardAnchor: spotlightCardAnchor,
              cardBottomInset: spotlightCardBottomInset,
            ),
          if (bottomAction != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32 + bottomInset,
              child: bottomActionKey == null
                  ? bottomAction!
                  : SpotlightTarget(
                      spotlightKey: bottomActionKey!,
                      child: bottomAction!,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Scrollable body that vertically centres a phase's content in the band
/// between the header and the docked action. Falls back to scrolling when the
/// content is taller than the visible band (short screens).
class _CenteredPhaseBody extends StatelessWidget {
  const _CenteredPhaseBody({
    required this.children,
    required this.bottomInset,
    required this.hasBottomAction,
  });

  final List<Widget> children;
  final double bottomInset;
  final bool hasBottomAction;

  @override
  Widget build(BuildContext context) {
    const topPad = 16.0;
    final bottomPad = (hasBottomAction ? 128.0 : 16.0) + bottomInset;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          clipBehavior: Clip.none,
          padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - topPad - bottomPad).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  children[i],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoundProgressMeter extends StatelessWidget {
  const _RoundProgressMeter({required this.currentRound});

  final int currentRound;

  @override
  Widget build(BuildContext context) {
    final activeRound = currentRound.clamp(1, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final active = index < activeRound;
        return Container(
          width: index == 0 ? 23 : 21,
          height: 3,
          margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
          decoration: BoxDecoration(
            color: active ? Cyber.cyan : Cyber.cyan.withValues(alpha: 0.12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Cyber.cyan.withValues(alpha: 0.32),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class MatchHeaderScore extends StatelessWidget {
  const MatchHeaderScore({
    super.key,
    required this.playerScore,
    required this.opponentScore,
    this.label,
  });

  final int playerScore;
  final int opponentScore;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 88),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Cyber.danger.withValues(alpha: 0.1),
              border: Border.all(color: Cyber.danger.withValues(alpha: 0.45)),
            ),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 4, 7, 5),
          decoration: BoxDecoration(
            color: const Color(0xff050816).withValues(alpha: 0.72),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScoreDigit(score: playerScore, color: Cyber.cyan),
              const SizedBox(width: 5),
              const _ScoreDivider(),
              const SizedBox(width: 5),
              _ScoreDigit(score: opponentScore, color: Cyber.danger),
              const SizedBox(width: 6),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Cyber.lime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Cyber.lime.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreDigit extends StatelessWidget {
  const _ScoreDigit({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.64)),
      ),
      child: Text(
        '$score',
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontFamily: Cyber.displayFont,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ScoreDivider extends StatelessWidget {
  const _ScoreDivider();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 3, height: 3, color: Colors.white70),
        const SizedBox(height: 4),
        Container(width: 3, height: 3, color: Colors.white70),
      ],
    );
  }
}

class RoleStrip extends StatelessWidget {
  const RoleStrip({required this.attacking, super.key});

  final bool attacking;

  @override
  Widget build(BuildContext context) {
    final accent = attacking ? Cyber.cyan : Cyber.violet;
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(attacking ? Icons.sports_soccer : Icons.shield, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'YOU // ${attacking ? 'ATTACKING' : 'DEFENDING'}',
              style: TextStyle(
                color: accent,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          const HiddenCard(),
          const SizedBox(width: 8),
          const HiddenCard(),
        ],
      ),
    );
  }
}

class HiddenCard extends StatelessWidget {
  const HiddenCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Cyber.red, Cyber.panel]),
        border: Border.all(color: Cyber.red.withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.style, color: Cyber.red, size: 16),
    );
  }
}

class SelectedMovePanel extends StatelessWidget {
  const SelectedMovePanel({
    required this.attacking,
    required this.player,
    required this.action,
    required this.estimate,
    super.key,
  });

  final bool attacking;
  final PlayerCard? player;
  final ActionCard? action;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    final playerRoleLabel = attacking ? 'ATKR' : 'DEFR';
    final selectionTitle = attacking ? 'ATTACKER' : 'DEFENDER';
    final roleAccent = attacking ? Cyber.cyan : Cyber.violet;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final playerFrameWidth = compact ? 118.0 : 132.0;
        final playerFrameHeight = compact ? 152.0 : 164.0;
        final actionFrameWidth = compact ? 104.0 : 116.0;
        final actionFrameHeight = compact ? 138.0 : 150.0;
        final gap = compact ? 12.0 : 18.0;

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff121a29), Color(0xff0a0f19)],
            ),
            border: Border.all(
              color: estimate == null
                  ? Cyber.line
                  : roleAccent.withValues(alpha: 0.6),
            ),
            boxShadow: estimate == null
                ? null
                : [
                    BoxShadow(
                      color: roleAccent.withValues(alpha: 0.14),
                      blurRadius: 20,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 3,
                  color: roleAccent.withValues(alpha: 0.7),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '01 / SELECT $selectionTitle',
                            style: Cyber.label(
                              compact ? 14 : 15,
                              color: Colors.white,
                              weight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MoveArenaSlot(
                            label: playerRoleLabel,
                            value: player?.name ?? 'PLAYER PENDING',
                            accent: roleAccent,
                            frameWidth: playerFrameWidth,
                            frameHeight: playerFrameHeight,
                            child: player == null
                                ? _PendingSelectionBox(
                                    icon: Icons.person_search,
                                    label: 'PICK PLAYER',
                                    accent: roleAccent,
                                  )
                                : CyberPlayerCardTile(
                                    card: player!,
                                    selected: true,
                                    selectedAccent: roleAccent,
                                    size: VisualCardSize.sm,
                                  ),
                          ),
                        ),
                        SizedBox(width: gap),
                        _ArenaCenterColumn(estimate: estimate),
                        SizedBox(width: gap),
                        Expanded(
                          child: _MoveArenaSlot(
                            label: 'ACTION',
                            value: action?.title ?? 'ACTION PENDING',
                            accent: roleAccent,
                            frameWidth: actionFrameWidth,
                            frameHeight: actionFrameHeight,
                            child: action == null
                                ? _PendingSelectionBox(
                                    icon: Icons.grid_view_rounded,
                                    label: 'PICK ACTION',
                                    accent: roleAccent,
                                  )
                                : CyberActionCardTile(
                                    card: action!,
                                    selected: true,
                                    selectedAccent: roleAccent,
                                    size: VisualCardSize.sm,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoveArenaSlot extends StatelessWidget {
  const _MoveArenaSlot({
    required this.label,
    required this.value,
    required this.accent,
    required this.frameWidth,
    required this.frameHeight,
    required this.child,
  });

  final String label;
  final String value;
  final Color accent;
  final double frameWidth;
  final double frameHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Text(
            label,
            style: Cyber.label(11, color: accent, letterSpacing: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: frameWidth,
            height: frameHeight,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xaa0b1019),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Center(child: child),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Text(
            value.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: Cyber.displayFont,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingSelectionBox extends StatelessWidget {
  const _PendingSelectionBox({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 122,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent.withValues(alpha: 0.72), size: 28),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaCenterColumn extends StatelessWidget {
  const _ArenaCenterColumn({required this.estimate});

  final int? estimate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          const SizedBox(height: 44),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Cyber.bg,
              border: Border.all(color: Cyber.gold),
            ),
            child: Text('VS', style: Cyber.display(18, color: Cyber.gold)),
          ),
          const SizedBox(height: 12),
          if (estimate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Cyber.gold.withValues(alpha: 0.08),
                border: Border.all(color: Cyber.gold.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    'POWER',
                    textAlign: TextAlign.center,
                    style: Cyber.label(
                      9,
                      color: Cyber.gold.withValues(alpha: 0.8),
                      weight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${estimate!}-${estimate! + 20}',
                    textAlign: TextAlign.center,
                    style: Cyber.display(
                      14,
                      color: Cyber.gold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class LoadoutStatusPanel extends StatelessWidget {
  const LoadoutStatusPanel({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '> LOADOUT STATUS',
            style: TextStyle(
              color: Cyber.cyan.withValues(alpha: 0.68),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  'ATK',
                  '${state.deckAttackers.length}/2',
                  state.deckAttackers.length == 2,
                ),
              ),
              Expanded(
                child: MiniStat(
                  'DEF',
                  '${state.deckDefenders.length}/2',
                  state.deckDefenders.length == 2,
                ),
              ),
              Expanded(
                child: MiniStat(
                  'ACT',
                  '${state.deckActions.length}/6',
                  state.deckActions.length == 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MatchHistoryPanel extends StatelessWidget {
  const MatchHistoryPanel({required this.history, super.key});

  final List<MatchHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final preview = history.take(3).toList();
    return CyberPanel(
      accent: Cyber.cyan,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MATCH HISTORY',
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.68),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showMatchHistoryArchive(context, history),
                child: Text(history.isEmpty ? 'OPEN' : 'VIEW ALL'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            history.isEmpty
                ? 'No matches played yet — go win some glory.'
                : 'Tap any result to inspect the scoreline, deck, and round log.',
            style: const TextStyle(
              color: Cyber.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (preview.isEmpty)
            GestureDetector(
              onTap: () => showMatchHistoryArchive(context, history),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Cyber.bg.withValues(alpha: 0.38),
                  border: Border.all(color: Cyber.line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history, color: Cyber.cyan),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Archive terminal ready. Your next finished match will appear here.',
                        style: TextStyle(
                          color: Color(0xffd1d5db),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < preview.length; i++) ...[
              MatchHistoryTile(
                entry: preview[i],
                onTap: () => showMatchHistoryDetail(context, preview[i]),
              ),
              if (i < preview.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class MatchHistoryHeaderButton extends StatelessWidget {
  const MatchHistoryHeaderButton({required this.history, super.key});

  final List<MatchHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showMatchHistoryArchive(context, history),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.42),
              border: Border.all(color: Cyber.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history, color: Cyber.cyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  'HISTORY',
                  style: TextStyle(
                    color: history.isEmpty ? Cyber.muted : Cyber.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MatchHistoryTile extends StatelessWidget {
  const MatchHistoryTile({required this.entry, required this.onTap, super.key});

  final MatchHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (entry.resultLabel) {
      'Victory' => Cyber.success,
      'Defeat' => Cyber.danger,
      'Podium' => Cyber.gold,
      'Points' => Cyber.cyan,
      _ => Cyber.amber,
    };
    final resultIcon = switch (entry.resultLabel) {
      'Victory' => Icons.emoji_events,
      'Defeat' => Icons.sentiment_dissatisfied,
      'Podium' => Icons.military_tech,
      'Points' => Icons.flag,
      _ when entry.isGrandPrix => Icons.sports_motorsports,
      _ when entry.isBasketball => Icons.sports_basketball,
      _ => Icons.balance,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          border: Border(
            left: BorderSide(color: accent, width: 3),
            top: BorderSide(color: accent.withValues(alpha: 0.22)),
            right: BorderSide(color: accent.withValues(alpha: 0.22)),
            bottom: BorderSide(color: accent.withValues(alpha: 0.22)),
          ),
        ),
        child: Row(
          children: [
            // Result accent sidebar
            Container(
              width: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.09),
                border: Border(
                  right: BorderSide(color: accent.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(resultIcon, color: accent, size: 20),
                  const SizedBox(height: 3),
                  Text(
                    entry.resultLabel[0].toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.deckName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Orbitron',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        // Score — races show a finishing position, not a
                        // head-to-head scoreline.
                        if (entry.isGrandPrix)
                          Row(
                            children: [
                              Text(
                                'P${entry.playerScore}',
                                style: Cyber.display(18, color: accent),
                              ),
                              Text(
                                '/${entry.opponentScore}',
                                style: TextStyle(
                                  color: Cyber.muted,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Text(
                                '${entry.playerScore}',
                                style: Cyber.display(18, color: Cyber.cyan),
                              ),
                              Text(
                                ' – ',
                                style: TextStyle(
                                  color: Cyber.muted,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${entry.opponentScore}',
                                style: Cyber.display(18, color: Cyber.danger),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          historyTimestampLabel(entry.timestampIso),
                          style: const TextStyle(
                            color: Cyber.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (entry.isShootout) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Cyber.violet.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Cyber.violet.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'SHOOTOUT',
                              style: TextStyle(
                                color: Cyber.violet,
                                fontSize: 9,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        if (entry.isGrandPrix) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Cyber.f1Red.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Cyber.f1Red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'GRAND PRIX',
                              style: TextStyle(
                                color: Cyber.f1Red,
                                fontSize: 9,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        if (entry.isBasketball) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Cyber.gold.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Cyber.gold.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'HOOP DUEL',
                              style: TextStyle(
                                color: Cyber.gold,
                                fontSize: 9,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        if (entry.penaltyPlayerScore != null) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Cyber.violet.withValues(alpha: 0.14),
                              border: Border.all(
                                color: Cyber.violet.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              'PEN ${entry.penaltyPlayerScore}–${entry.penaltyOpponentScore}',
                              style: const TextStyle(
                                color: Cyber.violet,
                                fontSize: 9,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        if (entry.xpEarned != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (entry.xpEarned! >= 0
                                          ? Cyber.cyan
                                          : const Color(0xFFFF4D6A))
                                      .withValues(alpha: 0.14),
                              border: Border.all(
                                color:
                                    (entry.xpEarned! >= 0
                                            ? Cyber.cyan
                                            : const Color(0xFFFF4D6A))
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              entry.xpEarned! >= 0
                                  ? '+${entry.xpEarned} XP'
                                  : '${entry.xpEarned} XP',
                              style: TextStyle(
                                color: entry.xpEarned! >= 0
                                    ? Cyber.cyan
                                    : const Color(0xFFFF4D6A),
                                fontSize: 9,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right,
                          color: Cyber.cyan,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectionWrap<T> extends StatelessWidget {
  const SelectionWrap({
    required this.cards,
    required this.selectedIds,
    required this.enabled,
    required this.builder,
    required this.onToggle,
    required this.isDisabled,
    super.key,
  });

  final List<T> cards;
  final List<String> selectedIds;
  final bool enabled;
  final Widget Function(T card, bool selected, bool disabled) builder;
  final ValueChanged<T> onToggle;
  final bool Function(T card) isDisabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final card in cards)
            GestureDetector(
              onTap: enabled ? () => onToggle(card) : null,
              child: builder(
                card,
                selectedIds.contains(switch (card) {
                  PlayerCard c => c.id,
                  ActionCard c => c.id,
                  _ => '',
                }),
                isDisabled(card),
              ),
            ),
        ],
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.primaryOnTap,
    required this.secondaryLabel,
    required this.secondaryOnTap,
    this.tertiaryLabel,
    this.tertiaryOnTap,
    super.key,
  });

  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback primaryOnTap;
  final String secondaryLabel;
  final VoidCallback secondaryOnTap;
  final String? tertiaryLabel;
  final VoidCallback? tertiaryOnTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tertiaryLabel != null && tertiaryOnTap != null) ...[
              GestureDetector(
                onTap: tertiaryOnTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: Cyber.violet.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        color: Cyber.violet,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tertiaryLabel!.toUpperCase(),
                        style: const TextStyle(
                          color: Cyber.violet,
                          fontFamily: 'Orbitron',
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: CyberCtaButton(
                    label: secondaryLabel,
                    onPressed: secondaryOnTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CyberCtaButton(
                    label: primaryLabel,
                    primary: true,
                    onPressed: primaryEnabled ? primaryOnTap : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.55)),
              gradient: RadialGradient(
                colors: [Cyber.cyan.withValues(alpha: 0.25), Cyber.panel2],
              ),
            ),
            child: Icon(icon, size: 28, color: Cyber.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Cyber.cyan,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: Cyber.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreboardPanel extends StatelessWidget {
  const ScoreboardPanel({required this.state, this.label, super.key});

  final GameState state;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final inMatch =
        label == null && state.currentRound >= 1 && state.currentRound <= 4;
    final opponentFirstName = (state.opponentName ?? 'OPP')
        .split(RegExp(r'\s+'))
        .first
        .toUpperCase();
    final opponentLabel = opponentFirstName.length <= 7
        ? '[P2] $opponentFirstName'
        : '[P2] OPP';
    return Container(
      decoration: BoxDecoration(
        // Glass HUD: rgba(13,17,26,0.85).
        color: Cyber.bg.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Cyber.cyan.withValues(alpha: 0.28)),
          bottom: BorderSide(color: Cyber.danger.withValues(alpha: 0.32)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _HudIdentity(
              label: '[P1] YOU',
              score: state.playerScore,
              color: Cyber.cyan,
              alignRight: false,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label ?? 'RD ${max(1, state.currentRound)} / 4',
                style: const TextStyle(
                  color: Cyber.cyan,
                  fontSize: 10,
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text('VS', style: Cyber.display(16, color: Colors.white)),
              if (inMatch) ...[
                const SizedBox(height: 4),
                _RoleBadge(attacking: state.playerAttacking),
              ],
            ],
          ),
          Expanded(
            child: _HudIdentity(
              label: opponentLabel,
              score: state.opponentScore,
              color: Cyber.danger,
              alignRight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.attacking});
  final bool attacking;

  @override
  Widget build(BuildContext context) {
    final color = attacking ? Cyber.cyan : Cyber.violet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        attacking ? ' ATTACKING' : ' DEFENDING',
        style: TextStyle(
          color: color,
          fontFamily: Cyber.bodyFont,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _HudIdentity extends StatefulWidget {
  const _HudIdentity({
    required this.label,
    required this.score,
    required this.color,
    required this.alignRight,
  });

  final String label;
  final int score;
  final Color color;
  final bool alignRight;

  @override
  State<_HudIdentity> createState() => _HudIdentityState();
}

class _HudIdentityState extends State<_HudIdentity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void didUpdateWidget(_HudIdentity old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) _bounce.forward(from: 0);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignRight
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: widget.alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontFamily: 'Onest',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          AnimatedBuilder(
            animation: _bounce,
            builder: (context, child) {
              final scale = 1 + sin(_bounce.value * pi) * 0.3;
              return Transform.scale(
                scale: scale,
                alignment: widget.alignRight
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: child,
              );
            },
            child: Text(
              '${widget.score}',
              style: Cyber.display(36, color: Cyber.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class CardList<T> extends StatelessWidget {
  const CardList({
    required this.cards,
    required this.selectedIds,
    required this.builder,
    required this.onToggle,
    required this.enabled,
    super.key,
  });

  final List<T> cards;
  final List<String> selectedIds;
  final Widget Function(T card, bool selected) builder;
  final ValueChanged<T> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final card = cards[index];
        final id = switch (card) {
          PlayerCard c => c.id,
          ActionCard c => c.id,
          _ => '',
        };
        return Opacity(
          opacity: enabled ? 1 : 0.72,
          child: InkWell(
            onTap: enabled ? () => onToggle(card) : null,
            child: builder(card, selectedIds.contains(id)),
          ),
        );
      },
    );
  }
}

class PlayerCardTile extends StatelessWidget {
  const PlayerCardTile({
    required this.card,
    required this.selected,
    this.onTap,
    super.key,
  });

  final PlayerCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: tierColor(card.tier),
          child: Icon(card.icon, color: Colors.black),
        ),
        title: Text(
          card.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${card.countryCode} - ${card.trait} - ${card.position}',
        ),
        trailing: Text(
          '${card.rating}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class ActionCardTile extends StatelessWidget {
  const ActionCardTile({
    required this.card,
    required this.selected,
    this.onTap,
    super.key,
  });

  final ActionCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(card.icon)),
        title: Text(
          card.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${card.category.name.toUpperCase()} - ${card.effect}${card.risky ? ' - Risky' : ''}',
        ),
        trailing: Text(
          '+${card.power}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Cyber.cyan.withValues(alpha: 0.18)
            : Cyber.panel,
        foregroundColor: selected ? Cyber.cyan : Cyber.muted,
        side: BorderSide(color: selected ? Cyber.cyan : Cyber.line),
      ),
      child: Text(label),
    );
  }
}
