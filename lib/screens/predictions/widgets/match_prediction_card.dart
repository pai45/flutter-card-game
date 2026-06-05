import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';

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
///       - finished + reward → "△ +N XP",
///       - live → no strip.
class MatchPredictionCard extends StatelessWidget {
  const MatchPredictionCard({
    required this.match,
    required this.prediction,
    this.onTap,
    super.key,
  });

  final SportMatch match;
  final UserPrediction? prediction;
  final VoidCallback? onTap;

  bool get _predicted => prediction != null;
  bool get _finished => match.status == MatchStatus.finished;

  @override
  Widget build(BuildContext context) {
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
                style: Cyber.body(11.5, color: _resultCol, weight: FontWeight.w600),
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
          // Hard, un-blurred drop shadow drawn behind the card.
          const Positioned.fill(
            child: CustomPaint(painter: _HardShadowPainter()),
          ),
          Material(
            color: _cardBase,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: const _CyberCardBorder(
              cut: 12,
              notchWidth: _notchFloorW,
              notchDepth: _notchDepth,
              notchSlope: _notchSlope,
              side: BorderSide(color: _borderCol),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                body,
                _StatusStrip(
                  match: match,
                  predicted: _predicted,
                  submittedAt: prediction?.submittedAt,
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
        style: Cyber.body(13, color: _timeGold, weight: FontWeight.w700).copyWith(
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
            style: Cyber.body(12.5, color: Cyber.danger, weight: FontWeight.w800)
                .copyWith(letterSpacing: 0.8),
          ),
        ],
      ),
      MatchStatus.finished => Text(
        'Finished',
        style: Cyber.body(11, color: Cyber.muted, weight: FontWeight.w600)
            .copyWith(letterSpacing: 0.4),
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
    // Cricket shows each side's innings under the team name; football keeps the
    // score in the centre instead.
    final cricketScores = match.sport == Sport.cricket && match.hasScore;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TeamColumn(
            team: match.home,
            alignEnd: false,
            dim: dimNames,
            scoreLine: cricketScores ? match.homeScore : null,
          ),
        ),
        _ScoreCentre(match: match),
        Expanded(
          child: _TeamColumn(
            team: match.away,
            alignEnd: true,
            dim: dimNames,
            scoreLine: cricketScores ? match.awayScore : null,
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
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            style: Cyber.body(10.5, color: _scoreSub, weight: FontWeight.w600)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
    // Very light crests (cream/white/yellow) read better with dark text; tinted
    // crests keep white text. Threshold tuned so orange/sky stay white-on-colour.
    final light = team.color.computeLuminance() > 0.55;
    final textColor = light ? const Color(0xff15202e) : Colors.white;
    final accentEdge = light
        ? Color.lerp(team.color, Colors.black, 0.28)!
        : Color.lerp(team.color, Colors.white, 0.5)!;

    return ClipPath(
      clipper: _BadgeClipper(cutBottomRight: cutBottomRight),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [team.color, Color.lerp(team.color, Colors.black, 0.34)!],
          ),
          border: Border(bottom: BorderSide(color: accentEdge, width: 3)),
        ),
        child: Text(
          team.shortName,
          style: TextStyle(
            color: textColor,
            fontFamily: Cyber.displayFont,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _ScoreCentre extends StatelessWidget {
  const _ScoreCentre({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.sport == Sport.football && match.hasScore) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '${match.homeScore ?? '-'}  -  ${match.awayScore ?? '-'}',
          style: Cyber.display(21, color: Colors.white, letterSpacing: 0.5)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
    }
    // Upcoming, or cricket (innings live under each name) → centre dash.
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
    required this.predicted,
    required this.submittedAt,
  });

  final SportMatch match;
  final bool predicted;
  final DateTime? submittedAt;

  @override
  Widget build(BuildContext context) {
    // Finished with a reward → "△ +N XP".
    if (match.status == MatchStatus.finished && match.rewardXp > 0) {
      return _Strip(
        fill: _stripDark,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.change_history, color: Cyber.cyan, size: 15),
            const SizedBox(width: 6),
            Text(
              '+${match.rewardXp} XP',
              style: Cyber.body(12.5, color: Cyber.cyan, weight: FontWeight.w700)
                  .copyWith(
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      );
    }

    // Upcoming + predicted → calm note.
    if (match.status == MatchStatus.upcoming && predicted) {
      return _Strip(
        fill: _stripDark,
        child: Text(
          'Predicted ${_timeAgo(submittedAt)}',
          style: Cyber.body(12.5, color: _predictedText, weight: FontWeight.w500),
        ),
      );
    }

    // Upcoming + open → prize CTA (the one focal strip; brighter + glowing text).
    if (match.status == MatchStatus.upcoming && match.prizeLabel != null) {
      return _Strip(
        fill: _stripBlue,
        topBorder: Cyber.cyan.withValues(alpha: 0.28),
        child: Text(
          'Make prediction and ${match.prizeLabel}',
          style: Cyber.body(12.5, color: Cyber.cyan, weight: FontWeight.w700)
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

    // Live → no strip.
    return const SizedBox.shrink();
  }
}

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

// ── Shape: square top, chamfered bottom corners — used for the shadow + border ─
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

  Path _build(Rect r) =>
      _cardPath(r, cut, notchWidth, notchDepth, notchSlope);

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
  const _HardShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cardPath(
      Offset.zero & size,
      12,
      _notchFloorW,
      _notchDepth,
      _notchSlope,
    ).shift(const Offset(0, 6));
    canvas.drawPath(path, Paint()..color = _shadowCol);
  }

  @override
  bool shouldRepaint(covariant _HardShadowPainter oldDelegate) => false;
}

/// Cuts a single bottom corner of a team badge (mirrored per side).
class _BadgeClipper extends CustomClipper<Path> {
  const _BadgeClipper({required this.cutBottomRight});
  final bool cutBottomRight;

  @override
  Path getClip(Size s) {
    const c = 11.0;
    if (cutBottomRight) {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, s.height - c)
        ..lineTo(s.width - c, s.height)
        ..lineTo(0, s.height)
        ..close();
    }
    return Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(c, s.height)
      ..lineTo(0, s.height - c)
      ..close();
  }

  @override
  bool shouldReclip(covariant _BadgeClipper old) =>
      old.cutBottomRight != cutBottomRight;
}

// ── Palette (card-local, tuned to the reference) ──────────────────────────────
const _cardBase = Color(0xff141c2b);
const _cardTop = Color(0xff1b2336);
const _cardBottom = Color(0xff121a28);
const _borderCol = Color(0xff2a3550);
const _shadowCol = Color(0xff04060b); // hard drop-shadow fill
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

// ── Helpers ───────────────────────────────────────────────────────────────────
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
