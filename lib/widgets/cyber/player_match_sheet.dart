import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import 'cyber_widgets.dart';

/// Opens a squad-paging player dossier.
///
/// Shared by the football and cricket match cards. The paging is the point: a
/// dossier you can swipe through turns comparing two team-mates into one
/// gesture instead of a close, a scroll and another tap.
Future<void> showPlayerMatchSheet({
  required BuildContext context,
  required Color accent,
  required int itemCount,
  required int initialIndex,
  required Widget Function(BuildContext, int) itemBuilder,
  String title = 'MATCH DOSSIER',
  String pagerNoun = 'PLAYER',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => PlayerMatchSheetScaffold(
      accent: accent,
      itemCount: itemCount,
      initialIndex: initialIndex,
      itemBuilder: itemBuilder,
      title: title,
      pagerNoun: pagerNoun,
    ),
  );
}

/// The chrome around a player dossier: header, lazy pager, footer hint.
class PlayerMatchSheetScaffold extends StatefulWidget {
  const PlayerMatchSheetScaffold({
    required this.accent,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    this.title = 'MATCH DOSSIER',
    this.pagerNoun = 'PLAYER',
    super.key,
  });

  final Color accent;
  final int itemCount;
  final int initialIndex;

  /// Built lazily — a squad of 40 must never be constructed at once.
  final Widget Function(BuildContext, int) itemBuilder;

  final String title;
  final String pagerNoun;

  @override
  State<PlayerMatchSheetScaffold> createState() =>
      _PlayerMatchSheetScaffoldState();
}

class _PlayerMatchSheetScaffoldState extends State<PlayerMatchSheetScaffold> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipPath(
        clipper: CyberClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: Cyber.bg,
            border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              _SheetGrip(accent: widget.accent, title: widget.title),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.itemCount,
                  onPageChanged: (page) {
                    HapticFeedback.selectionClick();
                    setState(() => _index = page);
                  },
                  itemBuilder: widget.itemBuilder,
                ),
              ),
              _SquadPager(
                count: widget.itemCount,
                index: _index,
                noun: widget.pagerNoun,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The drag handle plus the sheet's only always-on chrome.
class _SheetGrip extends StatelessWidget {
  const _SheetGrip({required this.accent, required this.title});

  final Color accent;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.8),
          ),
          const Spacer(),
          Container(width: 36, height: 3, color: accent.withValues(alpha: 0.5)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.close, size: 16, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

/// Position in the squad, and the hint that the card is swipeable at all.
class _SquadPager extends StatelessWidget {
  const _SquadPager({
    required this.count,
    required this.index,
    required this.noun,
  });

  final int count;
  final int index;
  final String noun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_left, size: 13, color: Cyber.muted),
          const SizedBox(width: 8),
          Text(
            'SWIPE FOR NEXT $noun  //  ${index + 1} OF $count',
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1.4),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 13, color: Cyber.muted),
        ],
      ),
    );
  }
}

/// A [CyberMiniMetric] whose number counts up on entry — the small
/// gratification beat that fires again on every swipe.
class CountUpMetric extends StatelessWidget {
  const CountUpMetric({
    required this.label,
    required this.value,
    required this.format,
    this.accent,
    super.key,
  });

  final String label;
  final double value;
  final String Function(double) format;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) =>
          CyberMiniMetric(label: label, value: format(animated), accent: accent),
    );
  }
}

/// A tap target that punches inward, so a row or node feels pressed rather than
/// merely navigating.
class TapPunch extends StatefulWidget {
  const TapPunch({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<TapPunch> createState() => _TapPunchState();
}

class _TapPunchState extends State<TapPunch> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
