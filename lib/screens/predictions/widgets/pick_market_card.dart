import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/picks.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/fixture_card.dart';
import 'pick_status_style.dart';

/// Pick market card built on the shared [FixtureCardFrame] so it reads like the
/// match prediction fixture card: navy gradient body, square-top status notch,
/// chamfered bottom + hard shadow, and a bottom strip. The outcome CTAs are
/// filled team-logo style badges (color fill + abbreviated code + odds).
class PickMarketCard extends StatefulWidget {
  const PickMarketCard({
    required this.market,
    required this.positions,
    required this.onOpen,
    required this.onBuy,
    super.key,
  });

  final PickMarket market;
  final List<PickPosition> positions;
  final VoidCallback onOpen;
  final void Function(PickOutcome outcome) onBuy;

  @override
  State<PickMarketCard> createState() => _PickMarketCardState();
}

class _PickMarketCardState extends State<PickMarketCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool get _isLive => widget.market.status == PickMarketStatus.live;

  @override
  void initState() {
    super.initState();
    if (_isLive) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PickMarketCard old) {
    super.didUpdateWidget(old);
    if (_isLive && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_isLive && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = widget.market;
    final visibleOutcomes = market.outcomes.take(3).toList();
    final showMatchTeams =
        market.type == PickMarketType.match &&
        market.homeLabel != null &&
        market.awayLabel != null &&
        visibleOutcomes.length >= 2;
    return FixtureCardFrame(
      onTap: () {
        playSound(SoundEffect.uiTap);
        widget.onOpen();
      },
      tag: _StatusTag(market: market, pulse: _pulse),
      bottomStrip: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OutcomeShareBar(outcomes: market.outcomes),
          _Strip(market: market, positions: widget.positions),
        ],
      ),
      bodyPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeagueMark(
                label: market.leagueLabel,
                color: _leaguePrimaryColor(market.leagueId),
              ),
              const Spacer(),
              _PickTypePill(type: market.type),
            ],
          ),
          const SizedBox(height: 8),
          if (showMatchTeams)
            _MatchTeamsLine(
              leftLabel: visibleOutcomes.first.label,
              rightLabel: visibleOutcomes.last.label,
            )
          else ...[
            Text(
              market.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(18, weight: FontWeight.w700, height: 1.12),
            ),
            if (_contextLine(market) != null) ...[
              const SizedBox(height: 4),
              Text(
                _contextLine(market)!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(
                  11,
                  color: const Color(0xff9fb0c2),
                  weight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          if (market.type == PickMarketType.future)
            _FutureOutcomeRail(
              market: market,
              positions: widget.positions,
              onBuy: market.canBuy ? _buy : null,
            )
          else
            Row(
              children: [
                for (var i = 0; i < visibleOutcomes.length; i++) ...[
                  Expanded(
                    child: _OutcomeBadge(
                      market: market,
                      outcome: visibleOutcomes[i],
                      held: widget.positions.any(
                        (p) => p.outcomeId == visibleOutcomes[i].id,
                      ),
                      onTap: market.canBuy
                          ? () => _buy(visibleOutcomes[i])
                          : null,
                    ),
                  ),
                  if (i != visibleOutcomes.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _buy(PickOutcome outcome) {
    playSound(SoundEffect.uiTap);
    widget.onBuy(outcome);
  }

  /// One muted line of extra context: a compact scoreline when teams are
  /// playing, otherwise the freeform context title/subtitle.
  String? _contextLine(PickMarket market) {
    final hasTeams = market.homeLabel != null && market.awayLabel != null;
    if (hasTeams) {
      if (market.homeScore == null && market.awayScore == null) return null;
      return '${market.homeLabel} ${market.homeScore ?? '-'}'
          '  —  '
          '${market.awayScore ?? '-'} ${market.awayLabel}';
    }
    final parts = [
      market.contextTitle,
      market.contextSubtitle,
    ].whereType<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _FutureOutcomeRail extends StatelessWidget {
  const _FutureOutcomeRail({
    required this.market,
    required this.positions,
    required this.onBuy,
  });

  static const _gap = 8.0;
  static const _visibleBadges = 3.5;

  final PickMarket market;
  final List<PickPosition> positions;
  final void Function(PickOutcome outcome)? onBuy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final minBadgeWidth = availableWidth < 56.0 ? availableWidth : 56.0;
        final badgeWidth = ((availableWidth - _gap * 3) / _visibleBadges)
            .clamp(minBadgeWidth, availableWidth)
            .toDouble();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < market.outcomes.length; i++) ...[
                SizedBox(
                  width: badgeWidth,
                  child: _OutcomeBadge(
                    market: market,
                    outcome: market.outcomes[i],
                    held: positions.any(
                      (p) => p.outcomeId == market.outcomes[i].id,
                    ),
                    onTap: onBuy == null
                        ? null
                        : () => onBuy!(market.outcomes[i]),
                  ),
                ),
                if (i != market.outcomes.length - 1)
                  const SizedBox(width: _gap),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MatchTeamsLine extends StatelessWidget {
  const _MatchTeamsLine({required this.leftLabel, required this.rightLabel});

  final String leftLabel;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TeamNameText(
            label: leftLabel,
            alignment: Alignment.centerLeft,
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TeamNameText(
            label: rightLabel,
            alignment: Alignment.centerRight,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _TeamNameText extends StatelessWidget {
  const _TeamNameText({
    required this.label,
    required this.alignment,
    required this.textAlign,
  });

  final String label;
  final Alignment alignment;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: Cyber.body(18, weight: FontWeight.w700, height: 1.12),
      ),
    );
  }
}

/// Status content that sits inside the top notch, reading against the page
/// background — kickoff/close time (gold), a glowing "• LIVE n'" (red), or the
/// settled/closed status.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.market, required this.pulse});

  final PickMarket market;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    if (market.status == PickMarketStatus.live) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Cyber.danger,
                boxShadow: Cyber.glow(
                  Cyber.danger,
                  alpha: 0.45 + 0.4 * pulse.value,
                  blur: 7,
                  spread: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            market.liveLabel == null || market.liveLabel == 'LIVE'
                ? 'LIVE'
                : 'LIVE ${market.liveLabel}',
            style:
                Cyber.body(
                  12.5,
                  color: Cyber.danger,
                  weight: FontWeight.w800,
                ).copyWith(
                  letterSpacing: 0.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      );
    }
    if (market.canBuy) {
      return Text(
        'CLOSES ${_closesLabel(market.closesAt)}',
        style: Cyber.body(12, color: kFixtureTimeGold, weight: FontWeight.w700)
            .copyWith(
              letterSpacing: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      );
    }
    return Text(
      pickMarketStatusLabel(market.status),
      style: Cyber.body(
        11,
        color: pickMarketStatusColor(market.status),
        weight: FontWeight.w700,
      ).copyWith(letterSpacing: 0.6),
    );
  }
}

class _LeagueMark extends StatelessWidget {
  const _LeagueMark({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.48
        ? const Color(0xff07111e)
        : Colors.white;
    return SizedBox(
      height: 28,
      child: CustomPaint(
        painter: _LeagueMarkPainter(color: color),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 5, 11, 6),
          child: Text(
            _leagueCode(label),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: Cyber.display(12, color: ink, letterSpacing: 0.6).copyWith(
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickTypePill extends StatelessWidget {
  const _PickTypePill({required this.type});

  final PickMarketType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0xff0f1826),
        border: Border.all(color: Cyber.border.withValues(alpha: 0.78)),
      ),
      child: Text(
        pickMarketTypeLabel(type),
        style: Cyber.label(
          8.5,
          color: Cyber.muted.withValues(alpha: 0.9),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _LeagueMarkPainter extends CustomPainter {
  const _LeagueMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 6.0;
    final rect = Offset.zero & size;
    final path = Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
    canvas
      ..drawPath(
        path.shift(const Offset(0, 3)),
        Paint()..color = Color.lerp(color, Colors.black, 0.58)!,
      )
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.2),
      );
  }

  @override
  bool shouldRepaint(covariant _LeagueMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A filled, team-logo-style outcome CTA: octagon-cut color fill with a hard
/// darker base (the home-page badge look), an abbreviated code, and the odds.
class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({
    required this.market,
    required this.outcome,
    required this.held,
    required this.onTap,
  });

  final PickMarket market;
  final PickOutcome outcome;
  final bool held;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? outcome.color : Cyber.muted;
    final ink = color.computeLuminance() > 0.48 ? Colors.black : Colors.white;
    final delta = market.latestDeltaFor(outcome.id);
    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        height: 62,
        child: CustomPaint(
          painter: _BadgePainter(color: color, held: held),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    pickOutcomeCode(outcome.label),
                    style: Cyber.label(15, color: ink, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DeltaArrow(delta: delta, ink: ink),
                    Text(
                      '${outcome.probabilityPercent}%',
                      style: Cyber.display(15, color: ink, letterSpacing: 0)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the octagon-cut team-badge silhouette: a hard darker base shifted
/// down (the "logo" drop) under the solid color face, plus a subtle edge.
class _BadgePainter extends CustomPainter {
  const _BadgePainter({required this.color, required this.held});

  final Color color;
  final bool held;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height - 5;
    final cut = size.shortestSide * 0.16;
    final rect = Rect.fromLTWH(0, 0, size.width, bodyHeight);
    final body = _octagon(rect, cut);

    canvas.drawPath(
      body.shift(const Offset(0, 5)),
      Paint()..color = Color.lerp(color, Colors.black, 0.58)!,
    );
    canvas.drawPath(body, Paint()..color = color);
    // Bright bottom accent edge for a touch of dimensionality.
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  Path _octagon(Rect r, double cut) => Path()
    ..moveTo(r.left + cut, r.top)
    ..lineTo(r.right - cut, r.top)
    ..lineTo(r.right, r.top + cut)
    ..lineTo(r.right, r.bottom - cut)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..lineTo(r.left, r.top + cut)
    ..close();

  @override
  bool shouldRepaint(covariant _BadgePainter old) =>
      old.color != color || old.held != held;
}

/// Probability movement since the previous price point; only meaningful moves
/// (≥2pp) earn an arrow. Tinted to the badge ink so it reads on the fill.
class _DeltaArrow extends StatelessWidget {
  const _DeltaArrow({required this.delta, required this.ink});

  final int? delta;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    if (d == null || d.abs() < 2) return const SizedBox.shrink();
    final up = d > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        '${up ? '▲' : '▼'}${d.abs()}',
        style: Cyber.label(
          8,
          color: ink.withValues(alpha: 0.9),
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Bottom strip mirroring the fixture card: a focal gold CTA when a result is
/// claimable, a calm "you hold" line when positioned, otherwise volume + close.
class _Strip extends StatelessWidget {
  const _Strip({required this.market, required this.positions});

  final PickMarket market;
  final List<PickPosition> positions;

  @override
  Widget build(BuildContext context) {
    if (positions.any((p) => p.canSettle)) {
      return FixtureCardStrip(
        focal: true,
        topBorder: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.redeem, color: Cyber.gold, size: 14),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'RESULT READY — TAP TO CLAIM',
                    style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (positions.isNotEmpty) {
      // One backed side → show its code + stake; several → a compact count of
      // sides with the combined stake so 4-5 picks on one market still read.
      final totalStake = positions.fold<int>(0, (sum, p) => sum + p.stakeOz);
      final heldLabel = positions.length == 1
          ? '${pickOutcomeCode(positions.first.outcomeLabel)} · '
                '$totalStake OZ'
          : '${positions.length} PICKS · $totalStake OZ';
      return FixtureCardStrip(
        topBorder: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_rounded, color: Cyber.cyan, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    heldLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      8.5,
                      color: Cyber.cyan,
                      letterSpacing: 0.8,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  'VOL ${formatOzCompact(market.volumeOz)} OZ',
                  style: Cyber.label(
                    8,
                    color: Cyber.muted.withValues(alpha: 0.7),
                    letterSpacing: 0.8,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final more =
        market.type != PickMarketType.future && market.outcomes.length > 3
        ? '${market.outcomes.length - 3} MORE · '
        : '';
    return FixtureCardStrip(
      topBorder: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              Text(
                '${more}VOL ${formatOzCompact(market.volumeOz)} OZ',
                style: Cyber.label(
                  8,
                  color: Cyber.muted.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeShareBar extends StatelessWidget {
  const _OutcomeShareBar({required this.outcomes});

  final List<PickOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    final total = outcomes.fold<int>(
      0,
      (sum, outcome) => sum + outcome.probabilityPercent,
    );
    if (total <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: 3,
      width: double.infinity,
      child: CustomPaint(
        painter: _OutcomeShareBarPainter(outcomes: outcomes, total: total),
      ),
    );
  }
}

class _OutcomeShareBarPainter extends CustomPainter {
  const _OutcomeShareBarPainter({required this.outcomes, required this.total});

  final List<PickOutcome> outcomes;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    if (outcomes.isEmpty || total <= 0 || size.width <= 0) return;

    const gap = 7.0;
    final usableWidth = (size.width - gap * (outcomes.length - 1)).clamp(
      0.0,
      size.width,
    );
    var left = 0.0;
    for (var i = 0; i < outcomes.length; i++) {
      final outcome = outcomes[i];
      final isLast = i == outcomes.length - 1;
      final width = isLast
          ? size.width - left
          : usableWidth * outcome.probabilityPercent / total;
      canvas.drawRect(
        Rect.fromLTWH(left, 0, width.clamp(1.0, size.width), size.height),
        Paint()..color = outcome.color,
      );
      left += width + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _OutcomeShareBarPainter oldDelegate) =>
      oldDelegate.outcomes != outcomes || oldDelegate.total != total;
}

String _closesLabel(DateTime closesAt) {
  final diff = closesAt.difference(DateTime.now());
  if (diff.isNegative) return 'SOON';
  if (diff.inMinutes < 60) return '${diff.inMinutes}M';
  if (diff.inHours < 24) return '${diff.inHours}H';
  return '${diff.inDays}D';
}

String _leagueCode(String label) {
  final compact = label.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compact.isEmpty) return 'LGE';
  if (compact.length <= 3) return compact.padRight(3, ' ');
  return compact.substring(0, 3);
}

Color _leaguePrimaryColor(String leagueId) {
  return switch (leagueId.toLowerCase()) {
    'ipl' => const Color(0xff5cdfff),
    'epl' => const Color(0xffa855f7),
    'fifa' => const Color(0xff2856ff),
    _ => Cyber.cyan,
  };
}
