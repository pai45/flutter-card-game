import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/match.dart';
import '../../models/progression.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../../screens/match_history/match_history_pages.dart';
import 'widgets/shootout_arena_background.dart';
import 'widgets/shootout_emblem.dart';

/// Penalty Shootout lobby — mirrors the Pitch Duel home (stats, hero, CTAs) but
/// with its own arena backdrop and the targeting-reticle emblem.
class ShootoutHomeScreen extends StatelessWidget {
  const ShootoutHomeScreen({
    required this.onNavigate,
    this.onBack,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Cyber.bg,
          appBar: ReactHeaderBar(
            title: 'Penalty Shootout',
            leftSlot: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: Cyber.lime,
                  ),
            rightSlot: PlayerLevelBadge(
              progression: state.progression,
              track: ProgressTrack.shootout,
            ),
          ),
          body: ShootoutArenaBackground(
            // Arena art stays full-bleed; inset the scroll content above the
            // gesture bar so the PLAY CTA isn't clipped.
            child: SafeArea(
              top: false,
              child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CyberSlideUpFadeIn(child: _ShootoutStatusBar()),
                      const SizedBox(height: 18),
                      // Hero: targeting emblem + wordmark + deck status.
                      CyberSlideUpFadeIn(
                        delay: const Duration(milliseconds: 80),
                        offset: 24,
                        child: Row(
                          children: [
                            const ShootoutEmblem(size: 92),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PENALTY\nSHOOTOUT',
                                    style:
                                        Cyber.display(24, letterSpacing: 1.2)
                                            .copyWith(
                                              height: 1.05,
                                              shadows: [
                                                Shadow(
                                                  color: Cyber.lime.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius: 14,
                                                ),
                                              ],
                                            ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'SUDDEN-DEATH SPOT KICKS',
                                    style: TextStyle(
                                      color: Cyber.muted,
                                      fontFamily: Cyber.displayFont,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: CyberChip(
                                      label: state.deckReady
                                          ? 'SQUAD READY'
                                          : 'SQUAD INCOMPLETE',
                                      color: state.deckReady
                                          ? Cyber.lime
                                          : Cyber.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Telemetry row — real data, no glow.
                      Row(
                        children: [
                          Expanded(
                            child: CyberDealtCard(
                              key: const ValueKey('shootout-stat-level'),
                              index: 0,
                              initialDelay: const Duration(milliseconds: 180),
                              flyDistance: 130,
                              child: _HudStat(
                                label: 'LEVEL',
                                value:
                                    '${state.progression.levelFor(ProgressTrack.shootout)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CyberDealtCard(
                              key: const ValueKey('shootout-stat-xp'),
                              index: 1,
                              initialDelay: const Duration(milliseconds: 180),
                              flyDistance: 130,
                              child: _HudStat(
                                label: 'MODE XP',
                                value: _grp(
                                  state.progression.xpFor(
                                    ProgressTrack.shootout,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CyberDealtCard(
                              key: const ValueKey('shootout-stat-won'),
                              index: 2,
                              initialDelay: const Duration(milliseconds: 180),
                              flyDistance: 130,
                              child: _HudStat(
                                label: 'WON',
                                value: '${_shootoutWins(state.matchHistory)}',
                                accent: Cyber.lime,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // PLAY SHOOTOUT — hero CTA, gated on a ready squad.
                      CyberSlideUpFadeIn(
                        delay: const Duration(milliseconds: 390),
                        offset: 22,
                        child: state.deckReady
                            ? HudCtaButton(
                                label: 'PLAY SHOOTOUT',
                                onTap: () => onNavigate(AppSection.shootout),
                              )
                            : Opacity(
                                opacity: 0.45,
                                child: IgnorePointer(
                                  child: HudCtaButton(
                                    label: 'PLAY SHOOTOUT',
                                    onTap: () {},
                                  ),
                                ),
                              ),
                      ),
                      if (!state.deckReady) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Build a full squad (2 ATK · 2 DEF · 1 GK) to take the spot.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Cyber.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: CyberDealtCard(
                              key: const ValueKey('shootout-action-deck'),
                              index: 0,
                              initialDelay: const Duration(milliseconds: 470),
                              staggerMs: 85,
                              flyDistance: 95,
                              duration: const Duration(milliseconds: 500),
                              child: CyberCtaButton(
                                label: 'Deck Builder',
                                clip: false,
                                onPressed: () => onNavigate(AppSection.deck),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CyberDealtCard(
                              key: const ValueKey('shootout-action-history'),
                              index: 1,
                              initialDelay: const Duration(milliseconds: 470),
                              staggerMs: 85,
                              flyDistance: 95,
                              duration: const Duration(milliseconds: 500),
                              child: CyberCtaButton(
                                label: 'Match History',
                                clip: false,
                                onPressed: () => showGameMatchHistory(
                                  context,
                                  gameLabel: 'Shootout',
                                  history: state.matchHistory
                                      .where((e) => e.isShootout)
                                      .toList(growable: false),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}

/// Groups an integer with thousands separators ("3870" -> "3,870").
String _grp(int value) {
  final s = value.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}$b';
}

int _shootoutWins(List<MatchHistoryEntry> history) => history
    .where((e) => e.isShootout && e.playerScore > e.opponentScore)
    .length;

/// Greeble status strip: a live indicator + a system readout.
class _ShootoutStatusBar extends StatelessWidget {
  const _ShootoutStatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Cyber.lime,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(Cyber.lime, alpha: 0.6, blur: 8, spread: 0),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'ARMED',
          style: TextStyle(
            color: Cyber.lime,
            fontFamily: Cyber.displayFont,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Cyber.lime.withValues(alpha: 0.16),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SYS://SHOOTOUT v1.0.0',
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: Cyber.displayFont,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// A compact telemetry cell (label + value). Secondary data — no glow.
class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.label,
    required this.value,
    this.accent = Cyber.lime,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
