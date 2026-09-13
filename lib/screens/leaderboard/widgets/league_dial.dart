import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/leaderboard_leagues.dart';
import '../../../utils/sound_effects.dart';
import 'rank_widgets.dart';

/// The flick-to-spin league selector that shares the leaderboard's scope row.
///
/// A horizontal wheel (a [ListWheelScrollView] turned on its side) so picking a
/// league feels like tuning a dial rather than tapping a chip: neighbours curve
/// away in 3D, every detent ticks, and the centred league takes its own accent.
///
/// Per the glow rule the centre notch is crisp chrome at rest — it only flashes
/// [Cyber.glow] for a beat as a league locks in.
class LeagueDial extends StatefulWidget {
  const LeagueDial({
    required this.leagues,
    required this.selectedId,
    required this.onSelect,
    this.width = 132,
    this.height = 38,
    super.key,
  });

  final List<LeaderboardLeague> leagues;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final double width;
  final double height;

  @override
  State<LeagueDial> createState() => _LeagueDialState();
}

class _LeagueDialState extends State<LeagueDial>
    with SingleTickerProviderStateMixin {
  static const double _itemExtent = 64;

  late final FixedExtentScrollController _wheel;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _wheel = FixedExtentScrollController(initialItem: _indexOf(widget.selectedId));
    // Rests at 1 so the notch sits dark; a detent drives it 0 → 1 again, which
    // reads as a flash that decays.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant LeagueDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Realign when the selection changes from outside the dial.
    final target = _indexOf(widget.selectedId);
    if (_wheel.hasClients && _wheel.selectedItem != target) {
      _wheel.animateToItem(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _wheel.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int _indexOf(String id) {
    final index = widget.leagues.indexWhere((league) => league.id == id);
    return index < 0 ? 0 : index;
  }

  /// Fires per detent while spinning, not just on settle — so a flick through
  /// four leagues ticks four times.
  void _onDetent(int index) {
    if (index < 0 || index >= widget.leagues.length) return;
    HapticFeedback.selectionClick();
    playSound(SoundEffect.countdownTick);
    _pulse.forward(from: 0);
    widget.onSelect(widget.leagues[index].id);
  }

  /// Fractional wheel position, so colour and opacity track the spin per pixel
  /// rather than snapping at each detent.
  double get _position {
    if (_wheel.hasClients && _wheel.position.hasPixels) {
      return _wheel.offset / _itemExtent;
    }
    return _indexOf(widget.selectedId).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.leagues[_indexOf(widget.selectedId)];
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _wheel,
            builder: (context, _) => _buildWheel(),
          ),
          // Dissolve the leagues at both edges instead of hard-cutting them.
          // Painted as an overlay rather than a ShaderMask: masking the wheel's
          // 3D-transformed layer drops it entirely on the web renderer.
          const IgnorePointer(child: _DialEdgeFade()),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) =>
                  _DialNotch(accent: selected.accent, pulse: 1 - _pulse.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    final position = _position;
    // quarterTurns 3 lays the wheel on its side; each child turns back upright.
    return ScrollConfiguration(
      // Flutter's default behaviour omits the mouse from drag devices, which
      // would leave the dial unspinnable on web/desktop.
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
        scrollbars: false,
        overscroll: false,
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: ListWheelScrollView.useDelegate(
          controller: _wheel,
          itemExtent: _itemExtent,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 2,
          perspective: 0.004,
          // No useMagnifier: it paints the centred child through its own layer,
          // which the web renderer drops. The centre is emphasised by `focus`
          // scaling below instead.
          onSelectedItemChanged: _onDetent,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.leagues.length,
            builder: (context, index) {
              final league = widget.leagues[index];
              final focus = (1 - (index - position).abs()).clamp(0.0, 1.0);
              return RotatedBox(
                quarterTurns: 1,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Opacity(
                        opacity: 0.42 + (0.58 * focus),
                        child: Transform.scale(
                          scale: 0.86 + (0.14 * focus),
                          child: Text(
                            league.shortCode,
                            maxLines: 1,
                            style: Cyber.display(
                              11,
                              color: Color.lerp(
                                Cyber.muted,
                                league.accent,
                                focus,
                              )!,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fades the leagues out at both ends of the dial so they slide away instead of
/// being clipped mid-glyph.
class _DialEdgeFade extends StatelessWidget {
  const _DialEdgeFade();

  @override
  Widget build(BuildContext context) {
    final clear = Cyber.bg.withValues(alpha: 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Cyber.bg, clear, clear, Cyber.bg],
          stops: const [0, 0.24, 0.66, 0.94],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// The centre slot's chamfered bracket. [pulse] runs 1 → 0 as a league locks in.
class _DialNotch extends StatelessWidget {
  const _DialNotch({required this.accent, required this.pulse});

  final Color accent;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_bar(flip: false), _bar(flip: true)],
      ),
    );
  }

  Widget _bar({required bool flip}) {
    final bar = Container(
      height: 4,
      decoration: ShapeDecoration(
        color: accent.withValues(alpha: 0.55 + (0.45 * pulse)),
        shape: const CutCornerBorder(cut: 3),
        shadows: pulse > 0.01
            ? Cyber.glow(accent, alpha: 0.4 * pulse, blur: 10, spread: 0)
            : null,
      ),
    );
    return flip ? RotatedBox(quarterTurns: 2, child: bar) : bar;
  }
}
