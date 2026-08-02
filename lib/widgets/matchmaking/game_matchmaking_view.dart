import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../cyber/cyber_cta_button.dart';
import '../cyber/cyber_widgets.dart';
import '../game_scaffold.dart';
import 'game_matchmaking_config.dart';
import 'matchmaking_arena_background.dart';

/// Cinematic matchmaking beat: player banner → queue scan → locked rival.
///
/// Does not own post-lock gameplay handoff beyond [onMatched] / [onCancel].
class GameMatchmakingView extends StatefulWidget {
  const GameMatchmakingView({
    required this.config,
    required this.onMatched,
    required this.onCancel,
    super.key,
  });

  final GameMatchmakingConfig config;
  final VoidCallback onMatched;
  final VoidCallback onCancel;

  @override
  State<GameMatchmakingView> createState() => _GameMatchmakingViewState();
}

class _GameMatchmakingViewState extends State<GameMatchmakingView>
    with TickerProviderStateMixin {
  static const _searchDuration = Duration(milliseconds: 2600);
  static const _rivalRevealDuration = Duration(milliseconds: 360);
  static const _foundHold = Duration(milliseconds: 700);
  static const _reducedMotionHold = Duration(milliseconds: 180);

  late final AnimationController _search = AnimationController(
    vsync: this,
    duration: _searchDuration,
  );
  late final AnimationController _vsPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  Timer? _advanceTimer;
  bool _opponentAvatarPrecached = false;
  bool _locked = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _search.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _lockOpponent(reducedMotion: MediaQuery.disableAnimationsOf(context));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cancelled) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _search.value = 1;
        _lockOpponent(reducedMotion: true);
      } else {
        playSound(SoundEffect.riser);
        _search.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opponentAvatarPrecached) return;
    _opponentAvatarPrecached = true;
    unawaited(
      precacheImage(
        AssetImage(widget.config.opponent.avatarAsset),
        context,
      ),
    );
  }

  void _lockOpponent({required bool reducedMotion}) {
    if (!mounted || _locked || _cancelled) return;
    setState(() => _locked = true);
    playSound(SoundEffect.commit);
    HapticFeedback.heavyImpact();

    final handoffDelay = reducedMotion
        ? _reducedMotionHold
        : _rivalRevealDuration + _foundHold;
    _advanceTimer = Timer(handoffDelay, () {
      if (!mounted || _cancelled) return;
      widget.onMatched();
    });
  }

  void _cancelMatchmaking() {
    if (_cancelled) return;
    _cancelled = true;
    _advanceTimer?.cancel();
    _search.stop();
    _vsPulse.stop();
    widget.onCancel();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _search.dispose();
    _vsPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final player = config.player;
    final opponent = config.opponent;
    final playerAccent = player.accent ?? config.searchAccent;
    final opponentAccent = opponent.accent ?? config.lockedAccent;

    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: config.title,
        subtitle: config.subtitle,
      ),
      body: MatchmakingArenaBackground(
        asset: config.backgroundAsset,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
              final dockHeight = 104 + bottomInset;
              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, dockHeight + 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 420,
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - dockHeight - 36,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CyberMatchmakingPlayerBanner(
                                name: player.name,
                                avatarAsset: player.avatarAsset,
                                frame: player.frame,
                                badge: player.badge,
                                accent: playerAccent,
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: _MatchmakingVsMedallion(
                                  animation: _vsPulse,
                                  locked: _locked,
                                  searchAccent: config.searchAccent,
                                  lockedAccent: config.lockedAccent,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 136,
                                child: AnimatedSwitcher(
                                  duration: Duration(
                                    milliseconds:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? 100
                                        : _rivalRevealDuration.inMilliseconds,
                                  ),
                                  switchInCurve: Curves.easeOutBack,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.10),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _locked
                                      ? CyberMatchmakingPlayerBanner(
                                          key: const ValueKey(
                                            'matchmaking-opponent-banner',
                                          ),
                                          name: opponent.name,
                                          avatarAsset: opponent.avatarAsset,
                                          accent: opponentAccent,
                                          frame: opponent.frame,
                                          badge: opponent.badge,
                                          mirrored: true,
                                        )
                                      : _SearchingStatus(
                                          key: const ValueKey(
                                            'matchmaking-searching-status',
                                          ),
                                          animation: _search,
                                          queueLabel: config.queueLabel,
                                          accent: config.searchAccent,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _CancelDock(
                      bottomInset: bottomInset,
                      onCancel: _cancelMatchmaking,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SearchingStatus extends StatelessWidget {
  const _SearchingStatus({
    required this.animation,
    required this.queueLabel,
    required this.accent,
    super.key,
  });

  final Animation<double> animation;
  final String queueLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SEARCHING FOR\nOPPONENT...',
              textAlign: TextAlign.center,
              style: Cyber.display(
                24,
                color: Colors.white,
                letterSpacing: 1.5,
              ).copyWith(height: 1.18),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: CyberProgressBar(
                value: animation.value,
                accent: accent,
                height: 5,
                radius: 2,
                animate: false,
                trackColor: Cyber.line.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              queueLabel,
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.5),
            ),
          ],
        );
      },
    );
  }
}

class _MatchmakingVsMedallion extends StatelessWidget {
  const _MatchmakingVsMedallion({
    required this.animation,
    required this.locked,
    required this.searchAccent,
    required this.lockedAccent,
  });

  final Animation<double> animation;
  final bool locked;
  final Color searchAccent;
  final Color lockedAccent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final accent = locked ? lockedAccent : searchAccent;
        final pulse = 0.5 - 0.5 * math.cos(animation.value * math.pi * 2);
        return SizedBox(
          width: 116,
          height: 116,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: animation.value * math.pi * 2,
                child: CustomPaint(
                  size: const Size.square(116),
                  painter: _VsOrbitPainter(accent: accent, pulse: pulse),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 82,
                height: 82,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cyber.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                  boxShadow: Cyber.glow(
                    accent,
                    alpha: 0.30 + pulse * 0.14,
                    blur: 18 + pulse * 8,
                    spread: 0,
                  ),
                ),
                child: Text(
                  'VS',
                  style: Cyber.display(
                    28,
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VsOrbitPainter extends CustomPainter {
  const _VsOrbitPainter({required this.accent, required this.pulse});

  final Color accent;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: 0.24 + pulse * 0.18);
    canvas.drawCircle(center, radius - 8, ring);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 3
      ..color = accent.withValues(alpha: 0.72);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -0.2, 1.05, false, arc);
    canvas.drawArc(rect, math.pi - 0.2, 1.05, false, arc);
  }

  @override
  bool shouldRepaint(covariant _VsOrbitPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.pulse != pulse;
}

class _CancelDock extends StatelessWidget {
  const _CancelDock({required this.bottomInset, required this.onCancel});

  final double bottomInset;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Cyber.bg.withValues(alpha: 0.88),
            Cyber.bg,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 18, 24, 24 + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: HudCtaButton(
              label: 'CANCEL',
              icon: Icons.close,
              height: 58,
              accent: Cyber.danger,
              glow: false,
              tapSound: SoundEffect.uiTap,
              onTap: onCancel,
            ),
          ),
        ),
      ),
    );
  }
}
