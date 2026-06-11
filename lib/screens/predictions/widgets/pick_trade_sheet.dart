import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/picks/picks_cubit.dart';
import '../../../config/theme.dart';
import '../../../models/picks.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../shop/shop_screen.dart' show CoinIcon;

Future<bool> showPickTradeSheet({
  required BuildContext context,
  required PickMarket market,
  required PickOutcome outcome,
}) async {
  final result = await showModalBottomSheet<_PickTradeSuccess>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _PickTradeSheet(market: market, outcome: outcome),
  );
  if (result == null) return false;
  if (context.mounted) {
    await _showPickSuccessOverlay(context: context, success: result);
  }
  return true;
}

class _PickTradeSuccess {
  const _PickTradeSuccess({
    required this.marketQuestion,
    required this.outcomeLabel,
    required this.stakeOz,
    required this.shares,
    required this.maxPayoutOz,
  });

  final String marketQuestion;
  final String outcomeLabel;
  final int stakeOz;
  final int shares;
  final int maxPayoutOz;
}

class _PickTradeSheet extends StatefulWidget {
  const _PickTradeSheet({required this.market, required this.outcome});

  final PickMarket market;
  final PickOutcome outcome;

  @override
  State<_PickTradeSheet> createState() => _PickTradeSheetState();
}

class _PickTradeSheetState extends State<_PickTradeSheet> {
  late int _stakeOz = widget.outcome.probabilityPercent;
  bool _submitting = false;

  int get _price => widget.outcome.probabilityPercent;
  int get _shares =>
      PickMath.sharesForStake(stakeOz: _stakeOz, probabilityPercent: _price);
  int get _maxPayout => PickMath.payoutForShares(_shares);
  int get _profit => PickMath.profitFor(stakeOz: _stakeOz, shares: _shares);

  @override
  Widget build(BuildContext context) {
    final balance = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canConfirm =
        !_submitting &&
        widget.market.canBuy &&
        PickMath.isValidStake(
          stakeOz: _stakeOz,
          probabilityPercent: _price,
          balanceOz: balance,
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 18, smallCut: 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff152139), Color(0xff0b101c)],
            ),
            border: Border.all(color: Cyber.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HudLine(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'BUY PICK',
                          style: Cyber.label(
                            12,
                            color: Cyber.cyan,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const Spacer(),
                        _PercentPill(outcome: widget.outcome),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.market.question,
                      style: Cyber.body(
                        16,
                        weight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.outcome.label} costs $_price Oz per share',
                      style: Cyber.body(
                        12,
                        color: Cyber.muted,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SheetSummaryTile(
                          label: 'STAKE',
                          child: _CoinValue(value: _stakeOz),
                        ),
                        const SizedBox(width: 8),
                        _SheetSummaryTile(
                          label: 'SHARES',
                          child: Text(
                            '$_shares',
                            style: Cyber.label(
                              13,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SheetSummaryTile(
                          label: 'PAYOUT',
                          child: _CoinValue(value: _maxPayout),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SheetSummaryTile(
                          label: 'PROFIT IF RIGHT',
                          child: Text(
                            '+$_profit',
                            style: Cyber.label(
                              13,
                              color: Cyber.success,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SheetSummaryTile(
                          label: 'BALANCE AFTER',
                          child: _CoinValue(value: _balanceAfter(balance)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _StakeStepper(
                      value: _stakeOz,
                      step: _price,
                      max: balance,
                      onChanged: (value) => setState(() => _stakeOz = value),
                    ),
                    if (!canConfirm) ...[
                      const SizedBox(height: 10),
                      Text(
                        _disabledReason(balance),
                        style: Cyber.body(
                          11,
                          color: Cyber.amber,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetAction(
                        label: 'CANCEL',
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff243654)),
                    Expanded(
                      child: _SheetAction(
                        label: _submitting ? 'CONFIRMING' : 'CONFIRM',
                        color: canConfirm ? Cyber.cyan : Cyber.muted,
                        onTap: canConfirm ? () => _confirm(balance) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _disabledReason(int balance) {
    if (!widget.market.canBuy) return 'This market is closed.';
    if (balance < _price) return 'Not enough Oz Coins for one share.';
    if (_stakeOz > balance) return 'Stake is above your balance.';
    return 'Stake must be a multiple of $_price Oz.';
  }

  int _balanceAfter(int balance) =>
      _stakeOz >= balance ? 0 : balance - _stakeOz;

  Future<void> _confirm(int balance) async {
    setState(() => _submitting = true);
    final picks = context.read<PicksCubit>();
    final result = await picks.placePick(
      marketId: widget.market.id,
      outcomeId: widget.outcome.id,
      stakeOz: _stakeOz,
      balanceOz: balance,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xff121b30),
          content: Text(result.message, style: Cyber.body(12)),
        ),
      );
      return;
    }
    context.read<GameBloc>().add(CoinsSpent(result.stakeOz));
    playSound(SoundEffect.coins);
    Navigator.of(context).pop(
      _PickTradeSuccess(
        marketQuestion: widget.market.question,
        outcomeLabel: widget.outcome.label,
        stakeOz: _stakeOz,
        shares: _shares,
        maxPayoutOz: _maxPayout,
      ),
    );
  }
}

Future<void> _showPickSuccessOverlay({
  required BuildContext context,
  required _PickTradeSuccess success,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _PickSubmittedOverlay(success: success),
  );
}

class _PickSubmittedOverlay extends StatefulWidget {
  const _PickSubmittedOverlay({required this.success});

  final _PickTradeSuccess success;

  @override
  State<_PickSubmittedOverlay> createState() => _PickSubmittedOverlayState();
}

class _PickSubmittedOverlayState extends State<_PickSubmittedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
        final scrim = (t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15)).clamp(
          0.0,
          1.0,
        );
        final textOpacity = ((t - 0.22) / 0.25).clamp(0.0, 1.0);
        return Opacity(
          opacity: scrim,
          child: Material(
            color: Cyber.bg.withValues(alpha: 0.88),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: pop,
                      child: Container(
                        width: 112,
                        height: 112,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Cyber.success.withValues(alpha: 0.12),
                          border: Border.all(color: Cyber.success, width: 2.5),
                          boxShadow: Cyber.glow(
                            Cyber.success,
                            alpha: 0.62,
                            blur: 26,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Cyber.success,
                          size: 58,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: textOpacity,
                      child: Column(
                        children: [
                          Text(
                            'PICK LOCKED',
                            textAlign: TextAlign.center,
                            style: Cyber.display(21, letterSpacing: 2).copyWith(
                              shadows: [
                                Shadow(
                                  color: Cyber.success.withValues(alpha: 0.62),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.success.outcomeLabel.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: Cyber.label(
                              13,
                              color: Cyber.gold,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff10192d),
                              border: Border.all(color: Cyber.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CoinIcon(size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.success.stakeOz} STAKE',
                                  style: Cyber.label(
                                    10,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  '${widget.success.shares} SHARES',
                                  style: Cyber.label(
                                    10,
                                    color: Cyber.cyan,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  '${widget.success.maxPayoutOz} MAX',
                                  style: Cyber.label(
                                    10,
                                    color: Cyber.success,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.outcome});

  final PickOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: outcome.color.withValues(alpha: 0.14),
        border: Border.all(color: outcome.color.withValues(alpha: 0.75)),
      ),
      child: Text(
        '${outcome.label.toUpperCase()} ${outcome.probabilityPercent}%',
        style: Cyber.label(
          10,
          color: outcome.color,
          letterSpacing: 0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _SheetSummaryTile extends StatelessWidget {
  const _SheetSummaryTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 55,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.62),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(
                7,
                color: Cyber.muted.withValues(alpha: 0.72),
                letterSpacing: 1,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _StakeStepper extends StatelessWidget {
  const _StakeStepper({
    required this.value,
    required this.step,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int step;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > step;
    final canIncrease = value + step <= max;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.62),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            enabled: canDecrease,
            onTap: () => onChanged(value - step),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'AMOUNT',
                  style: Cyber.label(
                    7,
                    color: Cyber.muted.withValues(alpha: 0.72),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                _CoinValue(value: value),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.add,
            enabled: canIncrease,
            onTap: () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 48,
        child: Icon(
          icon,
          color: enabled ? Cyber.cyan : Cyber.muted.withValues(alpha: 0.35),
          size: 18,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Cyber.label(10, color: color, letterSpacing: 1.6),
          ),
        ),
      ),
    );
  }
}

class _CoinValue extends StatelessWidget {
  const _CoinValue({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoinIcon(size: 14),
        const SizedBox(width: 4),
        Text(
          _formatInt(value),
          style: Cyber.label(
            12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
