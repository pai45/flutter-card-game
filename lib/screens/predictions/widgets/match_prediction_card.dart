import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';
import 'pick_status_style.dart';

/// Fixture card on the prediction home — a faithful build of the design
/// reference. A neutral dark-navy panel (NOT league-tinted) with:
///   • a square top edge + chamfered bottom corners, and a drop shadow that
///     follows that chamfer (see [_CyberCardBorder]);
///   • a centred status line — kickoff time (gold), "• LIVE n'" (red), or a
///     notched "Finished" tab hanging off the top edge;
///   • mirrored team badges (single chamfered outer-bottom corner + a bright
///     bottom accent edge) with the team name beneath;
///   • football score in the centre / cricket innings under each name;
///   • a full-width bottom strip whose chamfered corners match the card, read
///     like a live market — potential XP on the left, Total Vol (Oz) on the
///     right — and telegraphing lifecycle:
///       - upcoming → "POTENTIAL +N XP"  |  "VOL … OZ" (✓ prefix if predicted),
///       - live → "● IN PLAY"            |  "VOL … OZ",
///       - finished + reward pending → focal gold, breathing
///         "◆ RESULTS ARE OUT — TAP TO REVEAL" (the reveal cinematic runs onTap),
///       - finished + revealed → "+N XP" | coins P&L ("±N OZ") if the player
///         staked, else "VOL … OZ",
///       - finished, no engagement → "FULL TIME" | "VOL … OZ".
class MatchPredictionCard extends StatelessWidget {
  const MatchPredictionCard({
    required this.match,
    required this.prediction,
    this.quiz,
    this.volumeOz = 0,
    this.picks,
    this.onTap,
    super.key,
  });

  final SportMatch match;
  final UserPrediction? prediction;
  final PredictionQuiz? quiz;

  /// Total trading volume (Oz) for the fixture — real linked-market volume, or a
  /// seeded fallback. Shown as the "VOL … OZ" readout in the bottom strip.
  final int volumeOz;

  /// The player's realized Oz P&L on this fixture, present only when they hold a
  /// Pick position on it. Drives the coins-won/lost figure in the revealed
  /// state; null → the strip shows Total Vol instead.
  final ({int pnl, bool staked})? picks;

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
        // Extra top room so the teams clear the notch cut into the top edge;
        // the bottom 8 mirrors the gap above each team name.
        padding: const EdgeInsets.fromLTRB(16, 28, 16, _namePad),
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
            // The strip is a real Column child, not an overlay, so the card's
            // height is genuinely intrinsic — long team names wrap and push the
            // strip down instead of being clipped behind it. The Material's
            // antiAlias clip against _CyberCardBorder chamfers the strip's
            // bottom corners for free.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                body,
                _StatusStrip(
                  match: match,
                  prediction: prediction,
                  quiz: quiz,
                  predicted: _predicted,
                  volumeOz: volumeOz,
                  picks: picks,
                ),
              ],
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
            sport: match.sport,
            scoreLine: perTeamScores ? match.homeScore : null,
          ),
        ),
        _ScoreCentre(match: match),
        Expanded(
          child: _TeamColumn(
            team: match.away,
            alignEnd: true,
            dim: dimNames,
            sport: match.sport,
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
    this.sport,
    this.scoreLine,
  });

  final SportTeam team;
  final bool alignEnd;
  final bool dim;
  final Sport? sport;
  final String? scoreLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Mirror the badge chamfer toward the centre of the card.
        _TeamBadge(team: team, cutBottomRight: !alignEnd, sport: sport),
        const SizedBox(height: _namePad),
        // Long club names (cricket especially — "Los Angeles Knight Riders")
        // wrap onto a second line and grow the card rather than ellipsing.
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Cyber.body(
            14.5,
            color: dim ? _dimName : Colors.white,
            weight: FontWeight.w700,
          ),
        ),
        if (scoreLine != null) ...[
          const SizedBox(height: 3),
          // Cricket's chase line ("172/4 (19.1/20 ov, target 172)") is long —
          // wrap it rather than ellipse away the target.
          Text(
            scoreLine!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
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
  const _TeamBadge({required this.team, required this.cutBottomRight, this.sport});
  final SportTeam team;
  final bool cutBottomRight;
  final Sport? sport;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      team: team,
      width: 46,
      height: 46,
      cutBottomRight: cutBottomRight,
      sport: sport,
    );
  }
}

class _ScoreCentre extends StatelessWidget {
  const _ScoreCentre({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if ((match.sport == Sport.football || match.sport == Sport.basketball || match.sport == Sport.tennis) && match.hasScore) {
      final isTennis = match.sport == Sport.tennis;
      final sets = match.tennisScorecard?.sets;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${match.homeScore ?? '-'}  -  ${match.awayScore ?? '-'}',
              style: Cyber.display(
                21,
                color: Colors.white,
                letterSpacing: 0.5,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            // Tennis set scores row (e.g. 6-4  6-2  6-1)
            if (isTennis && sets != null && sets.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < sets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _SetScoreChip(homeScore: sets[i].homeScore, awayScore: sets[i].awayScore),
                  ],
                ],
              ),
            ],
          ],
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

/// A compact bordered chip showing a single set's score (e.g. "6-4").
class _SetScoreChip extends StatelessWidget {
  const _SetScoreChip({required this.homeScore, required this.awayScore});
  final int homeScore;
  final int awayScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Cyber.cyan.withValues(alpha: 0.35),
          width: 1,
        ),
        color: Cyber.cyan.withValues(alpha: 0.06),
      ),
      child: Text(
        '$homeScore-$awayScore',
        style: Cyber.body(
          10.5,
          color: Cyber.cyan,
          weight: FontWeight.w700,
        ).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Bottom status strip ───────────────────────────────────────────────────────
/// The fixture card reads like a live market: potential XP on the left, Total
/// Vol (Oz) on the right before kickoff; a focal, breathing gold "results are
/// out" cue once a reward is claimable; and the earned XP + the player's Oz P&L
/// once revealed. See the class doc on [MatchPredictionCard] for the full map.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.match,
    required this.prediction,
    required this.quiz,
    required this.predicted,
    required this.volumeOz,
    required this.picks,
  });

  final SportMatch match;
  final UserPrediction? prediction;
  final PredictionQuiz? quiz;
  final bool predicted;
  final int volumeOz;
  final ({int pnl, bool staked})? picks;

  @override
  Widget build(BuildContext context) {
    final volText = 'VOL ${formatOzCompact(volumeOz)} OZ';

    switch (match.status) {
      // Live — in-play beacon + the market's running volume.
      case MatchStatus.live:
        return _InfoStrip(
          left: const _LiveInPlay(),
          right: _VolText(volText),
        );

      // Upcoming — the two-figure market row the redesign leads with.
      case MatchStatus.upcoming:
        final potentialXp = quiz?.maxReward ?? match.rewardXp;
        return _InfoStrip(
          left: _PotentialXp(xp: potentialXp, predicted: predicted),
          right: _VolText(volText),
        );

      // Finished — reward-pending (focal gold) → revealed → no-engagement.
      case MatchStatus.finished:
        final isSettled = prediction?.status == PredictionStatus.settled;
        final rewardPending =
            !isSettled && (prediction != null || (quiz?.settleable ?? false));

        if (rewardPending) return const _RewardReadyStrip();

        if (isSettled) {
          final total = quiz?.questions.length ?? 0;
          final correct = prediction!.correctCount ?? 0;
          final isWon = correct > 0;
          return _InfoStrip(
            topBorder: (isWon ? Cyber.success : Cyber.muted).withValues(
              alpha: 0.25,
            ),
            left: isWon
                ? _XpWon(prediction!.rewardEarned)
                : _MutedLabel(total > 0 ? '$correct/$total CORRECT' : 'SETTLED'),
            // Coins P&L only when the player actually staked Oz on this match;
            // otherwise fall back to the market's final volume.
            right: picks != null
                ? _CoinsPnl(picks!.pnl)
                : _VolText(volText),
          );
        }

        // Finished, never engaged — a calm closed-market readout.
        return _InfoStrip(
          left: const _MutedLabel('FULL TIME'),
          right: _VolText(volText),
        );
    }
  }
}

/// Two-slot strip: a left cue and a right figure, on the shared dark fill.
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.left, required this.right, this.topBorder});

  final Widget left;
  final Widget right;
  final Color? topBorder;

  @override
  Widget build(BuildContext context) {
    return _Strip(
      fill: _stripDark,
      topBorder: topBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [left, const Spacer(), right]),
      ),
    );
  }
}

/// The right-slot Total Vol readout — muted, tabular, always-on (never glows).
class _VolText extends StatelessWidget {
  const _VolText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Cyber.label(
      9,
      color: Cyber.muted,
      letterSpacing: 0.8,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Left-slot potential-XP cue for upcoming fixtures; a ✓ marks a placed pick.
class _PotentialXp extends StatelessWidget {
  const _PotentialXp({required this.xp, required this.predicted});
  final int xp;
  final bool predicted;

  @override
  Widget build(BuildContext context) {
    final color = Cyber.cyan.withValues(alpha: 0.85);
    if (xp <= 0) {
      return _MutedLabel(
        predicted ? '✓ PREDICTED' : 'OPEN',
        color: predicted ? color : Cyber.muted,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (predicted) ...[
          Icon(Icons.check, size: 11, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          'POTENTIAL +$xp XP',
          style: Cyber.label(
            9,
            color: color,
            letterSpacing: 0.8,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Live in-play beacon — a legit glow per THE GLOW RULE (this fixture is live).
class _LiveInPlay extends StatelessWidget {
  const _LiveInPlay();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Cyber.danger,
          boxShadow: Cyber.glow(Cyber.danger, alpha: 0.8, blur: 6),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        'IN PLAY',
        style: Cyber.label(9, color: Cyber.danger, letterSpacing: 1),
      ),
    ],
  );
}

/// Revealed XP win.
class _XpWon extends StatelessWidget {
  const _XpWon(this.xp);
  final int xp;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.trending_up, color: Cyber.success, size: 13),
      const SizedBox(width: 6),
      Text(
        '+$xp XP',
        style: Cyber.body(
          12,
          color: Cyber.success,
          weight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

/// Revealed coins P&L — the player's realized Oz on this match (green up / red
/// down). Uses a real minus glyph so it lines up with the "+N OZ" wins.
class _CoinsPnl extends StatelessWidget {
  const _CoinsPnl(this.pnl);
  final int pnl;

  @override
  Widget build(BuildContext context) {
    final up = pnl >= 0;
    final color = up ? Cyber.success : Cyber.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.trending_up : Icons.trending_down,
          color: color,
          size: 12,
        ),
        const SizedBox(width: 5),
        Text(
          '${up ? '+' : '−'}${formatOzCompact(pnl.abs())} OZ',
          style: Cyber.body(
            12,
            color: color,
            weight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A calm muted label (FULL TIME / SETTLED / n/m CORRECT / OPEN).
class _MutedLabel extends StatelessWidget {
  const _MutedLabel(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Cyber.label(
      9,
      color: color ?? Cyber.muted,
      letterSpacing: 0.8,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// The one focal element on a finished-but-unclaimed card: a breathing gold
/// "results are out" cue. The glow is gated to this state only — tapping the
/// card runs the existing settlement reveal cinematic.
class _RewardReadyStrip extends StatelessWidget {
  const _RewardReadyStrip();

  @override
  Widget build(BuildContext context) {
    return CyberPulse(
      period: const Duration(milliseconds: 1100),
      builder: (context, t) => _Strip(
        fill: _stripDark,
        topBorder: Cyber.gold.withValues(alpha: 0.28 + 0.30 * t),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.redeem, color: Cyber.gold, size: 14),
            const SizedBox(width: 7),
            Text(
              'RESULTS ARE OUT — TAP TO REVEAL',
              style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1)
                  .copyWith(
                    shadows: [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.25 + 0.35 * t),
                        blurRadius: 8 + 8 * t,
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
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
const _timeGold = Color(0xffc8a45a);
const _dimName = Color(0xffaeb7c5);
const _scoreSub = Color(0xff9fb0c2);
const _resultCol = Color(0xffbac5d3);

// Top-centre notch geometry (shared by the card shape + the tag overlay).
const _notchFloorW = 96.0;
const _notchDepth = 22.0;
const _notchSlope = 12.0;

// Breathing room around the team name — the same 8 above (badge → name) and
// below (name → bottom strip), so the block sits evenly however it wraps.
const _namePad = 8.0;

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
