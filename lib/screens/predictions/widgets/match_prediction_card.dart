import 'package:card_game/design_system/typography.dart';
import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../data/favorite_team_matcher.dart';
import '../../../data/team_palettes.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';
import '../../../widgets/cyber/match_discovery.dart';
import 'pick_status_style.dart';

/// Routes revamped sports to the shared editorial library and preserves the
/// existing Tennis set-score and prediction/reveal presentation.
class MatchPredictionCard extends StatelessWidget {
  const MatchPredictionCard({
    required this.match,
    required this.prediction,
    this.quiz,
    this.volumeOz = 0,
    this.picks,
    this.favorite,
    this.onTap,
    super.key,
  });

  final SportMatch match;
  final UserPrediction? prediction;
  final PredictionQuiz? quiz;

  /// The side of this fixture that is one of the player's followed clubs, or
  /// null when neither side is. Resolve it with
  /// `PredictionState.favoriteSideFor(match)`.
  final FavoriteSide? favorite;

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
  bool get _showsResultSummary => match.resultLine != null;

  @override
  Widget build(BuildContext context) {
    if (match.sport != Sport.tennis || match.status == MatchStatus.upcoming) {
      if (_finished &&
          prediction != null &&
          prediction!.status != PredictionStatus.settled &&
          quiz?.settleable == true) {
        return EditorialRevealCard(match: match, onTap: onTap);
      }
      return EditorialMatchCard(
        match: match,
        showCompetition: false,
        onTap: onTap,
        followed: this.favorite != null,
      );
    }
    final favorite = this.favorite;
    // The club's WCAG-checked identity colour, from the same palette table the
    // badge itself uses — not the raw catalogue hex, which can be unreadable
    // on the dark card.
    final clubAccent = favorite == null
        ? null
        : paletteForTeam(
            favorite.team,
            sport: match.sport,
            competition: match.leagueId,
          ).secondaryTextColor;
    final stateColor = _stateBorderColor(match, prediction);
    // Live / reward-pending lifecycle colours keep priority; the club tint only
    // takes over the two neutral resting edges.
    final borderColor =
        clubAccent != null &&
            (stateColor == _borderPredicted || stateColor == _borderCol)
        ? clubAccent
        : stateColor;
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
            _TeamsRow(
              match: match,
              dimNames: _finished,
              favoriteIsHome: favorite?.isHome,
              clubAccent: clubAccent,
            ),
            if (_showsResultSummary) ...[
              const SizedBox(height: 12),
              Text(
                match.resultLine!,
                textAlign: TextAlign.center,
                style: Cyber.bodyFor(
                  context,
                  StatOzTypography.p11_5,
                  color: _resultCol,
                  weight: StatOzTypography.semibold,
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
        style:
            Cyber.bodyFor(
              context,
              StatOzTypography.p13,
              color: _timeGold,
              weight: StatOzTypography.bold,
            ).copyWith(
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
            style: Cyber.bodyFor(
              context,
              StatOzTypography.p12_5,
              color: Cyber.danger,
              weight: StatOzTypography.bold,
            ).copyWith(letterSpacing: 0.8),
          ),
        ],
      ),
      MatchStatus.finished => Text(
        'Finished',
        style: Cyber.bodyFor(
          context,
          StatOzTypography.p11,
          color: Cyber.muted,
          weight: StatOzTypography.semibold,
        ).copyWith(letterSpacing: 0.4),
      ),
    };
  }
}

// ── Teams + score row ─────────────────────────────────────────────────────────
class _TeamsRow extends StatelessWidget {
  const _TeamsRow({
    required this.match,
    required this.dimNames,
    this.favoriteIsHome,
    this.clubAccent,
  });
  final SportMatch match;
  final bool dimNames;

  /// Which side is the player's club (null when neither is).
  final bool? favoriteIsHome;
  final Color? clubAccent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TeamColumn(
            team: match.home,
            alignEnd: false,
            nameColor: dimNames ? _dimName : Colors.white,
            sport: match.sport,
            competition: match.leagueId,
            clubAccent: favoriteIsHome == true ? clubAccent : null,
          ),
        ),
        _ScoreCentre(match: match),
        Expanded(
          child: _TeamColumn(
            team: match.away,
            alignEnd: true,
            nameColor: dimNames ? _dimName : Colors.white,
            sport: match.sport,
            competition: match.leagueId,
            clubAccent: favoriteIsHome == false ? clubAccent : null,
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
    required this.nameColor,
    this.sport,
    this.competition,
    this.clubAccent,
  });

  final SportTeam team;
  final bool alignEnd;
  final Color nameColor;
  final Sport? sport;
  final String? competition;

  /// Set only on the player's own club, which writes its name in this identity
  /// colour so the side that is "yours" is readable at a glance.
  final Color? clubAccent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        TeamLogo(
          team: team,
          width: 46,
          height: 46,
          cutBottomRight: !alignEnd,
          sport: sport,
          competition: competition,
        ),
        const SizedBox(height: _namePad),
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Cyber.bodyFor(
            context,
            StatOzTypography.p14_5,
            color: clubAccent ?? nameColor,
            weight: clubAccent != null
                ? StatOzTypography.extrabold
                : StatOzTypography.bold,
          ),
        ),
      ],
    );
  }
}

class _ScoreCentre extends StatelessWidget {
  const _ScoreCentre({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.hasScore) {
      final sets = match.tennisScorecard?.sets;
      final scoreStyle = Cyber.display(
        StatOzTypography.p21,
        color: Colors.white,
        letterSpacing: 0.5,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: match.homeScore ?? '-', style: scoreStyle),
                  TextSpan(
                    text: '  -  ',
                    style: scoreStyle.copyWith(color: Cyber.muted),
                  ),
                  TextSpan(text: match.awayScore ?? '-', style: scoreStyle),
                ],
              ),
            ),
            // Tennis set scores row (e.g. 6-4  6-2  6-1)
            if (sets != null && sets.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < sets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _SetScoreChip(
                      homeScore: sets[i].homeScore,
                      awayScore: sets[i].awayScore,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    }
    // Upcoming Tennis fixtures have no score yet.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '-',
        style: TextStyle(
          color: Cyber.muted,
          fontFamily: Cyber.displayFont,
          fontSize: StatOzTypography.p18,
          fontWeight: StatOzTypography.black,
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
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.35), width: 1),
        color: Cyber.cyan.withValues(alpha: 0.06),
      ),
      child: Text(
        '$homeScore-$awayScore',
        style:
            Cyber.bodyFor(
              context,
              StatOzTypography.p10_5,
              color: Cyber.cyan,
              weight: StatOzTypography.bold,
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
        return _InfoStrip(left: const _LiveInPlay(), right: _VolText(volText));

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
        // Reward-pending requires the user to have actually engaged (predicted
        // or answered the quiz) — a settleable quiz alone isn't enough, since
        // it's looked up by matchId regardless of whether the user played it.
        final rewardPending = !isSettled && prediction != null;

        if (rewardPending) {
          return const _RewardReadyStrip();
        }

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
                : _MutedLabel(
                    total > 0 ? '$correct/$total CORRECT' : 'SETTLED',
                  ),
            // Coins P&L only when the player actually staked Oz on this match;
            // otherwise fall back to the market's final volume.
            right: picks != null ? _CoinsPnl(picks!.pnl) : _VolText(volText),
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
      StatOzTypography.p9,
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
            StatOzTypography.p9,
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
        style: Cyber.label(
          StatOzTypography.p9,
          color: Cyber.danger,
          letterSpacing: 1,
        ),
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
        style: Cyber.bodyFor(
          context,
          StatOzTypography.p12,
          color: Cyber.success,
          weight: StatOzTypography.bold,
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
          style: Cyber.bodyFor(
            context,
            StatOzTypography.p12,
            color: color,
            weight: StatOzTypography.bold,
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
      StatOzTypography.p9,
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
              style:
                  Cyber.label(
                    StatOzTypography.p9,
                    color: Cyber.gold,
                    letterSpacing: 1,
                  ).copyWith(
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
      if (prediction == null) {
        return _borderCol;
      } // neutral edge
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
