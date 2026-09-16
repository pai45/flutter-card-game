import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/streak.dart';
import '../models/streak_reminder.dart';
import '../screens/predictions/widgets/daily_quest_panel.dart'
    show questClock, questTimeLeft;
import '../utils/sound_effects.dart';
import 'cyber/cyber_cta_button.dart';
import 'cyber/cyber_widgets.dart';
import 'streak_widgets.dart';

/// What the player chose from a streak reminder. Null = dismissed.
enum StreakReminderAction { openHub, play, predict, pick }

/// Shows the escalating streak reminder as a bottom sheet and resolves with
/// the player's choice. Swipe down or tap the scrim to dismiss.
Future<StreakReminderAction?> showStreakReminder(
  BuildContext context, {
  required StreakReminderKind kind,
  required StreakSnapshot streak,
  required DateTime now,
}) {
  return showModalBottomSheet<StreakReminderAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Cyber.bg.withValues(alpha: 0.78),
    barrierLabel: 'Dismiss streak reminder',
    // Never full height: a strip of scrim always stays tappable to dismiss.
    constraints: BoxConstraints(
      maxWidth: 480,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (context) =>
        StreakReminderSheet(kind: kind, streak: streak, now: now),
  );
}

/// The moves that secure today, in the order the sheet offers them.
enum _Move {
  play(
    label: 'PLAY',
    icon: Icons.sports_esports,
    accent: Cyber.amber,
    cta: 'PLAY A GAME',
    action: StreakReminderAction.play,
  ),
  predict(
    label: 'PREDICT',
    icon: Icons.insights,
    accent: Cyber.cyan,
    cta: 'MAKE A PREDICTION',
    action: StreakReminderAction.predict,
  ),
  pick(
    label: 'PICK',
    icon: Icons.show_chart,
    accent: Cyber.lime,
    cta: 'PLACE A PICK',
    action: StreakReminderAction.pick,
  );

  const _Move({
    required this.label,
    required this.icon,
    required this.accent,
    required this.cta,
    required this.action,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final String cta;
  final StreakReminderAction action;
}

/// Preselects whatever the player did most recently — the lowest-effort way
/// back in is the habit they already have.
_Move _usualMove(StreakSnapshot streak) {
  final days = streak.activitiesByDay.keys.toList()..sort();
  for (final day in days.reversed) {
    final activities = streak.activitiesByDay[day];
    if (activities == null || activities.isEmpty) continue;
    return switch (activities.last) {
      StreakActivity.predict => _Move.predict,
      StreakActivity.pick => _Move.pick,
      _ => _Move.play,
    };
  }
  return _Move.play;
}

/// Loss-aversion sheet, read top to bottom: what's at stake (the run, the week
/// chain, the reward one day away, shield cover), then one choice of move and
/// a single ignition CTA that says exactly what the tap does.
class StreakReminderSheet extends StatefulWidget {
  const StreakReminderSheet({
    required this.kind,
    required this.streak,
    required this.now,
    super.key,
  });

  final StreakReminderKind kind;
  final StreakSnapshot streak;
  final DateTime now;

  @override
  State<StreakReminderSheet> createState() => _StreakReminderSheetState();
}

class _StreakReminderSheetState extends State<StreakReminderSheet> {
  late _Move _move = _usualMove(widget.streak);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.kind == StreakReminderKind.atRisk) {
        playSound(SoundEffect.streak);
        HapticFeedback.mediumImpact();
      } else {
        playSound(SoundEffect.uiConfirm);
      }
    });
  }

  void _close([StreakReminderAction? action]) =>
      Navigator.of(context).pop(action);

  void _select(_Move move) {
    if (move == _move) return;
    HapticFeedback.selectionClick();
    playSound(SoundEffect.uiTap);
    setState(() => _move = move);
  }

  @override
  Widget build(BuildContext context) {
    final atRisk = widget.kind == StreakReminderKind.atRisk;
    final accent = atRisk ? Cyber.danger : Cyber.amber;
    final streak = widget.streak;
    final now = widget.now;
    final current = streak.current(StreakCategory.overall, now: now);
    final left = questTimeLeft(now);
    final clock = questClock(left);
    final milestone = streakMilestones
        .where((milestone) => milestone.days > current)
        .firstOrNull;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Material(
          type: MaterialType.transparency,
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 22, smallCut: 6),
            child: CustomPaint(
              foregroundPainter: HudSheetFramePainter(
                bigCut: 22,
                smallCut: 6,
                accent: accent,
              ),
              child: ColoredBox(
                color: Cyber.card,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle sits outside the scroll view so a downward drag on it
                    // always reaches the sheet (swipe-to-dismiss) even when the
                    // content scrolls.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          color: Cyber.line.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: _StatusTag(
                                      label: atRisk ? 'AT RISK' : 'PENDING',
                                      accent: accent,
                                      pulse: atRisk,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: _HubLink(
                                      onTap: () =>
                                          _close(StreakReminderAction.openHub),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _FlameCore(
                                  state: atRisk
                                      ? StreakFlameState.atRisk
                                      : StreakFlameState.pending,
                                  count: current,
                                  accent: accent,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        atRisk
                                            ? 'STREAK AT RISK'
                                            : 'KEEP THE FIRE BURNING',
                                        style: Cyber.display(19, color: accent),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        atRisk
                                            ? '$clock left to save your $current-day run.'
                                            : 'Play anything today to make it ${current + 1}.',
                                        style: Cyber.body(
                                          14,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            CyberPanel(
                              accent: Cyber.line,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'LAST 7 DAYS',
                                        style: Cyber.label(
                                          9,
                                          color: Cyber.muted,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          atRisk
                                              ? 'TODAY NOT LIT'
                                              : 'RESETS IN $clock',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: Cyber.label(9, color: accent),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  StreakWeekChain(streak: streak, now: now),
                                  if (milestone != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      height: 1,
                                      color: Cyber.line.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 12),
                                    _MilestoneLine(
                                      milestone: milestone,
                                      current: current,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ShieldLine(shields: streak.shields),
                            const SizedBox(height: 20),
                            Text(
                              'PICK YOUR MOVE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.display(13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ANY ONE OF THESE LIGHTS TODAY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.label(
                                8.5,
                                color: Cyber.muted,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                for (final move in _Move.values) ...[
                                  if (move.index > 0) const SizedBox(width: 8),
                                  Expanded(
                                    child: _MoveTile(
                                      move: move,
                                      selected: move == _move,
                                      accent: accent,
                                      onTap: () => _select(move),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            CyberFuseCtaButton(
                              key: const ValueKey('streak-reminder-cta'),
                              label: _move.cta,
                              accent: accent,
                              fuse: left.inMinutes / Duration.minutesPerDay,
                              onTap: () => _close(_move.action),
                            ),
                          ],
                        ),
                      ),
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

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.label,
    required this.accent,
    required this.pulse,
  });

  final String label;
  final Color accent;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    Widget dot(double t) => Container(
      width: 6,
      height: 6,
      color: Color.lerp(accent.withValues(alpha: 0.35), accent, t),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.16), Cyber.panel),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: accent.withValues(alpha: 0.6)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pulse && !MediaQuery.disableAnimationsOf(context)
                ? CyberPulse(
                    period: const Duration(milliseconds: 620),
                    builder: (context, t) => dot(t),
                  )
                : dot(1),
            const SizedBox(width: 6),
            Text(label, style: Cyber.label(9.5, color: accent)),
          ],
        ),
      ),
    );
  }
}

class _HubLink extends StatelessWidget {
  const _HubLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open streak hub',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('STREAK HUB', style: Cyber.label(9.5, color: Cyber.cyan)),
              const Icon(Icons.chevron_right, size: 16, color: Cyber.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

/// The run itself: the live flame over the day count, on a chamfered plate.
class _FlameCore extends StatelessWidget {
  const _FlameCore({
    required this.state,
    required this.count,
    required this.accent,
  });

  final StreakFlameState state;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: ChamferedActionSurface(
        clipper: const HudChamferClipper(bigCut: 14, smallCut: 4),
        borderColor: accent.withValues(alpha: 0.55),
        child: ColoredBox(
          color: Color.alphaBlend(accent.withValues(alpha: 0.1), Cyber.panel),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreakFlame(state: state, size: 36),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$count',
                    maxLines: 1,
                    style: Cyber.display(32, letterSpacing: 0).copyWith(
                      height: 1.05,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1 ? 'DAY' : 'DAYS',
                  style: Cyber.label(
                    8.5,
                    color: Cyber.muted,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The carrot: the next milestone reward and how close today gets you.
class _MilestoneLine extends StatelessWidget {
  const _MilestoneLine({required this.milestone, required this.current});

  final StreakMilestone milestone;
  final int current;

  @override
  Widget build(BuildContext context) {
    final toGo = milestone.days - current;
    final accent = streakMilestoneAccent(milestone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              streakRewardIcon(milestone.rewardType),
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAY ${milestone.days} REWARD',
                    style: Cyber.label(
                      8.5,
                      color: Cyber.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    milestone.rewardLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              toGo == 1 ? 'UNLOCKS TODAY' : '$toGo DAYS AWAY',
              style: Cyber.label(9.5, color: toGo == 1 ? accent : Cyber.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CyberProgressBar(
          value: current / milestone.days,
          accent: accent,
          height: 6,
        ),
      ],
    );
  }
}

/// Honest shield cover: what's armed, or how to forge one.
class _ShieldLine extends StatelessWidget {
  const _ShieldLine({required this.shields});

  final int shields;

  @override
  Widget build(BuildContext context) {
    final armed = shields > 0;
    return Row(
      children: [
        StreakShieldPips(shields: shields, size: 15),
        const SizedBox(width: 10),
        Text(
          armed ? 'SHIELD ARMED' : 'NO SHIELD',
          style: Cyber.label(10, color: armed ? Cyber.cyan : Cyber.muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            armed
                ? 'Covers ${shields == 1 ? 'a missed day' : '$shields missed days'}.'
                : 'Clear the Daily Sweep to forge one.',
            maxLines: 2,
            style: Cyber.body(12, color: Cyber.muted, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// One selectable way to secure today. Selection is a crisp border + tint and a
/// corner tick; the glow stays on the CTA.
class _MoveTile extends StatelessWidget {
  const _MoveTile({
    required this.move,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final _Move move;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: move.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
          borderColor: selected ? accent : Cyber.line.withValues(alpha: 0.6),
          borderWidth: selected ? 1.5 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 78,
            color: selected
                ? Color.alphaBlend(accent.withValues(alpha: 0.14), Cyber.panel)
                : Cyber.panel,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        move.icon,
                        size: 24,
                        color: selected
                            ? move.accent
                            : move.accent.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            move.label,
                            maxLines: 1,
                            style: Cyber.label(
                              11,
                              color: selected ? Colors.white : Cyber.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      color: accent,
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: AppTheme.darkInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
