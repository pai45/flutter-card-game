import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../data/super_over_batter_profiles.dart';
import '../../data/super_over_jerseys.dart';
import '../../games/super_over/cricket_rig.dart';
import '../../models/cards.dart';
import '../../models/super_over.dart';
import '../../models/super_over_stats.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../match_history/match_history_pages.dart';

class SuperOverLobbyScreen extends StatelessWidget {
  const SuperOverLobbyScreen({
    required this.onBack,
    required this.onStartGame,
    required this.onEditDeck,
    required this.onJerseySelected,
    required this.selectedMode,
    required this.onModeChanged,
    required this.stats,
    this.onTutorial,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onStartGame;
  final VoidCallback onEditDeck;
  final ValueChanged<CricketJersey> onJerseySelected;
  final SuperOverMode selectedMode;
  final ValueChanged<SuperOverMode> onModeChanged;
  final SuperOverStats stats;
  final VoidCallback? onTutorial;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) =>
          p.progression != c.progression ||
          p.superOverDeckReady != c.superOverDeckReady ||
          p.deckBatsmen != c.deckBatsmen ||
          p.matchHistory != c.matchHistory,
      builder: (context, gameState) {
        final ready = gameState.superOverDeckReady;
        final batsmen = gameState.deckBatsmen;
        final avg = _averageRating(batsmen);

        return Scaffold(
          backgroundColor: Cyber.bg,
          appBar: ReactHeaderBar(
            title: 'SUPER OVER',
            subtitle: '// 2D CRICKET ARCADE',
            onBack: onBack,
            rightSlot: PlayerLevelBadge(progression: gameState.progression),
          ),
          body: _SuperOverArenaBackground(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 380,
                          minHeight: math.max(0, constraints.maxHeight - 44),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CyberSlideUpFadeIn(
                                child: _LobbyStatusBar(ready: ready),
                              ),
                              const SizedBox(height: 18),
                              CyberSlideUpFadeIn(
                                delay: const Duration(milliseconds: 80),
                                offset: 24,
                                child: _HeroBlock(
                                  ready: ready,
                                  avgRating: avg,
                                  jersey: stats.lastJersey,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const SectionLabel(label: 'PLAY MODE'),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ModeCard(
                                      mode: SuperOverMode.chase,
                                      selected:
                                          selectedMode == SuperOverMode.chase,
                                      icon: Icons.flag_outlined,
                                      subtitle: 'BEAT THE TARGET',
                                      onTap: () =>
                                          onModeChanged(SuperOverMode.chase),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ModeCard(
                                      mode: SuperOverMode.scoreAttack,
                                      selected:
                                          selectedMode ==
                                          SuperOverMode.scoreAttack,
                                      icon: Icons.bolt,
                                      subtitle: 'MAX RUNS / 6 BALLS',
                                      onTap: () => onModeChanged(
                                        SuperOverMode.scoreAttack,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _BattingOrderPanel(
                                batsmen: batsmen,
                                stats: stats,
                                onEdit: onEditDeck,
                              ),
                              const SizedBox(height: 18),
                              _RecordPanel(stats: stats),
                              const SizedBox(height: 20),
                              const SectionLabel(label: 'TEAM JERSEY'),
                              const SizedBox(height: 10),
                              CyberSlideUpFadeIn(
                                delay: const Duration(milliseconds: 320),
                                offset: 16,
                                child: _JerseyPicker(
                                  selected: stats.lastJersey,
                                  onSelect: (jersey) {
                                    HapticFeedback.selectionClick();
                                    playSound(SoundEffect.uiTap);
                                    onJerseySelected(jersey);
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              CyberSlideUpFadeIn(
                                delay: const Duration(milliseconds: 390),
                                offset: 22,
                                child: HudCtaButton(
                                  label: ready
                                      ? 'START ${selectedMode.label}'
                                      : 'ADD BATTERS',
                                  icon: ready
                                      ? Icons.keyboard_double_arrow_right
                                      : Icons.add,
                                  helper: ready
                                      ? 'AVG OVR $avg  /  6 BALLS  /  2 WICKETS'
                                      : 'FILL THREE BATTING SLOTS',
                                  tapSound: ready
                                      ? SoundEffect.playMatch
                                      : SoundEffect.uiTap,
                                  accent: ready ? Cyber.cyan : Cyber.amber,
                                  onTap: ready ? onStartGame : onEditDeck,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'super-over-action-deck',
                                      ),
                                      index: 0,
                                      initialDelay: const Duration(
                                        milliseconds: 470,
                                      ),
                                      staggerMs: 85,
                                      flyDistance: 95,
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      child: CyberCtaButton(
                                        key: const ValueKey(
                                          'super-over-deck-builder-button',
                                        ),
                                        label: ready
                                            ? 'Edit Batters'
                                            : 'Deck Builder',
                                        clip: false,
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          playSound(SoundEffect.uiTap);
                                          onEditDeck();
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CyberDealtCard(
                                      key: const ValueKey(
                                        'super-over-action-history',
                                      ),
                                      index: 1,
                                      initialDelay: const Duration(
                                        milliseconds: 470,
                                      ),
                                      staggerMs: 85,
                                      flyDistance: 95,
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      child: CyberCtaButton(
                                        key: const ValueKey(
                                          'super-over-match-history-button',
                                        ),
                                        label: 'Match History',
                                        clip: false,
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          playSound(SoundEffect.uiTap);
                                          showMatchHistoryArchive(
                                            context,
                                            gameState.matchHistory
                                                .where(
                                                  (entry) =>
                                                      entry.mode ==
                                                      'super_over',
                                                )
                                                .toList(),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (onTutorial != null) ...[
                                const SizedBox(height: 12),
                                CyberCtaButton(
                                  key: const ValueKey(
                                    'super-over-tutorial-button',
                                  ),
                                  label: stats.tutorialCompleted
                                      ? 'Replay Tutorial'
                                      : 'How To Play',
                                  clip: false,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    playSound(SoundEffect.uiTap);
                                    onTutorial!();
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),
                              const CyberSlideUpFadeIn(
                                delay: Duration(milliseconds: 650),
                                offset: 14,
                                child: _ModeHint(),
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
    );
  }
}

int _averageRating(List<PlayerCard> batsmen) {
  if (batsmen.isEmpty) return 0;
  return (batsmen.fold<int>(0, (sum, card) => sum + card.rating) /
          batsmen.length)
      .round();
}

class _LobbyStatusBar extends StatelessWidget {
  const _LobbyStatusBar({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final status = ready ? 'ONLINE' : 'LOADOUT';
    final color = ready ? Cyber.success : Cyber.amber;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(color, alpha: 0.6, blur: 8, spread: 0),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: TextStyle(
            color: color,
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
            color: Cyber.cyan.withValues(alpha: 0.16),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SYS://SUPER_OVER v1.0.0',
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: Cyber.displayFont,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.ready,
    required this.avgRating,
    required this.jersey,
  });

  final bool ready;
  final int avgRating;
  final CricketJersey jersey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CricketHeroEmblem(size: 104, jersey: jersey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPER OVER',
                style: Cyber.display(26, letterSpacing: 1.4).copyWith(
                  shadows: [
                    Shadow(
                      color: Cyber.cyan.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'READ. AIM. STRIKE.',
                style: TextStyle(
                  color: Cyber.muted,
                  fontFamily: Cyber.displayFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  CyberChip(
                    label: ready ? 'DECK ONLINE' : 'DECK NEEDED',
                    color: ready ? Cyber.lime : Cyber.amber,
                  ),
                  if (avgRating > 0)
                    CyberChip(label: 'AVG $avgRating OVR', color: Cyber.cyan),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CricketHeroEmblem extends StatefulWidget {
  const _CricketHeroEmblem({required this.size, required this.jersey});

  final double size;
  final CricketJersey jersey;

  @override
  State<_CricketHeroEmblem> createState() => _CricketHeroEmblemState();
}

class _CricketHeroEmblemState extends State<_CricketHeroEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = .5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final jersey = cricketJerseySpec(widget.jersey);
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final phase = _pulse.value * math.pi * 2;
          final glow = 0.5 + 0.5 * math.sin(phase * 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cyber.bg.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Cyber.cyan.withValues(alpha: 0.28 + glow * 0.14),
                  ),
                  boxShadow: Cyber.glow(
                    Cyber.cyan,
                    alpha: 0.18 + glow * 0.08,
                    blur: 18 + glow * 5,
                    spread: -4,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, math.sin(phase * 2) * 1.5),
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _HeroBatterPainter(
                    primary: jersey.primary,
                    accent: jersey.accent,
                    phase: phase,
                  ),
                ),
              ),
              CustomPaint(
                size: Size.square(size),
                painter: _CornerBracketsPainter(
                  Cyber.cyan.withValues(alpha: 0.64 + glow * 0.14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBatterPainter extends CustomPainter {
  const _HeroBatterPainter({
    required this.primary,
    required this.accent,
    required this.phase,
  });

  final Color primary;
  final Color accent;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final bowler = bowlerPose(
      runProgress: .62 + math.sin(phase) * .08,
      time: phase,
      isDeliveryActive: true,
    );
    CricketRigPainter.drawBowlerRig(
      canvas,
      Offset(size.width * .53, size.height * .42),
      bowler,
      primary: const Color(0xff252d42),
      accent: const Color(0xff9da9c7),
      skin: const Color(0xff8f5e45),
      scale: size.width * .19,
      holdingBall: false,
    );
    final trajectory = Path()
      ..moveTo(size.width * .53, size.height * .36)
      ..quadraticBezierTo(
        size.width * .67,
        size.height * .55,
        size.width * .52,
        size.height * .7,
      );
    canvas.drawPath(
      trajectory,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          colors: [
            Cyber.cyan.withValues(alpha: 0),
            Cyber.cyan.withValues(alpha: .85),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(size.width * .52, size.height * .7),
      2.4,
      Paint()..color = Colors.white,
    );
    final pose = batsmanPose(
      swing: -0.20 + math.sin(phase) * 0.05,
      time: phase,
      onFire: false,
    );
    CricketRigPainter.drawBatsmanRig(
      canvas,
      Offset(size.width * 0.48, size.height * 0.93),
      pose,
      primary: primary,
      accent: accent,
      skin: const Color(0xffb97852),
      scale: size.width * 0.42,
      onFire: false,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroBatterPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.accent != accent ||
      oldDelegate.phase != phase;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.subtitle,
    required this.onTap,
  });

  final SuperOverMode mode;
  final bool selected;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Cyber.lime : Cyber.cyan;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('super-over-mode-${mode.name}'),
        onTap: onTap,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 66,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accent, size: 19),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle, color: accent, size: 16),
                  ],
                ),
                const Spacer(),
                Text(mode.label, style: Cyber.display(10, color: Colors.white)),
                const SizedBox(height: 3),
                Text(subtitle, style: Cyber.label(7, color: Cyber.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BattingOrderPanel extends StatelessWidget {
  const _BattingOrderPanel({
    required this.batsmen,
    required this.stats,
    required this.onEdit,
  });

  final List<PlayerCard> batsmen;
  final SuperOverStats stats;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SectionLabel(label: 'BATTING UNIT'),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                child: Text('EDIT', style: Cyber.display(8, color: Cyber.cyan)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (batsmen.isEmpty)
            Text('ADD THREE BATTERS TO DEPLOY', style: Cyber.label(9))
          else
            ...batsmen.take(3).indexed.map((entry) {
              final orderIndex = entry.$1;
              final batter = entry.$2;
              final profile = SuperOverBatterProfiles.fromCard(
                batter,
                orderIndex: orderIndex,
              );
              final xp = stats.batterMastery[batter.id] ?? 0;
              final level = 1 + xp ~/ 100;
              final style = profile.archetype;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Cyber.bg,
                        border: Border.all(
                          color: Cyber.cyan.withValues(alpha: .4),
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            color: Cyber.cyan.withValues(alpha: .82),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 1,
                            child: Text(
                              '${orderIndex + 1}',
                              style: Cyber.display(7, color: Cyber.gold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(9, color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profile.archetypeLabel} // OVR ${profile.rating}',
                            style: Cyber.label(7, color: Cyber.muted),
                          ),
                          const SizedBox(height: 5),
                          CyberProgressBar(
                            value: (xp % 100) / 100,
                            accent: style == CricketBattingStyle.powerHitter
                                ? Cyber.gold
                                : Cyber.lime,
                            animate: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LV $level',
                      style: Cyber.display(8, color: Cyber.cyan),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});

  final SuperOverStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _RecordItem(
        label: 'ATTACK',
        value: '${stats.scoreAttackHighScore}',
        accent: Cyber.gold,
      ),
      _RecordItem(
        label: 'WINS',
        value: '${stats.chaseWins}',
        accent: Cyber.lime,
      ),
      _RecordItem(
        label: 'PERFECT',
        value: '${stats.perfectContacts}',
        accent: Cyber.lime,
      ),
      _RecordItem(
        label: 'SIXES',
        value: '${stats.totalSixes}',
        accent: Cyber.cyan,
      ),
      _RecordItem(
        label: 'COMBO',
        value: '${stats.bestCombo}',
        accent: Cyber.violet,
      ),
    ];

    return Row(
      children: List.generate(items.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 7),
            child: CyberDealtCard(
              key: ValueKey('super-over-stat-$index'),
              index: index,
              initialDelay: const Duration(milliseconds: 220),
              staggerMs: 55,
              flyDistance: 90,
              duration: const Duration(milliseconds: 460),
              child: _RecordStat(item: items[index]),
            ),
          ),
        );
      }),
    );
  }
}

class _RecordItem {
  const _RecordItem({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;
}

class _RecordStat extends StatelessWidget {
  const _RecordStat({required this.item});

  final _RecordItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.56),
        border: Border.all(color: item.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.value,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 7.4,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.75,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeHint extends StatelessWidget {
  const _ModeHint();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        _HudLink(label: 'AIM / CHOOSE / SWING'),
        Text('/', style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1)),
        _HudLink(label: 'READ THE FIELD', faint: true),
      ],
    );
  }
}

class _HudLink extends StatelessWidget {
  const _HudLink({required this.label, this.faint = false});

  final String label;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: faint ? Cyber.cyan.withValues(alpha: 0.55) : Cyber.cyan,
        fontFamily: Cyber.displayFont,
        fontSize: faint ? 9 : 10,
        fontWeight: faint ? FontWeight.w800 : FontWeight.w900,
        letterSpacing: faint ? 2 : 1.4,
      ),
    );
  }
}

class _SuperOverArenaBackground extends StatefulWidget {
  const _SuperOverArenaBackground({required this.child});

  final Widget child;

  @override
  State<_SuperOverArenaBackground> createState() =>
      _SuperOverArenaBackgroundState();
}

class _SuperOverArenaBackgroundState extends State<_SuperOverArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff020812), Color(0xff071522), Color(0xff02050b)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value * math.pi * 2;
                return Transform.translate(
                  offset: Offset(math.sin(phase) * 8, math.cos(phase) * 6),
                  child: Transform.scale(
                    scale: 1.05 + 0.008 * math.sin(phase * 2),
                    child: child,
                  ),
                );
              },
              child: Opacity(
                opacity: 0.22,
                child: Image.asset(
                  'assets/backgrounds/home_stadium.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) =>
                  CustomPaint(painter: _ArenaMotionPainter(_controller.value)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0.28),
                    Cyber.bg.withValues(alpha: 0.08),
                    Cyber.bg.withValues(alpha: 0.66),
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
          widget.child,
        ],
      ),
    );
  }
}

class _ArenaMotionPainter extends CustomPainter {
  const _ArenaMotionPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final phase = progress * math.pi * 2;
    final pulse = 0.5 + 0.5 * math.sin(phase * 2);

    final fieldGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.72),
        radius: 0.88,
        colors: [
          Cyber.cyan.withValues(alpha: 0.08 + pulse * 0.035),
          Cyber.lime.withValues(alpha: 0.026),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, fieldGlow);

    _drawBeam(
      canvas,
      size,
      start: Offset(size.width * 0.08, size.height * 0.72),
      end: Offset(size.width * (0.42 + math.sin(phase) * 0.06), 0),
      width: size.width * 0.42,
      opacity: 0.026 + pulse * 0.016,
    );
    _drawBeam(
      canvas,
      size,
      start: Offset(size.width * 0.92, size.height * 0.72),
      end: Offset(size.width * (0.58 + math.cos(phase) * 0.06), 0),
      width: size.width * 0.42,
      opacity: 0.026 + (1 - pulse) * 0.016,
    );

    final streakPaint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final seed = i * 37.0;
      final x = ((seed * 19) % size.width) + math.sin(phase + i) * 18;
      final travel = (progress + i * 0.071) % 1.0;
      final y = size.height * (0.96 - travel * 0.82);
      final length = 12.0 + (i % 4) * 5.0;
      final opacity = 0.025 + 0.03 * math.sin(phase + i).abs();
      streakPaint.color = Cyber.cyan.withValues(alpha: opacity);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + length * 0.42, y - length),
        streakPaint,
      );
    }
  }

  void _drawBeam(
    Canvas canvas,
    Size size, {
    required Offset start,
    required Offset end,
    required double width,
    required double opacity,
  }) {
    final path = Path()
      ..moveTo(start.dx - width * 0.5, start.dy)
      ..lineTo(start.dx + width * 0.5, start.dy)
      ..lineTo(end.dx + width * 0.08, end.dy)
      ..lineTo(end.dx - width * 0.08, end.dy)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Cyber.cyan.withValues(alpha: opacity),
          Cyber.cyan.withValues(alpha: opacity * 0.35),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size)
      ..blendMode = BlendMode.plus;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArenaMotionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const len = 11.0;
    final points = [
      (Offset.zero, Offset(len, 0), Offset(0, len)),
      (
        Offset(size.width, 0),
        Offset(size.width - len, 0),
        Offset(size.width, len),
      ),
      (
        Offset(0, size.height),
        Offset(len, size.height),
        Offset(0, size.height - len),
      ),
      (
        Offset(size.width, size.height),
        Offset(size.width - len, size.height),
        Offset(size.width, size.height - len),
      ),
    ];
    for (final (corner, horizontal, vertical) in points) {
      canvas
        ..drawLine(corner, horizontal, p)
        ..drawLine(corner, vertical, p);
    }
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Sponsor-free jersey picker with a procedural batter preview.
class _JerseyPicker extends StatelessWidget {
  const _JerseyPicker({required this.selected, required this.onSelect});

  final CricketJersey selected;
  final ValueChanged<CricketJersey> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cricketJerseys.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final spec = cricketJerseys[index];
          final isSelected = spec.jersey == selected;
          return GestureDetector(
            onTap: () => onSelect(spec.jersey),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.alphaBlend(
                        spec.primary.withValues(alpha: 0.12),
                        Cyber.panel,
                      )
                    : Cyber.panel,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Cyber.border.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: CricketJerseyPreviewPainter(
                        spec.primary,
                        spec.accent,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
