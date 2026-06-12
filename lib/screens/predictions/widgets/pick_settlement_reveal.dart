import 'package:flutter/material.dart';

import '../../../blocs/picks/picks_state.dart';
import '../../../config/theme.dart';
import '../../../models/picks.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../shop/shop_screen.dart' show CoinIcon;
import 'pick_status_style.dart';

enum PickRevealVerdict { win, loss, voided, mixed }

/// Everything the settlement cinematic needs, precomputed by the caller so the
/// overlay stays presentation-only (coins are credited before it shows).
class PickSettlementRevealData {
  const PickSettlementRevealData._({
    required this.title,
    required this.subtitle,
    required this.verdict,
    required this.stakeOz,
    required this.payoutOz,
    required this.winStreak,
  });

  /// A single settled position (the REVEAL RESULT path).
  factory PickSettlementRevealData.single({
    required PickPosition position,
    required int winStreak,
  }) {
    final verdict = switch (position.status) {
      PickPositionStatus.won => PickRevealVerdict.win,
      PickPositionStatus.voided => PickRevealVerdict.voided,
      _ => PickRevealVerdict.loss,
    };
    return PickSettlementRevealData._(
      title: position.marketQuestion,
      subtitle: position.outcomeLabel.toUpperCase(),
      verdict: verdict,
      stakeOz: position.stakeOz,
      payoutOz: position.payoutOz,
      winStreak: winStreak,
    );
  }

  /// A Claim All batch — one aggregate number, one cinematic.
  factory PickSettlementRevealData.batch({
    required PickBatchSettlementResult result,
    required int winStreak,
  }) {
    final verdict = result.wonCount == result.settledCount
        ? PickRevealVerdict.win
        : result.wonCount == 0
        ? PickRevealVerdict.loss
        : PickRevealVerdict.mixed;
    return PickSettlementRevealData._(
      title:
          '${result.settledCount} '
          '${result.settledCount == 1 ? 'PICK' : 'PICKS'} SETTLED',
      subtitle:
          '${result.wonCount} WON · ${result.settledCount - result.wonCount} LOST',
      verdict: verdict,
      stakeOz: result.stakeOz,
      payoutOz: result.payoutOz,
      winStreak: winStreak,
    );
  }

  final String title;
  final String subtitle;
  final PickRevealVerdict verdict;
  final int stakeOz;
  final int payoutOz;
  final int winStreak;

  int get profitOz => payoutOz - stakeOz;
}

/// Full-screen 3-beat settlement cinematic for coin picks, mirroring the quiz
/// reveal's language: verdict stamp → coin flow → summary. Tapping skips to
/// the summary; rewards are identical (the caller credits coins beforehand).
Future<void> showPickSettlementReveal(
  BuildContext context,
  PickSettlementRevealData data,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _PickSettlementOverlay(data: data),
  );
}

class _PickSettlementOverlay extends StatefulWidget {
  const _PickSettlementOverlay({required this.data});

  final PickSettlementRevealData data;

  @override
  State<_PickSettlementOverlay> createState() => _PickSettlementOverlayState();
}

class _PickSettlementOverlayState extends State<_PickSettlementOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _stampSounded = false;
  bool _coinsSounded = false;
  bool _streakSounded = false;

  PickSettlementRevealData get _data => widget.data;
  bool get _paidOut => _data.payoutOz > 0;
  bool get _showStreak =>
      _data.winStreak >= 2 && _data.verdict != PickRevealVerdict.loss;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2800),
          )
          ..addListener(_onTick)
          ..forward();
    playSound(SoundEffect.whoosh);
  }

  void _onTick() {
    final t = _controller.value;
    if (!_stampSounded && t >= 0.1) {
      _stampSounded = true;
      playSound(switch (_data.verdict) {
        PickRevealVerdict.win => SoundEffect.cardReveal,
        PickRevealVerdict.loss => SoundEffect.cardSlam,
        _ => SoundEffect.cardReveal,
      });
    }
    if (!_coinsSounded && t >= 0.38 && _paidOut) {
      _coinsSounded = true;
      playSound(SoundEffect.coins);
    }
    if (!_streakSounded && t >= 0.78 && _showStreak) {
      _streakSounded = true;
      playSound(SoundEffect.rarityGold);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_controller.value < 1) {
      _controller.value = 1;
      _onTick();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (_data.verdict) {
      PickRevealVerdict.win => Cyber.success,
      PickRevealVerdict.loss => Cyber.danger,
      PickRevealVerdict.voided => Cyber.muted,
      PickRevealVerdict.mixed => Cyber.gold,
    };
    final stampLabel = switch (_data.verdict) {
      PickRevealVerdict.win => 'WIN',
      PickRevealVerdict.loss => 'LOST',
      PickRevealVerdict.voided => 'VOID',
      PickRevealVerdict.mixed => 'SETTLED',
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Beat boundaries: stamp 0–0.32, coin flow 0.32–0.62, summary 0.62–1.
          final titleIn = Curves.easeOutCubic.transform(
            (t / 0.14).clamp(0.0, 1.0),
          );
          final stampIn = Curves.elasticOut.transform(
            ((t - 0.08) / 0.24).clamp(0.0, 1.0),
          );
          final burstIn = Curves.easeOutCubic.transform(
            ((t - 0.32) / 0.2).clamp(0.0, 1.0),
          );
          final coinIn = Curves.easeOutCubic.transform(
            ((t - 0.36) / 0.22).clamp(0.0, 1.0),
          );
          final summaryIn = Curves.easeOutCubic.transform(
            ((t - 0.62) / 0.24).clamp(0.0, 1.0),
          );
          final streakIn = Curves.elasticOut.transform(
            ((t - 0.78) / 0.22).clamp(0.0, 1.0),
          );
          final hintIn = ((t - 0.9) / 0.1).clamp(0.0, 1.0);

          return Material(
            color: Cyber.bg.withValues(alpha: 0.96),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Opacity(
                      opacity: titleIn,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - titleIn)),
                        child: Column(
                          children: [
                            Text(
                              'RESULTS ARE IN',
                              style: Cyber.label(
                                10,
                                color: Cyber.cyan,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _data.title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.body(
                                15,
                                weight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _data.subtitle,
                              textAlign: TextAlign.center,
                              style: Cyber.label(
                                10,
                                color: Cyber.muted,
                                letterSpacing: 1.3,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_data.verdict == PickRevealVerdict.win &&
                              burstIn > 0)
                            Opacity(
                              opacity: burstIn,
                              child: Transform.scale(
                                scale: 0.7 + 0.3 * burstIn,
                                child: const PackBurst(),
                              ),
                            ),
                          Transform.scale(
                            scale: stampIn,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                border: Border.all(color: accent, width: 2),
                                boxShadow: Cyber.glow(
                                  accent,
                                  alpha: 0.5,
                                  blur: 26,
                                ),
                              ),
                              child: Text(
                                stampLabel,
                                style: Cyber.display(
                                  34,
                                  color: accent,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 54, child: _coinFlow(coinIn)),
                    const Spacer(),
                    Opacity(
                      opacity: summaryIn,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - summaryIn)),
                        child: Row(
                          children: [
                            _SummaryTile(
                              label: 'STAKE',
                              value: formatOzGrouped(_data.stakeOz),
                            ),
                            const SizedBox(width: 8),
                            _SummaryTile(
                              label: 'PAYOUT',
                              value: formatOzGrouped(_data.payoutOz),
                              color: _paidOut ? Cyber.success : null,
                            ),
                            const SizedBox(width: 8),
                            _SummaryTile(
                              label: 'PROFIT',
                              value: _data.profitOz >= 0
                                  ? '+${formatOzGrouped(_data.profitOz)}'
                                  : '−${formatOzGrouped(-_data.profitOz)}',
                              color: _data.profitOz > 0
                                  ? Cyber.success
                                  : _data.profitOz < 0
                                  ? Cyber.danger
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 56,
                      child: _showStreak
                          ? Center(
                              child: Transform.scale(
                                scale: streakIn,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Cyber.gold.withValues(alpha: 0.12),
                                    border: Border.all(color: Cyber.gold),
                                    boxShadow: Cyber.glow(
                                      Cyber.gold,
                                      alpha: 0.4,
                                      blur: 16,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        color: Cyber.gold,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'WIN STREAK ×${_data.winStreak}',
                                        style: Cyber.label(
                                          11,
                                          color: Cyber.gold,
                                          letterSpacing: 1.2,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: hintIn,
                      child: Text(
                        'TAP TO CONTINUE',
                        style: Cyber.label(
                          9,
                          color: Cyber.muted,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Beat 2: a win counts the payout up; a loss sinks the stake; a void
  /// confirms the refund.
  Widget _coinFlow(double coinIn) {
    if (coinIn <= 0) return const SizedBox.shrink();
    if (_data.verdict == PickRevealVerdict.loss) {
      return Opacity(
        opacity: 0.35 + 0.65 * (1 - coinIn),
        child: Transform.translate(
          offset: Offset(0, 10 * coinIn),
          child: Center(
            child: Text(
              '−${formatOzGrouped(_data.stakeOz)} OZ',
              style: Cyber.display(
                24,
                color: Cyber.danger,
                letterSpacing: 1,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      );
    }
    if (_data.verdict == PickRevealVerdict.voided) {
      return Opacity(
        opacity: coinIn,
        child: Center(
          child: Text(
            'STAKE REFUNDED',
            style: Cyber.label(13, color: Cyber.muted, letterSpacing: 1.6),
          ),
        ),
      );
    }
    return Opacity(
      opacity: coinIn,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 26),
            const SizedBox(width: 10),
            Text(
              '+${formatOzGrouped((_data.payoutOz * coinIn).round())} OZ',
              style: Cyber.display(32, color: Cyber.gold, letterSpacing: 1)
                  .copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.55),
                        blurRadius: 22,
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff10192d),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Cyber.label(
                8,
                color: Cyber.muted.withValues(alpha: 0.72),
                letterSpacing: 1,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(
                13,
                color: color ?? Colors.white,
                letterSpacing: 0.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
