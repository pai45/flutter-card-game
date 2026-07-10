import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../utils/prediction_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/team_logo.dart';

/// Fixture card on the prediction home — a faithful build of the design
/// reference. A neutral dark-navy panel (NOT league-tinted) with:
///   • a square top edge + chamfered bottom corners, and a drop shadow that
///     follows that chamfer (see [_CyberCardBorder]);
///   • a centred status line — kickoff time (gold), "• LIVE n'" (red), or a
///     notched "Finished" tab hanging off the top edge;
///   • mirrored team badges (single chamfered outer-bottom corner + a bright
///     bottom accent edge) with the team name beneath;
///   • football score in the centre / cricket innings under each name;
///   • a full-width bottom strip whose chamfered corners match the card:
///       - upcoming + open → bluer "Make prediction and …" CTA (focal),
///       - upcoming + predicted → calm "Predicted … ago",
///       - finished + predicted + unsettled → gold "Results ready" CTA (focal),
///       - finished + predicted + settled → the user's earned "△ +N XP",
///       - finished, no prediction → the fixture's "△ +N XP",
///       - live → no strip.
class MatchPredictionCard extends StatelessWidget {
  const MatchPredictionCard({
    required this.match,
    required this.prediction,
    this.quiz,
    this.onTap,
    super.key,
  });

  final SportMatch match;
  final UserPrediction? prediction;
  final PredictionQuiz? quiz;
  final VoidCallback? onTap;

  bool get _predicted => prediction != null;
  bool get _finished => match.status == MatchStatus.finished;

  @override
  Widget build(BuildContext context) {
    final borderColor = _stateBorderColor(match, prediction);
    final body = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cardTop, _cardBottom],
        ),
      ),
      child: Padding(
        // Extra top room so the teams clear the notch cut into the top edge.
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TeamsRow(match: match, dimNames: _finished),
            if (match.resultLine != null) ...[
              const SizedBox(height: 12),
              Text(
                match.resultLine!,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  11.5,
                  color: _resultCol,
                  weight: FontWeight.w600,
                ),
              ),
              // Reserve room so the bottom strip (an overlay, not part of this
              // Column's own height) doesn't sit on top of this text.
              if (match.status != MatchStatus.live)
                const SizedBox(height: _stripReserve),
            ],
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              playSound(SoundEffect.uiTap);
              onTap!();
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hard, un-blurred drop shadow drawn behind the card — tinted with the
          // state colour so the elevated bottom edge matches the border.
          Positioned.fill(
            child: CustomPaint(
              painter: _HardShadowPainter(borderColor.withValues(alpha: 0.25)),
            ),
          ),
          Material(
            color: _cardBase,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: _CyberCardBorder(
              cut: 12,
              notchWidth: _notchFloorW,
              notchDepth: _notchDepth,
              notchSlope: _notchSlope,
              side: BorderSide(
                color: borderColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [body]),
          ),
          // Bottom strip gets drawn above the shadow but below the notch
          if (match.status != MatchStatus.live)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: _StripClipper(cut: 12),
                child: _StatusStrip(
                  match: match,
                  prediction: prediction,
                  quiz: quiz,
                  predicted: _predicted,
                  submittedAt: prediction?.submittedAt,
                ),
              ),
            ),
          // The status tag sits inside the notch, reading against the page
          // background that shows through the cut.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _notchDepth,
            child: Center(child: _TagContent(match: match)),
          ),
        ],
      ),
    );
  }
}

class _StripClipper extends CustomClipper<Path> {
  const _StripClipper({required this.cut});
  final double cut;

  @override
  Path getClip(Size size) {
    final r = Offset.zero & size;
    return Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.bottom - cut)
      ..lineTo(r.right - cut, r.bottom)
      ..lineTo(r.left + cut, r.bottom)
      ..lineTo(r.left, r.bottom - cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant _StripClipper oldClipper) => oldClipper.cut != cut;
}

// ── Status tag content (sits inside the top notch, against the background) ─────
class _TagContent extends StatelessWidget {
  const _TagContent({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return switch (match.status) {
      MatchStatus.upcoming => Text(
        _formatTime(match.kickoff),
        style: Cyber.body(13, color: _timeGold, weight: FontWeight.w700)
            .copyWith(
              letterSpacing: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
      MatchStatus.live => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Cyber.danger,
              boxShadow: Cyber.glow(Cyber.danger, alpha: 0.8, blur: 7),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            match.liveMinute != null ? "LIVE ${match.liveMinute}'" : 'LIVE',
            style: Cyber.body(
              12.5,
              color: Cyber.danger,
              weight: FontWeight.w800,
            ).copyWith(letterSpacing: 0.8),
          ),
        ],
      ),
      MatchStatus.finished => Text(
        'Finished',
        style: Cyber.body(
          11,
          color: Cyber.muted,
          weight: FontWeight.w600,
        ).copyWith(letterSpacing: 0.4),
      ),
    };
  }
}

// ── Teams + score row ─────────────────────────────────────────────────────────
class _TeamsRow extends StatelessWidget {
  const _TeamsRow({required this.match, required this.dimNames});
  final SportMatch match;
  final bool dimNames;

  @override
  Widget build(BuildContext context) {
    // Cricket shows each side's innings, F1 shows each constructor's finishing
    // grid position, under the team name; football keeps the score centred.
    final perTeamScores =
        (match.sport == Sport.cricket || match.sport == Sport.f1) &&
        match.hasScore;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TeamColumn(
            team: match.home,
            alignEnd: false,
            dim: dimNames,
            scoreLine: perTeamScores ? match.homeScore : null,
          ),
        ),
        _ScoreCentre(match: match),
        Expanded(
          child: _TeamColumn(
            team: match.away,
            alignEnd: true,
            dim: dimNames,
            scoreLine: perTeamScores ? match.awayScore : null,
          ),
        ),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.team,
    required this.alignEnd,
    required this.dim,
    this.scoreLine,
  });

  final SportTeam team;
  final bool alignEnd;
  final bool dim;
  final String? scoreLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Mirror the badge chamfer toward the centre of the card.
        _TeamBadge(team: team, cutBottomRight: !alignEnd),
        const SizedBox(height: 8),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.body(
            14.5,
            color: dim ? _dimName : Colors.white,
            weight: FontWeight.w700,
          ),
        ),
        if (scoreLine != null) ...[
          const SizedBox(height: 3),
          Text(
            scoreLine!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              10.5,
              color: _scoreSub,
              weight: FontWeight.w600,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ],
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team, required this.cutBottomRight});
  final SportTeam team;
  final bool cutBottomRight;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      team: team,
      width: 46,
      height: 46,
      cutBottomRight: cutBottomRight,
    );
  }
}

class _ScoreCentre extends StatelessWidget {
  const _ScoreCentre({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if ((match.sport == Sport.football || match.sport == Sport.basketball) && match.hasScore) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '${match.homeScore ?? '-'}  -  ${match.awayScore ?? '-'}',
          style: Cyber.display(
            21,
            color: Colors.white,
            letterSpacing: 0.5,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
    }
    if (match.sport == Sport.f1 && match.status == MatchStatus.finished) {
      // Grid position lives under each team name; the centre carries the
      // chequered-flag cue instead of a football-style score dash.
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.sports_motorsports, color: Cyber.muted, size: 20),
      );
    }
    // Upcoming, or cricket/F1 (line lives under each name) → centre dash.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '-',
        style: TextStyle(
          color: Cyber.muted,
          fontFamily: Cyber.displayFont,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ── Bottom status strip ───────────────────────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.match,
    required this.prediction,
    required this.quiz,
    required this.predicted,
    required this.submittedAt,
  });

  final SportMatch match;
  final UserPrediction? prediction;
  final PredictionQuiz? quiz;
  final bool predicted;
  final DateTime? submittedAt;

  @override
  Widget build(BuildContext context) {
    // If it's a quiz, use the quiz-specific UI
    if (quiz != null) {
      final answered = prediction?.answers.length ?? 0;
      final total = quiz!.questions.length;
      final potentialXp = quiz!.maxReward;
      final isSettled = prediction?.status == PredictionStatus.settled;
      final correct = prediction?.correctCount ?? 0;
      
      if (match.status == MatchStatus.upcoming) {
        return _Strip(
          fill: _stripDark,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'QUIZ $answered/$total',
                  style: Cyber.label(
                    9,
                    color: Cyber.muted,
                    letterSpacing: 0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  'POTENTIAL +$potentialXp XP',
                  style: Cyber.label(
                    9,
                    color: Cyber.cyan.withValues(alpha: 0.85),
                    letterSpacing: 0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      if (match.status == MatchStatus.finished) {
        if (!isSettled && (prediction != null || quiz!.settleable)) {
          return _Strip(
            fill: _stripDark,
            topBorder: Cyber.gold.withValues(alpha: 0.35),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.redeem, color: Cyber.gold, size: 14),
                const SizedBox(width: 7),
                Text(
                  'RESULTS READY — TAP TO REVEAL',
                  style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1)
                      .copyWith(
                        shadows: [
                          Shadow(
                            color: Cyber.gold.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                ),
              ],
            ),
          );
        }
        
        if (isSettled) {
          final isWon = correct > 0;
          return _Strip(
            fill: _stripDark,
            topBorder: (isWon ? Cyber.success : Cyber.red).withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (isWon) ...[
                    const Icon(Icons.trending_up, color: Cyber.success, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      '+${prediction!.rewardEarned} XP',
                      style: Cyber.body(
                        12,
                        color: Cyber.success,
                        weight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ] else ...[
                    Text(
                      '$correct/$total CORRECT',
                      style: Cyber.label(
                        9,
                        color: Cyber.muted,
                        letterSpacing: 0.8,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const Spacer(),
                  _OutcomeDots(
                    outcomes: questionOutcomes(quiz!, prediction!),
                    compact: true,
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    // Fallback/classic match status strip
    if (match.status == MatchStatus.finished &&
        prediction != null &&
        prediction!.status != PredictionStatus.settled) {
      return _Strip(
        fill: _stripDark,
        topBorder: Cyber.gold.withValues(alpha: 0.28),
        child: Text(
          'RESULTS READY — TAP TO REVEAL',
          style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1)
              .copyWith(
                shadows: [
                  Shadow(
                    color: Cyber.gold.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
        ),
      );
    }

    final settledXp = prediction?.status == PredictionStatus.settled
        ? prediction!.rewardEarned
        : null;
    final rewardXp = settledXp ?? match.rewardXp;
    if (match.status == MatchStatus.finished && rewardXp > 0) {
      return _Strip(
        fill: _stripDark,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.change_history, color: Cyber.cyan, size: 15),
            const SizedBox(width: 6),
            Text(
              '+$rewardXp XP',
              style:
                  Cyber.body(
                    12.5,
                    color: Cyber.cyan,
                    weight: FontWeight.w700,
                  ).copyWith(
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      );
    }

    if (match.status == MatchStatus.upcoming && predicted) {
      return _Strip(
        fill: _stripDark,
        child: Text(
          'Predicted ${_timeAgo(submittedAt)}',
          style: Cyber.body(
            12.5,
            color: _predictedText,
            weight: FontWeight.w500,
          ),
        ),
      );
    }

    if (match.status == MatchStatus.upcoming && match.prizeLabel != null) {
      return _Strip(
        fill: _stripBlue,
        topBorder: Cyber.cyan.withValues(alpha: 0.28),
        child: Text(
          'Make prediction and ${match.prizeLabel}',
          style: Cyber.body(13, color: Cyber.cyan, weight: FontWeight.w700)
              .copyWith(
                shadows: [
                  Shadow(
                    color: Cyber.cyan.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _OutcomeDots extends StatelessWidget {
  const _OutcomeDots({required this.outcomes, this.compact = false});

  final List<QuestionOutcome> outcomes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 4.0 : 5.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < outcomes.length; i++) ...[
          _OutcomeDot(outcome: outcomes[i], compact: compact),
          if (i != outcomes.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class _OutcomeDot extends StatelessWidget {
  const _OutcomeDot({required this.outcome, required this.compact});

  final QuestionOutcome outcome;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (outcome) {
      QuestionOutcome.correct => Cyber.success,
      QuestionOutcome.wrong => Cyber.red,
      QuestionOutcome.pending => Cyber.muted,
    };
    final icon = switch (outcome) {
      QuestionOutcome.correct => Icons.check,
      QuestionOutcome.wrong => Icons.close,
      QuestionOutcome.pending => Icons.more_horiz,
    };
    final box = compact ? 13.0 : 17.0;
    final iconSize = compact ? 9.0 : 11.0;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

// ── Shape: square top, chamfered bottom corners — used for the shadow + border ─
class _Strip extends StatelessWidget {
  const _Strip({required this.fill, required this.child, this.topBorder});
  final Color fill;
  final Widget child;
  final Color? topBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          top: BorderSide(
            color: topBorder ?? Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _CyberCardBorder extends ShapeBorder {
  const _CyberCardBorder({
    this.cut = 12,
    this.notchWidth = 0,
    this.notchDepth = 0,
    this.notchSlope = 0,
    this.side = BorderSide.none,
  });

  final double cut;

  /// Top-centre notch (floor width / depth / diagonal run). With a positive
  /// width + depth the top edge dips into a trapezoidal cut so the background
  /// shows through and the status tag can sit inside it.
  final double notchWidth;
  final double notchDepth;
  final double notchSlope;
  final BorderSide side;

  Path _build(Rect r) => _cardPath(r, cut, notchWidth, notchDepth, notchSlope);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _build(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _build(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      _build(rect.deflate(side.width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  ShapeBorder scale(double t) => _CyberCardBorder(
    cut: cut * t,
    notchWidth: notchWidth * t,
    notchDepth: notchDepth * t,
    notchSlope: notchSlope * t,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => this;
}

/// The card silhouette: square top with a centred trapezoidal notch, chamfered
/// bottom corners. Shared by [_CyberCardBorder] (clip + border + stroke) and
/// [_HardShadowPainter] (the offset drop shadow).
Path _cardPath(
  Rect r,
  double cut,
  double notchWidth,
  double notchDepth,
  double notchSlope,
) {
  final path = Path()..moveTo(r.left, r.top);
  if (notchWidth > 0 && notchDepth > 0) {
    final cx = r.center.dx;
    final half = notchWidth / 2;
    path
      ..lineTo(cx - half - notchSlope, r.top) // top edge → notch opening
      ..lineTo(cx - half, r.top + notchDepth) // diagonal down-in
      ..lineTo(cx + half, r.top + notchDepth) // notch floor
      ..lineTo(cx + half + notchSlope, r.top); // diagonal up-out
  }
  return path
    ..lineTo(r.right, r.top)
    ..lineTo(r.right, r.bottom - cut)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..close();
}

/// A hard (un-blurred) drop shadow: the card silhouette filled with a solid dark
/// colour and shifted straight down, drawn behind the card for an "embossed"
/// elevated feel without a soft blur.
class _HardShadowPainter extends CustomPainter {
  const _HardShadowPainter(this.color);

  /// Fill colour of the elevated bottom edge — the card's state border colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cardPath(
      Offset.zero & size,
      12,
      _notchFloorW,
      _notchDepth,
      _notchSlope,
    ).shift(const Offset(0, 6));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HardShadowPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Palette (card-local, tuned to the reference) ──────────────────────────────
const _cardBase = Color(0xff141c2b);
const _cardTop = Color(0xff1b2336);
const _cardBottom = Color(0xff121a28);
const _borderCol = Color(0xff2a3550);
const _borderPredicted = Color(
  0xff2c7a8c,
); // dark cyan — predicted, not started
const _stripDark = Color(0xff0f1826);
const _stripBlue = Color(0xff173a5e);
const _timeGold = Color(0xffc8a45a);
const _dimName = Color(0xffaeb7c5);
const _scoreSub = Color(0xff9fb0c2);
const _resultCol = Color(0xffbac5d3);
const _predictedText = Color(0xff93a1b2);

// Top-centre notch geometry (shared by the card shape + the tag overlay).
const _notchFloorW = 96.0;
const _notchDepth = 22.0;
const _notchSlope = 12.0;

// Approximate rendered height of the single-line bottom strip (11 vertical
// padding × 2 + a line of 9-13pt text) — the strip is a Stack overlay, not a
// Column child, so its own height isn't otherwise reserved.
const _stripReserve = 44.0;

// ── Helpers ───────────────────────────────────────────────────────────────────
/// The card border colour telegraphs where the fixture sits in its lifecycle:
/// dark cyan = yet to begin (predicted or not), red = live, gold = results ready
/// to reveal, cyan = revealed. Mirrors the bottom strip's existing cues.
Color _stateBorderColor(SportMatch match, UserPrediction? prediction) {
  switch (match.status) {
    case MatchStatus.live:
      return Cyber.danger; // red — started
    case MatchStatus.upcoming:
      return _borderPredicted; // dark cyan — yet to begin
    case MatchStatus.finished:
      if (prediction == null) return _borderCol; // neutral edge
      return prediction.status == PredictionStatus.settled
          ? Cyber
                .cyan // cyan — revealed
          : _timeGold; // gold — results ready
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _timeAgo(DateTime? dt) {
  if (dt == null) return 'just now';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
}
