import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../screens/predictions/widgets/history_hud.dart';
import '../screens/shop/shop_screen.dart' show CoinIcon;
import 'cyber/fixture_card.dart';
import 'cyber/cyber_widgets.dart';

enum RewardSettlementOutcome { won, lost, voided, mixed }

class RewardSettlementDemoData {
  const RewardSettlementDemoData({
    required this.xpWon,
    required this.coinsWon,
    required this.predicts,
    required this.picks,
  });

  factory RewardSettlementDemoData.demo() {
    return const RewardSettlementDemoData(
      xpWon: 185,
      coinsWon: 340,
      predicts: [
        RewardPredictOutcome(
          fixture: 'Man City vs Arsenal',
          summary: '3 / 4 correct',
          xpWon: 120,
          outcome: RewardSettlementOutcome.won,
          details: ['Winner +', 'Over 2.5 +', 'BTTS +', 'First scorer -'],
        ),
        RewardPredictOutcome(
          fixture: 'Barcelona vs Real Madrid',
          summary: '2 / 4 correct',
          xpWon: 65,
          outcome: RewardSettlementOutcome.mixed,
          details: ['Winner +', 'Total goals -', 'BTTS +', 'Cards -'],
        ),
      ],
      picks: [
        RewardPickOutcome(
          market: 'Chelsea to win',
          selection: 'Chelsea',
          stake: 100,
          payout: 240,
          profit: 140,
          outcome: RewardSettlementOutcome.won,
        ),
        RewardPickOutcome(
          market: 'Over 3.5 goals',
          selection: 'Over',
          stake: 75,
          payout: 0,
          profit: -75,
          outcome: RewardSettlementOutcome.lost,
        ),
        RewardPickOutcome(
          market: 'Inter draw no bet',
          selection: 'Inter',
          stake: 100,
          payout: 100,
          profit: 0,
          outcome: RewardSettlementOutcome.voided,
        ),
      ],
    );
  }

  final int xpWon;
  final int coinsWon;
  final List<RewardPredictOutcome> predicts;
  final List<RewardPickOutcome> picks;
}

class RewardPredictOutcome {
  const RewardPredictOutcome({
    required this.fixture,
    required this.summary,
    required this.xpWon,
    required this.outcome,
    required this.details,
  });

  final String fixture;
  final String summary;
  final int xpWon;
  final RewardSettlementOutcome outcome;
  final List<String> details;
}

class RewardPickOutcome {
  const RewardPickOutcome({
    required this.market,
    required this.selection,
    required this.stake,
    required this.payout,
    required this.profit,
    required this.outcome,
  });

  final String market;
  final String selection;
  final int stake;
  final int payout;
  final int profit;
  final RewardSettlementOutcome outcome;
}

class RewardSettlementPopup extends StatefulWidget {
  const RewardSettlementPopup({
    required this.data,
    required this.onDismiss,
    super.key,
  });

  final RewardSettlementDemoData data;
  final VoidCallback onDismiss;

  @override
  State<RewardSettlementPopup> createState() => _RewardSettlementPopupState();
}

class _RewardSettlementPopupState extends State<RewardSettlementPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = screenHeight * 0.75;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          return Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 34),
                  child: _RewardSheet(
                    data: widget.data,
                    height: sheetHeight,
                    bottomPadding: bottomPadding,
                    onDismiss: widget.onDismiss,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RewardSheet extends StatelessWidget {
  const _RewardSheet({
    required this.data,
    required this.height,
    required this.bottomPadding,
    required this.onDismiss,
  });

  final RewardSettlementDemoData data;
  final double height;
  final double bottomPadding;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('reward-settlement-sheet'),
      height: height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: CustomPaint(
          foregroundPainter: const _FlatHudSheetBorderPainter(),
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 22, smallCut: 7),
            child: ColoredBox(
              color: const Color(0xff151f31),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  math.max(14, bottomPadding + 10),
                ),
                child: Column(
                  children: [
                    _RewardHeader(data: data),
                    const SizedBox(height: 12),
                    Expanded(child: _RewardOutcomeList(data: data)),
                    const SizedBox(height: 12),
                    HudPagerButton(
                      label: 'CONTINUE',
                      focal: false,
                      enabled: true,
                      trailingIcon: Icons.keyboard_double_arrow_down,
                      onTap: onDismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlatHudSheetBorderPainter extends CustomPainter {
  const _FlatHudSheetBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const HudChamferClipper(
      bigCut: 22,
      smallCut: 7,
    ).buildPath(size);
    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.cyan.withValues(alpha: 0.82),
    );
    canvas.drawLine(
      const Offset(22, 0.6),
      Offset(size.width - 7, 0.6),
      Paint()
        ..strokeWidth = 2
        ..color = Cyber.cyan.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _FlatHudSheetBorderPainter oldDelegate) => false;
}

class _RewardHeader extends StatelessWidget {
  const _RewardHeader({required this.data});

  final RewardSettlementDemoData data;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff19243a),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'REWARDS SETTLED',
              textAlign: TextAlign.center,
              style: Cyber.display(26, color: Cyber.gold, letterSpacing: 2.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Predict and Picks results are in',
              textAlign: TextAlign.center,
              style: Cyber.body(13, color: Cyber.muted, letterSpacing: 0.3),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _RewardStatCell(
                    label: 'XP WON',
                    value: data.xpWon,
                    prefix: '+',
                    accent: Cyber.cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RewardStatCell(
                    label: 'COINS WON',
                    value: data.coinsWon,
                    prefix: '+',
                    accent: Cyber.gold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardStatCell extends StatelessWidget {
  const _RewardStatCell({
    required this.label,
    required this.value,
    required this.accent,
    this.prefix = '',
  });

  final String label;
  final int value;
  final Color accent;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return HistoryStatCell(
          label: label,
          value: '$prefix${animated.round()}',
          accent: accent,
          valueColor: accent,
        );
      },
    );
  }
}

class _RewardOutcomeList extends StatelessWidget {
  const _RewardOutcomeList({required this.data});

  final RewardSettlementDemoData data;

  @override
  Widget build(BuildContext context) {
    return _RewardOutcomeTabs(data: data);
  }
}

enum _RewardTab { predict, picks }

class _RewardOutcomeTabs extends StatefulWidget {
  const _RewardOutcomeTabs({required this.data});

  final RewardSettlementDemoData data;

  @override
  State<_RewardOutcomeTabs> createState() => _RewardOutcomeTabsState();
}

class _RewardOutcomeTabsState extends State<_RewardOutcomeTabs> {
  _RewardTab _active = _RewardTab.predict;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final showPredict = _active == _RewardTab.predict;
    return CustomPaint(
      foregroundPainter: const _FlatCutPanelBorderPainter(),
      child: ClipPath(
        clipper: CyberClipper(),
        child: ColoredBox(
          color: const Color(0xff172235),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _RewardTabButton(
                        label: 'PREDICT',
                        accent: Cyber.cyan,
                        count: data.predicts.length,
                        active: showPredict,
                        onTap: () =>
                            setState(() => _active = _RewardTab.predict),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RewardTabButton(
                        label: 'PICKS',
                        accent: Cyber.lime,
                        count: data.picks.length,
                        active: !showPredict,
                        onTap: () => setState(() => _active = _RewardTab.picks),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: ListView.separated(
                    key: ValueKey(_active),
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: showPredict
                        ? data.predicts.length
                        : data.picks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => showPredict
                        ? _PredictOutcomeCard(outcome: data.predicts[index])
                        : _PickOutcomeCard(outcome: data.picks[index]),
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

class _FlatCutPanelBorderPainter extends CustomPainter {
  const _FlatCutPanelBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.line.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _FlatCutPanelBorderPainter oldDelegate) => false;
}

class _RewardTabButton extends StatelessWidget {
  const _RewardTabButton({
    required this.label,
    required this.accent,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HistoryFilterChip(
      label: label,
      count: count,
      active: active,
      accent: accent,
      onTap: onTap,
    );
  }
}

class _PredictOutcomeCard extends StatelessWidget {
  const _PredictOutcomeCard({required this.outcome});

  final RewardPredictOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final meta = _OutcomeMeta.from(outcome.outcome);
    return FixtureCardFrame(
      tag: FixtureTagText(text: meta.label, color: meta.color),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREDICTION RESULT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(
              8,
              color: Cyber.muted.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            outcome.fixture,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(15, weight: FontWeight.w700, height: 1.15),
          ),
          const SizedBox(height: 6),
          Text(
            outcome.summary,
            style: Cyber.body(12, color: const Color(0xff9fb0c2)),
          ),
          const SizedBox(height: 10),
          Text(
            outcome.details.join('   '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(11, color: Cyber.muted, weight: FontWeight.w600),
          ),
        ],
      ),
      bottomStrip: FixtureCardStrip(
        topBorder: Cyber.cyan.withValues(alpha: 0.25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.change_history, color: Cyber.cyan, size: 15),
            const SizedBox(width: 6),
            Text(
              '+${outcome.xpWon} XP',
              style: Cyber.body(
                12.5,
                color: Cyber.cyan,
                weight: FontWeight.w700,
              ).copyWith(letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickOutcomeCard extends StatelessWidget {
  const _PickOutcomeCard({required this.outcome});

  final RewardPickOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final meta = _OutcomeMeta.from(outcome.outcome);
    final outcomeColor = _pickOutcomeColor(outcome);
    return FixtureCardFrame(
      tag: FixtureTagText(text: meta.label, color: meta.color),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREMIER LEAGUE / MATCH PICK',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(
              8,
              color: Cyber.muted.withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            outcome.market,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(15, weight: FontWeight.w700, height: 1.15),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HeldBadge(label: outcome.selection, color: outcomeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'YOUR PICK',
                      style: Cyber.label(
                        7,
                        color: Cyber.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      outcome.selection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(13, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TO WIN',
                    style: Cyber.label(
                      7,
                      color: Cyber.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CoinIcon(size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${outcome.stake} -> ${outcome.payout}',
                        style: Cyber.body(12.5, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomStrip: _PickSettlementStrip(outcome: outcome),
    );
  }
}

class _HeldBadge extends StatelessWidget {
  const _HeldBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.48 ? Colors.black : Colors.white;
    return SizedBox(
      width: 44,
      height: 36,
      child: CustomPaint(
        painter: FixtureBadgePainter(color: color),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _pickOutcomeCode(label),
                style: Cyber.label(11, color: ink, letterSpacing: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickSettlementStrip extends StatelessWidget {
  const _PickSettlementStrip({required this.outcome});

  final RewardPickOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return switch (outcome.outcome) {
      RewardSettlementOutcome.won => FixtureCardStrip(
        topBorder: Cyber.success.withValues(alpha: 0.25),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: Cyber.success, size: 13),
            const SizedBox(width: 6),
            Text(
              '+${outcome.profit} OZ PROFIT',
              style: Cyber.body(
                12,
                color: Cyber.success,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      RewardSettlementOutcome.lost => FixtureCardStrip(
        topBorder: Cyber.red.withValues(alpha: 0.18),
        child: Text(
          '-${outcome.stake} OZ',
          style: Cyber.body(
            12,
            color: Cyber.red.withValues(alpha: 0.9),
            weight: FontWeight.w800,
          ),
        ),
      ),
      RewardSettlementOutcome.voided => FixtureCardStrip(
        child: Text(
          'REFUNDED ${outcome.stake} OZ',
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ),
      RewardSettlementOutcome.mixed => FixtureCardStrip(
        child: Text(
          'SETTLED',
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ),
    };
  }
}

Color _pickOutcomeColor(RewardPickOutcome outcome) {
  return switch (outcome.outcome) {
    RewardSettlementOutcome.won => Cyber.success,
    RewardSettlementOutcome.lost => Cyber.red,
    RewardSettlementOutcome.voided => Cyber.muted,
    RewardSettlementOutcome.mixed => Cyber.gold,
  };
}

String _pickOutcomeCode(String label) {
  final cleaned = label
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
      .trim()
      .toUpperCase();
  if (cleaned.isEmpty) return 'P';
  final parts = cleaned.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return parts.map((part) => part[0]).take(3).join();
  }
  return cleaned.length <= 4 ? cleaned : cleaned.substring(0, 3);
}

class _OutcomeMeta {
  const _OutcomeMeta({required this.label, required this.color});

  factory _OutcomeMeta.from(RewardSettlementOutcome outcome) {
    return switch (outcome) {
      RewardSettlementOutcome.won => const _OutcomeMeta(
        label: 'WON',
        color: Cyber.success,
      ),
      RewardSettlementOutcome.lost => const _OutcomeMeta(
        label: 'LOST',
        color: Cyber.danger,
      ),
      RewardSettlementOutcome.voided => const _OutcomeMeta(
        label: 'REFUND',
        color: Cyber.amber,
      ),
      RewardSettlementOutcome.mixed => const _OutcomeMeta(
        label: 'SETTLED',
        color: Cyber.cyan,
      ),
    };
  }

  final String label;
  final Color color;
}
