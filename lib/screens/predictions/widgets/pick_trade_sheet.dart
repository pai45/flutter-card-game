import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/picks/picks_cubit.dart';
import '../../../config/theme.dart';
import '../../../models/oz_coin_ledger.dart';
import '../../../models/picks.dart';
import '../../../models/streak.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../shop/shop_screen.dart' show CoinIcon;
import 'pick_status_style.dart';

Future<bool> showPickTradeSheet({
  required BuildContext context,
  required PickMarket market,
  required PickOutcome outcome,
}) async {
  final result = await showModalBottomSheet<_PickTradeSuccess>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _PickTradeSheet(market: market, outcome: outcome),
  );
  if (result == null) return false;
  if (context.mounted) {
    final streak = context.read<PicksCubit>().state.winStreak;
    await _showPickSuccessOverlay(
      context: context,
      success: result,
      winStreak: streak,
    );
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

/// Order-ticket style buy sheet: the potential payout is the hero number,
/// quick-stake chips make sizing one tap, and the confirm action is the one
/// glowing element.
class _PickTradeSheet extends StatefulWidget {
  const _PickTradeSheet({required this.market, required this.outcome});

  final PickMarket market;
  final PickOutcome outcome;

  @override
  State<_PickTradeSheet> createState() => _PickTradeSheetState();
}

class _PickTradeSheetState extends State<_PickTradeSheet> {
  late int _stakeOz = widget.outcome.probabilityPercent;
  late final TextEditingController _stakeController;
  bool _submitting = false;

  int get _price => widget.outcome.probabilityPercent;
  int get _shares =>
      PickMath.sharesForStake(stakeOz: _stakeOz, probabilityPercent: _price);
  int get _maxPayout => PickMath.payoutForShares(_shares);

  @override
  void initState() {
    super.initState();
    _stakeController = TextEditingController(text: '$_stakeOz');
  }

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final canConfirm =
        !_submitting &&
        widget.market.canBuy &&
        PickMath.isValidStake(
          stakeOz: _stakeOz,
          probabilityPercent: _price,
          balanceOz: balance,
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom + safeBottom + 16),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 18, smallCut: 4),
        child: CustomPaint(
          foregroundPainter: const HudSheetFramePainter(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff152139), Color(0xff0b101c)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                          18,
                          weight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '$_price OZ / SHARE',
                            style: Cyber.label(
                              8,
                              color: Cyber.muted,
                              letterSpacing: 1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'PAYS ${_multiplierLabel(_price)} IF RIGHT',
                            style: Cyber.label(
                              8,
                              color: Cyber.gold,
                              letterSpacing: 1,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _StakeStepper(
                        controller: _stakeController,
                        value: _stakeOz,
                        step: _price,
                        max: balance,
                        onChanged: _setStake,
                        onTextChanged: _setStakeFromText,
                      ),
                      const SizedBox(height: 12),
                      _ToWinHero(payoutOz: _maxPayout, price: _price),
                      const SizedBox(height: 8),
                      _QuickStakeRow(
                        price: _price,
                        balance: balance,
                        stakeOz: _stakeOz,
                        onChanged: _setStake,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$_shares ${_shares == 1 ? 'SHARE' : 'SHARES'} · '
                        'BALANCE AFTER '
                        '${formatOzGrouped(_balanceAfter(balance))} OZ',
                        style: Cyber.label(
                          8,
                          color: Cyber.muted,
                          letterSpacing: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (!canConfirm && !_submitting) ...[
                        const SizedBox(height: 8),
                        Text(
                          _disabledReason(balance),
                          style: Cyber.body(
                            11,
                            color: Cyber.amber,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      FilledButton(
                        onPressed: canConfirm ? () => _confirm(balance) : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Cyber.lime,
                          foregroundColor: Cyber.bg,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(
                          _submitting ? 'CONFIRMING' : 'CONFIRM PICK',
                          style: Cyber.label(
                            14,
                            color: Cyber.bg,
                            letterSpacing: 2,
                          ),
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
  }

  void _setStake(int value) {
    final next = value < 0 ? 0 : value;
    setState(() => _stakeOz = next);
    final text = '$next';
    if (_stakeController.text == text) return;
    _stakeController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _setStakeFromText(String value) {
    setState(() => _stakeOz = int.tryParse(value) ?? 0);
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
    context.read<GameBloc>().add(
      CoinsSpent(
        result.stakeOz,
        source: OzCoinTransactionSource.pickStake,
        title: 'PICK STAKE',
        subtitle: widget.market.question,
      ),
    );
    context.read<GameBloc>().add(StreakActivityRecorded(StreakActivity.pick));
    playSound(SoundEffect.coinSpend);
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

/// The hero of the ticket: what this pick pays if it hits. The number
/// retargets smoothly as the stake changes.
class _ToWinHero extends StatelessWidget {
  const _ToWinHero({required this.payoutOz, required this.price});

  final int payoutOz;
  final int price;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _ToWinFramePainter(),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Cyber.bg.withValues(alpha: 0.44)),
          child: Row(
            children: [
              Text(
                'TO WIN',
                style: Cyber.label(
                  8,
                  color: Cyber.lime.withValues(alpha: 0.68),
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              const CoinIcon(size: 16),
              const SizedBox(width: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: payoutOz.toDouble()),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  formatOzGrouped(v.round()),
                  style:
                      Cyber.display(
                        18,
                        color: Cyber.lime,
                        letterSpacing: 0.2,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Cyber.gold.withValues(alpha: 0.12),
                  border: Border.all(color: Cyber.gold.withValues(alpha: 0.45)),
                ),
                child: Text(
                  _multiplierLabel(price),
                  style: Cyber.label(
                    8.5,
                    color: Cyber.gold,
                    letterSpacing: 0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

/// Strokes the full chamfered TO-WIN silhouette so the diagonal corner cuts
/// keep their lime border (a clipped `Border.all` loses the cut edges).
class _ToWinFramePainter extends CustomPainter {
  const _ToWinFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const HudChamferClipper(
      bigCut: 8,
      smallCut: 2,
    ).buildPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.lime.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _ToWinFramePainter oldDelegate) => false;
}

/// One-tap stake sizing: share multiples of the price, plus an all-in MAX.
class _QuickStakeRow extends StatelessWidget {
  const _QuickStakeRow({
    required this.price,
    required this.balance,
    required this.stakeOz,
    required this.onChanged,
  });

  final int price;
  final int balance;
  final int stakeOz;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final maxStake = balance < price ? 0 : (balance ~/ price) * price;
    final presets = <({String label, int value})>[
      (label: '1×', value: price),
      (label: '5×', value: price * 5),
      (label: '10×', value: price * 10),
      (label: 'MAX', value: maxStake),
    ];
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++) ...[
          Expanded(
            child: _QuickStakeChip(
              label: presets[i].label,
              active: stakeOz == presets[i].value && presets[i].value > 0,
              enabled: presets[i].value > 0 && presets[i].value <= maxStake,
              onTap: () {
                playSound(SoundEffect.uiTap);
                onChanged(presets[i].value);
              },
            ),
          ),
          if (i != presets.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _QuickStakeChip extends StatelessWidget {
  const _QuickStakeChip({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xff12304a)
              : const Color(0xff111827).withValues(alpha: 0.86),
          border: Border.all(
            color: active
                ? Cyber.cyan.withValues(alpha: 0.7)
                : const Color(0xff273654),
          ),
        ),
        child: Text(
          label,
          style: Cyber.label(
            10,
            color: !enabled
                ? Cyber.muted.withValues(alpha: 0.4)
                : active
                ? Cyber.cyan
                : Cyber.muted,
            letterSpacing: 0.6,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

Future<void> _showPickSuccessOverlay({
  required BuildContext context,
  required _PickTradeSuccess success,
  required int winStreak,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        _PickSubmittedOverlay(success: success, winStreak: winStreak),
  );
}

class _PickSubmittedOverlay extends StatefulWidget {
  const _PickSubmittedOverlay({required this.success, required this.winStreak});

  final _PickTradeSuccess success;
  final int winStreak;

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
                          if (widget.winStreak >= 2) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Cyber.gold.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: Cyber.gold.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department,
                                    color: Cyber.gold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'WIN STREAK ×${widget.winStreak} — KEEP IT ALIVE',
                                    style: Cyber.label(
                                      9,
                                      color: Cyber.gold,
                                      letterSpacing: 1,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

class _StakeStepper extends StatelessWidget {
  const _StakeStepper({
    required this.controller,
    required this.value,
    required this.step,
    required this.max,
    required this.onChanged,
    required this.onTextChanged,
  });

  final TextEditingController controller;
  final int value;
  final int step;
  final int max;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > step;
    final canIncrease = value + step <= max;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Cyber.cyan.withValues(alpha: 0.08),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.62)),
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
                  'STAKE',
                  style: Cyber.label(
                    9,
                    color: Cyber.cyan.withValues(alpha: 0.82),
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 112,
                      child: TextField(
                        key: const ValueKey('pick_stake_input'),
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: onTextChanged,
                        textAlign: TextAlign.center,
                        cursorColor: Cyber.cyan,
                        style:
                            Cyber.display(
                              22,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          contentPadding: const EdgeInsets.only(bottom: 3),
                          // No box/fill — the digits sit on the STAKE surface;
                          // a thin cyan underline marks the editable number.
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Cyber.cyan.withValues(alpha: 0.7),
                              width: 1.4,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Cyber.cyan.withValues(alpha: 0.7),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

/// "2.4×" style payout multiplier for a share priced at [price] Oz.
String _multiplierLabel(int price) {
  if (price <= 0) return '—';
  final multiplier = 100 / price;
  var text = multiplier.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '$text×';
}
