import 'dart:ui';

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

/// Shows the escalating streak reminder as a moment popup and resolves with
/// the player's choice.
Future<StreakReminderAction?> showStreakReminder(
  BuildContext context, {
  required StreakReminderKind kind,
  required StreakSnapshot streak,
  required DateTime now,
}) {
  return showGeneralDialog<StreakReminderAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss streak reminder',
    barrierColor: Cyber.bg.withValues(alpha: 0.82),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) =>
        StreakReminderDialog(kind: kind, streak: streak, now: now),
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

/// Loss-aversion beat: the live flame, the run count and the week chain that
/// is about to snap, one CTA into the hub and one-tap PLAY / PREDICT / PICK.
class StreakReminderDialog extends StatefulWidget {
  const StreakReminderDialog({
    required this.kind,
    required this.streak,
    required this.now,
    super.key,
  });

  final StreakReminderKind kind;
  final StreakSnapshot streak;
  final DateTime now;

  @override
  State<StreakReminderDialog> createState() => _StreakReminderDialogState();
}

class _StreakReminderDialogState extends State<StreakReminderDialog> {
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

  @override
  Widget build(BuildContext context) {
    final atRisk = widget.kind == StreakReminderKind.atRisk;
    final accent = atRisk ? Cyber.danger : Cyber.amber;
    final streak = widget.streak;
    final current = streak.current(StreakCategory.overall, now: widget.now);
    final line = atRisk
        ? '${questClock(questTimeLeft(widget.now))} left to save your $current-day run.'
        : 'Play anything today to make it ${current + 1}.';

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  type: MaterialType.transparency,
                  child: SingleChildScrollView(
                    child: StreakMomentPanel(
                      accent: accent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreakFlame(
                                state: atRisk
                                    ? StreakFlameState.atRisk
                                    : StreakFlameState.pending,
                                size: 44,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$current',
                                style: Cyber.display(46, letterSpacing: 0)
                                    .copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DAY\nSTREAK',
                                style: Cyber.label(
                                  10,
                                  color: Cyber.muted,
                                  letterSpacing: 1.2,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            atRisk ? 'STREAK AT RISK' : 'KEEP THE FIRE BURNING',
                            textAlign: TextAlign.center,
                            style: Cyber.display(18, color: accent),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            line,
                            textAlign: TextAlign.center,
                            style: Cyber.body(
                              13.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          if (atRisk && streak.shields > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                StreakShieldPips(
                                  shields: streak.shields,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SHIELD ARMED',
                                  style: Cyber.label(10, color: Cyber.cyan),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          StreakWeekChain(
                            streak: streak,
                            now: widget.now,
                            compact: true,
                          ),
                          const SizedBox(height: 18),
                          HudCtaButton(
                            label: atRisk ? 'SAVE MY STREAK' : 'KEEP IT ALIVE',
                            icon: Icons.local_fire_department,
                            accent: accent,
                            height: 52,
                            labelStyle: Cyber.display(17),
                            tapSound: SoundEffect.uiConfirm,
                            onTap: () => _close(StreakReminderAction.openHub),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              CyberObjectiveAction(
                                label: 'PLAY',
                                icon: Icons.sports_esports,
                                accent: Cyber.amber,
                                onTap: () => _close(StreakReminderAction.play),
                              ),
                              CyberObjectiveAction(
                                label: 'PREDICT',
                                icon: Icons.insights,
                                onTap: () =>
                                    _close(StreakReminderAction.predict),
                              ),
                              CyberObjectiveAction(
                                label: 'PICK',
                                icon: Icons.show_chart,
                                accent: Cyber.lime,
                                onTap: () => _close(StreakReminderAction.pick),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            button: true,
                            label: 'Not now',
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                playSound(SoundEffect.uiTap);
                                _close();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'NOT NOW',
                                  style: Cyber.label(
                                    10,
                                    color: Cyber.muted,
                                    letterSpacing: 1.4,
                                  ),
                                ),
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
          ),
        ),
      ],
    );
  }
}
