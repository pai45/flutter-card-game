import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/picks.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../shop/shop_screen.dart' show CoinIcon;

class PickMarketCard extends StatelessWidget {
  const PickMarketCard({
    required this.market,
    required this.position,
    required this.onOpen,
    required this.onBuy,
    super.key,
  });

  final PickMarket market;
  final PickPosition? position;
  final VoidCallback onOpen;
  final void Function(PickOutcome outcome) onBuy;

  @override
  Widget build(BuildContext context) {
    final visibleOutcomes = market.outcomes.take(3).toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onOpen();
      },
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 16, smallCut: 2),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xff111b30),
            border: Border.all(color: const Color(0xff243654)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            market.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.body(
                              15,
                              weight: FontWeight.w900,
                              height: 1.12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MarketTypePill(type: market.type),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MarketContext(market: market),
                    const SizedBox(height: 12),
                    _MarketInfoStrip(market: market),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < visibleOutcomes.length; i++) ...[
                    Expanded(
                      child: _OutcomeButton(
                        outcome: visibleOutcomes[i],
                        enabled: market.canBuy,
                        first: i == 0,
                        last: i == visibleOutcomes.length - 1,
                        onTap: () {
                          playSound(SoundEffect.uiTap);
                          onBuy(visibleOutcomes[i]);
                        },
                      ),
                    ),
                    if (i != visibleOutcomes.length - 1)
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.black.withValues(alpha: 0.26),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketContext extends StatelessWidget {
  const _MarketContext({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    final hasTeams = market.homeLabel != null && market.awayLabel != null;
    if (hasTeams) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.28),
          border: Border.all(color: Cyber.border.withValues(alpha: 0.75)),
        ),
        child: Column(
          children: [
            _ScoreLine(label: market.homeLabel!, score: market.homeScore),
            const SizedBox(height: 7),
            _ScoreLine(label: market.awayLabel!, score: market.awayScore),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.28),
        border: Border.all(color: Cyber.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Icon(
            _typeIcon(market.type),
            color: _typeColor(market.type),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              market.contextTitle ?? market.leagueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(
                12.5,
                color: Colors.white,
                weight: FontWeight.w800,
              ),
            ),
          ),
          if (market.contextSubtitle != null)
            Flexible(
              child: Text(
                market.contextSubtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Cyber.body(
                  10.5,
                  color: Cyber.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.label, required this.score});

  final String label;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Cyber.cyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            score == null ? label : '$label  $score',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              12,
              weight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketInfoStrip extends StatelessWidget {
  const _MarketInfoStrip({required this.market});

  final PickMarket market;

  @override
  Widget build(BuildContext context) {
    final more = market.outcomes.length > 3
        ? ' · ${market.outcomes.length - 3} more'
        : '';
    return Row(
      children: [
        _InfoPill(label: market.leagueLabel, color: _typeColor(market.type)),
        const SizedBox(width: 7),
        _InfoPill(
          label: _statusLabel(market.status),
          color: _statusColor(market.status),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Vol ${_formatCompact(market.volumeOz)} Oz$more',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Cyber.body(10, color: Cyber.muted, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: Cyber.label(8, color: color, letterSpacing: 0.8),
      ),
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  const _OutcomeButton({
    required this.outcome,
    required this.enabled,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final PickOutcome outcome;
  final bool enabled;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = outcome.color;
    final light = color.computeLuminance() > 0.55;
    final ink = light ? const Color(0xff101827) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.46,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            border: Border(
              top: BorderSide(
                color: Colors.black.withValues(alpha: 0.3),
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: first ? 0 : null,
                right: last ? 0 : null,
                bottom: 0,
                child: Container(
                  width: 52,
                  height: 9,
                  color: Colors.black.withValues(alpha: 0.16),
                ),
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        outcome.label.toUpperCase(),
                        style: Cyber.label(12, color: ink, letterSpacing: 0.6),
                      ),
                      const SizedBox(width: 9),
                      CoinIcon(size: light ? 19 : 18),
                      const SizedBox(width: 5),
                      Text(
                        '${outcome.probabilityPercent}%',
                        style: Cyber.label(
                          19,
                          color: ink,
                          letterSpacing: 0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketTypePill extends StatelessWidget {
  const _MarketTypePill({required this.type});

  final PickMarketType type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        _typeLabel(type),
        style: Cyber.label(8, color: color, letterSpacing: 0.8),
      ),
    );
  }
}

String _formatCompact(int value) {
  if (value >= 1000) {
    final k = value / 1000;
    return k == k.roundToDouble()
        ? '${k.toInt()}K'
        : '${k.toStringAsFixed(1)}K';
  }
  return '$value';
}

String _typeLabel(PickMarketType type) => switch (type) {
  PickMarketType.match => 'MATCH',
  PickMarketType.event => 'EVENT',
  PickMarketType.future => 'FUTURE',
};

IconData _typeIcon(PickMarketType type) => switch (type) {
  PickMarketType.match => Icons.sports_soccer,
  PickMarketType.event => Icons.bolt,
  PickMarketType.future => Icons.query_stats,
};

Color _typeColor(PickMarketType type) => switch (type) {
  PickMarketType.match => Cyber.cyan,
  PickMarketType.event => Cyber.gold,
  PickMarketType.future => Cyber.violet,
};

String _statusLabel(PickMarketStatus status) => switch (status) {
  PickMarketStatus.upcoming => 'OPEN',
  PickMarketStatus.live => 'LIVE',
  PickMarketStatus.closed => 'CLOSED',
  PickMarketStatus.unresolved => 'UNRESOLVED',
  PickMarketStatus.settled => 'SETTLED',
  PickMarketStatus.voided => 'VOID',
};

Color _statusColor(PickMarketStatus status) => switch (status) {
  PickMarketStatus.upcoming => Cyber.gold,
  PickMarketStatus.live => Cyber.red,
  PickMarketStatus.closed => Cyber.muted,
  PickMarketStatus.unresolved => Cyber.amber,
  PickMarketStatus.settled => Cyber.success,
  PickMarketStatus.voided => Cyber.muted,
};
