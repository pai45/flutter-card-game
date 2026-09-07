import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/cricket_match_data.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/player_match_sheet.dart';

/// Which side of a player's match the tape is showing.
enum InningsTapeMode { batting, bowling }

/// A player's match as a sequence of deliveries.
///
/// This is cricket's answer to the football heatmap, and it is deliberately a
/// timeline rather than a map: ESPN publishes no coordinates for cricket at
/// all, so there is nothing honest to plot in space. What it does publish is
/// every ball with the batter and bowler named, which makes the *shape* of an
/// innings — dot pressure, boundary bursts, when the wicket fell — readable at
/// a glance.
class CricketInningsTape extends StatelessWidget {
  const CricketInningsTape({
    required this.stats,
    required this.mode,
    required this.accent,
    super.key,
  });

  final CricketPlayerMatchStats stats;
  final InningsTapeMode mode;
  final Color accent;

  List<CricketDelivery> get _balls =>
      mode == InningsTapeMode.batting ? stats.faced : stats.bowled;

  @override
  Widget build(BuildContext context) {
    if (_balls.isEmpty) {
      return CyberNoDataState(
        icon: Icons.timeline,
        title: 'No ball-by-ball',
        message: mode == InningsTapeMode.batting
            ? 'This player did not face a delivery in this match.'
            : 'This player did not bowl in this match.',
        accent: Cyber.muted,
        spark: Icons.timer_off_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberPanel(
          accent: accent,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          // Keyed by mode and length so switching bat/bowl replays the stagger
          // instead of tweening one sequence into the other.
          child: TweenAnimationBuilder<double>(
            key: ValueKey('tape-$mode-${_balls.length}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, reveal, _) => mode == InningsTapeMode.batting
                ? _BallTape(balls: _balls, accent: accent, reveal: reveal)
                : _SpellBars(balls: _balls, accent: accent, reveal: reveal),
          ),
        ),
        const SizedBox(height: 12),
        _PhaseStrip(stats: stats, mode: mode, accent: accent),
      ],
    );
  }
}

/// Every ball the batter faced, in bowling order.
class _BallTape extends StatelessWidget {
  const _BallTape({
    required this.balls,
    required this.accent,
    required this.reveal,
  });

  final List<CricketDelivery> balls;
  final Color accent;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var i = 0; i < balls.length; i++)
              _BallChip(
                delivery: balls[i],
                // A per-ball stagger: the tape fills in the order it was
                // bowled, which is the whole point of showing it as a tape.
                progress: ((reveal * balls.length * 1.2) - i).clamp(0.0, 1.0),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const _TapeLegend(),
      ],
    );
  }
}

class _BallChip extends StatelessWidget {
  const _BallChip({required this.delivery, required this.progress});

  final CricketDelivery delivery;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final (colour, label, filled) = _style(delivery);
    return Opacity(
      opacity: progress,
      child: Transform.scale(
        scale: 0.7 + 0.3 * progress,
        child: ClipPath(
          clipper: const HudChamferClipper(bigCut: 6, smallCut: 2),
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled
                  ? colour.withValues(alpha: 0.22)
                  : Cyber.bg.withValues(alpha: 0.5),
              border: Border.all(
                color: colour.withValues(alpha: filled ? 0.85 : 0.3),
              ),
              // The wicket is the only glow on the tape — it is the one moment
              // that ended something.
              boxShadow: delivery.isWicket
                  ? Cyber.glow(Cyber.danger, alpha: 0.45, blur: 7)
                  : null,
            ),
            child: Text(
              label,
              style: Cyber.display(
                delivery.isWicket ? 10 : 9.5,
                color: colour,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      ),
    );
  }

  /// Colour, glyph and whether the chip reads as filled.
  ///
  /// The ramp is semantic, NOT team-keyed. A club whose accent is red (RCB) or
  /// gold would otherwise render an ordinary single as an alert and a good
  /// over as a warning — the same trap the football heatmap hit. Team identity
  /// lives in the panel border and the headline figure instead. A dot is
  /// deliberately hollow and muted so a long dot sequence reads as pressure.
  static (Color, String, bool) _style(CricketDelivery ball) {
    if (ball.isWicket) return (Cyber.danger, 'W', true);
    return switch (ball.outcome) {
      CricketBallOutcome.six => (Cyber.amber, '6', true),
      CricketBallOutcome.four => (Cyber.lime, '4', true),
      CricketBallOutcome.wide => (Cyber.muted, 'wd', false),
      CricketBallOutcome.legBye => (Cyber.muted, 'lb', false),
      CricketBallOutcome.dot => (Cyber.muted, '•', false),
      _ => (Cyber.cyan, '${ball.runsOffTheBat}', ball.runsOffTheBat > 0),
    };
  }
}

class _TapeLegend extends StatelessWidget {
  const _TapeLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _LegendMark(colour: Cyber.muted, label: 'DOT'),
        _LegendMark(colour: Cyber.cyan, label: 'RUNS'),
        _LegendMark(colour: Cyber.lime, label: 'FOUR'),
        _LegendMark(colour: Cyber.amber, label: 'SIX'),
        _LegendMark(colour: Cyber.danger, label: 'WICKET'),
      ],
    );
  }
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, color: colour.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Cyber.label(7, color: Cyber.muted, letterSpacing: 1),
        ),
      ],
    );
  }
}

/// A bowler's spell, over by over.
class _SpellBars extends StatelessWidget {
  const _SpellBars({
    required this.balls,
    required this.accent,
    required this.reveal,
  });

  final List<CricketDelivery> balls;
  final Color accent;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final overs = <int, ({int runs, int wickets, int balls})>{};
    for (final ball in balls) {
      final current = overs[ball.over] ?? (runs: 0, wickets: 0, balls: 0);
      overs[ball.over] = (
        runs: current.runs + ball.runs,
        wickets: current.wickets + (ball.isWicket ? 1 : 0),
        balls: current.balls + (ball.countsAsBallFaced ? 1 : 0),
      );
    }
    final ordered = overs.keys.toList()..sort();
    // Scale against this bowler's worst over so the shape of their own spell
    // reads, rather than against a league-wide constant.
    final peak = overs.values.fold<int>(1, (m, o) => o.runs > m ? o.runs : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          Opacity(
            opacity: ((reveal * ordered.length * 1.3) - i).clamp(0.0, 1.0),
            child: _SpellRow(
              over: ordered[i],
              data: overs[ordered[i]]!,
              peak: peak,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpellRow extends StatelessWidget {
  const _SpellRow({
    required this.over,
    required this.data,
    required this.peak,
  });

  final int over;
  final ({int runs, int wickets, int balls}) data;
  final int peak;

  @override
  Widget build(BuildContext context) {
    // A four-step quality ramp, deliberately independent of the club colour:
    // a wicket over is good, twelve-plus is expensive, six or fewer is tidy.
    final colour = data.wickets > 0
        ? Cyber.lime
        : data.runs >= 12
        ? Cyber.danger
        : data.runs <= 6
        ? Cyber.cyan
        : Cyber.amber;
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            'OV$over',
            style: Cyber.label(
              7.5,
              color: Cyber.muted,
              letterSpacing: 0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: CyberProgressBar(
            value: (data.runs / peak).clamp(0.0, 1.0),
            accent: colour,
            height: 12,
            animate: false,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            data.wickets > 0 ? '${data.runs} · ${data.wickets}W' : '${data.runs}',
            textAlign: TextAlign.right,
            style: Cyber.display(
              11,
              color: data.wickets > 0 ? Cyber.lime : Colors.white,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

/// POWERPLAY / MIDDLE / DEATH — how a player's match split across the phases
/// everyone actually reads a T20 in.
class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({
    required this.stats,
    required this.mode,
    required this.accent,
  });

  final CricketPlayerMatchStats stats;
  final InningsTapeMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final phase in CricketMatchPhase.values) ...[
          if (phase != CricketMatchPhase.powerplay) const SizedBox(width: 8),
          if (mode == InningsTapeMode.batting)
            _battingCell(phase)
          else
            _bowlingCell(phase),
        ],
      ],
    );
  }

  Widget _battingCell(CricketMatchPhase phase) {
    final split = stats.battingPhase(phase);
    return CountUpMetric(
      label: phase.label,
      value: split.runs.toDouble(),
      format: (v) =>
          split.balls == 0 ? '—' : '${v.round()} (${split.balls})',
      accent: split.balls == 0 ? null : accent,
    );
  }

  Widget _bowlingCell(CricketMatchPhase phase) {
    final split = stats.bowlingPhase(phase);
    return CountUpMetric(
      label: phase.label,
      value: split.runs.toDouble(),
      format: (v) => split.balls == 0
          ? '—'
          : split.wickets > 0
          ? '${v.round()} · ${split.wickets}W'
          : '${v.round()}',
      accent: split.wickets > 0 ? Cyber.lime : null,
    );
  }
}
