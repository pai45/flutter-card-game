import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../data/random_opponent_names.dart';
import '../../models/cards.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/squad_faceoff.dart';

/// "SEARCHING FOR OPPONENT" cinematic → kickoff face-off. The radar scans the
/// 500-name pool, locks onto the matched rival, then the two squads square up
/// across a glowing VS (same DNA as the penalty-shootout face-off) before
/// kickoff. The opponent is CPU; the scan + card reveal sell a live-PvP feel.
class FootballChessMatchmakingScreen extends StatefulWidget {
  const FootballChessMatchmakingScreen({
    required this.playerLevel,
    required this.playerSquad,
    required this.opponentName,
    required this.opponentLevel,
    required this.opponentSquad,
    required this.onKickoff,
    required this.onCancel,
    super.key,
  });

  final int playerLevel;
  final List<PlayerCard> playerSquad;
  final String opponentName;
  final int opponentLevel;
  final List<PlayerCard> opponentSquad;

  final VoidCallback onKickoff;
  final VoidCallback onCancel;

  @override
  State<FootballChessMatchmakingScreen> createState() =>
      _FootballChessMatchmakingScreenState();
}

class _FootballChessMatchmakingScreenState
    extends State<FootballChessMatchmakingScreen>
    with TickerProviderStateMixin {
  final Random _random = Random();
  late final AnimationController _radar;
  late final AnimationController _faceoff;
  Timer? _scanTimer;
  Timer? _lockTimer;

  String _ticker = '';
  bool _locked = false;

  static const _searchMs = 2400;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _faceoff = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    playSound(SoundEffect.riser);
    _scanTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      setState(() => _ticker =
          randomOpponentNames[_random.nextInt(randomOpponentNames.length)]);
    });
    _lockTimer = Timer(const Duration(milliseconds: _searchMs), _lockOn);
  }

  void _lockOn() {
    _scanTimer?.cancel();
    if (!mounted) return;
    playSound(SoundEffect.commit);
    HapticFeedback.heavyImpact();
    setState(() {
      _locked = true;
      _ticker = widget.opponentName;
    });
    _faceoff.forward();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _lockTimer?.cancel();
    _radar.dispose();
    _faceoff.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberBackground(
        animated: true,
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Cyber.muted),
                  onPressed: () {
                    playSound(SoundEffect.uiTap);
                    widget.onCancel();
                  },
                ),
              ),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _locked ? _reveal() : _searching(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searching() {
    return Column(
      key: const ValueKey('searching'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _RadarPulse(animation: _radar),
        const SizedBox(height: 28),
        Text(
          'SEARCHING FOR OPPONENT',
          style: Cyber.label(13, color: Cyber.cyan, letterSpacing: 2.4),
        ),
        const SizedBox(height: 12),
        Text(
          _ticker.toUpperCase(),
          style: TextStyle(
            fontFamily: Cyber.displayFont,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SCANNING GLOBAL POOL // 500 ONLINE',
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.6),
        ),
      ],
    );
  }

  Widget _reveal() {
    return SingleChildScrollView(
      key: const ValueKey('reveal'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'OPPONENT FOUND',
            style: Cyber.label(12, color: Cyber.gold, letterSpacing: 3),
          ),
          const SizedBox(height: 6),
          Text(
            'LV ${widget.playerLevel}  VS  LV ${widget.opponentLevel}',
            style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.6),
          ),
          const SizedBox(height: 16),
          SquadFaceoff(
            reveal: _faceoff,
            topLabel: 'YOUR SQUAD',
            topSquad: widget.playerSquad,
            topAccent: Cyber.cyan,
            bottomLabel: '${widget.opponentName.toUpperCase()} SQUAD',
            bottomSquad: widget.opponentSquad,
            bottomAccent: Cyber.magenta,
          ),
          const SizedBox(height: 24),
          HudCtaButton(
            label: 'KICKOFF',
            icon: Icons.sports_soccer,
            tapSound: SoundEffect.playMatch,
            onTap: widget.onKickoff,
          ),
        ],
      ),
    );
  }
}

/// Concentric sweeping rings — the "scanning" radar at the heart of the search.
class _RadarPulse extends StatelessWidget {
  const _RadarPulse({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(animation.value),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final f in [0.4, 0.7, 1.0]) {
      ring.color = Cyber.cyan.withValues(alpha: 0.18);
      canvas.drawCircle(center, maxR * f, ring);
    }
    final sweepR = maxR * t;
    canvas.drawCircle(
      center,
      sweepR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.cyan.withValues(alpha: (1 - t).clamp(0.0, 1.0)),
    );
    canvas.drawCircle(center, 4, Paint()..color = Cyber.cyan);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}
