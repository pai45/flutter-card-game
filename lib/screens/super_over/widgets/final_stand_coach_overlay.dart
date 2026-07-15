import 'package:flutter/material.dart';

import '../../../blocs/super_over/super_over_state.dart';
import '../../../config/theme.dart';
import '../../../models/super_over.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// A slim, pitch-safe tutorial prompt. It occupies only the strip below the
/// scoreboard and never covers the bowler, batter, or shot controls.
class FinalStandCoachOverlay extends StatelessWidget {
  const FinalStandCoachOverlay({
    required this.state,
    required this.onSkip,
    super.key,
  });

  final SuperOverState state;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final lesson = _lessonFor(state);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 126, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 11, smallCut: 3),
            child: Material(
              key: const ValueKey('final-stand-coach'),
              color: Cyber.bg.withValues(alpha: .96),
              child: Container(
                constraints: const BoxConstraints(minHeight: 58, maxHeight: 76),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Cyber.cyan.withValues(alpha: .48)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Cyber.cyan.withValues(alpha: .12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Cyber.cyan.withValues(alpha: .72),
                        ),
                      ),
                      child: Text(
                        '${lesson.number}',
                        style: Cyber.display(
                          10,
                          color: Cyber.cyan,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(9, letterSpacing: .8),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            lesson.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.body(
                              8.5,
                              color: Cyber.muted,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                      ),
                      child: Text(
                        'SKIP',
                        style: Cyber.label(7, color: Cyber.muted),
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

  _CoachLesson _lessonFor(SuperOverState state) {
    if (state.phase == SuperOverPhase.targetReveal) {
      return const _CoachLesson(
        1,
        'THE FINAL STAND',
        'Six legal balls. Two wickets. Read the field, then time your shot.',
      );
    }
    return switch (state.ballsFaced.clamp(0, 5)) {
      0 => _CoachLesson(
        2,
        'READ THE FIELD',
        state.openSector == null
            ? 'The field is balanced. Pick the sector that matches the delivery.'
            : '${state.openSector!.label} is open. Aim there before the run-up.',
      ),
      1 => const _CoachLesson(
        3,
        'CHOOSE THE SHOT',
        'Ground is safer. Loft adds boundary power and catch risk.',
      ),
      2 => _CoachLesson(
        4,
        'READ LINE AND LENGTH',
        '${state.deliveryPlan.cue}. Let the line guide OFF, STRAIGHT, or LEG.',
      ),
      3 => const _CoachLesson(
        5,
        'WATCH THE BOUNCE',
        'Short balls reward an attacking pull. Track the ball and its shadow.',
      ),
      4 => const _CoachLesson(
        6,
        'NEED 6 FROM 2',
        'Dig out the yorker with Ground, then finish the scripted chase.',
      ),
      _ => const _CoachLesson(
        7,
        'CLUTCH CONTACT',
        'The timing rules stay fair under pressure. Watch release and finish.',
      ),
    };
  }
}

class _CoachLesson {
  const _CoachLesson(this.number, this.title, this.body);

  final int number;
  final String title;
  final String body;
}
