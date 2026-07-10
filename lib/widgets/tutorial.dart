import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../config/tutorial_steps.dart';
import 'cyber/cyber_widgets.dart';

class TutorialTip extends StatefulWidget {
  const TutorialTip({
    required this.keyName,
    required this.steps,
    this.forceToken = 0,
    super.key,
  });

  final String keyName;
  final List<TutorialStepData> steps;
  final int forceToken;

  @override
  State<TutorialTip> createState() => _TutorialTipState();
}

class _TutorialTipState extends State<TutorialTip> {
  bool _scheduled = false;
  int _lastForceToken = 0;

  @override
  void initState() {
    super.initState();
    _lastForceToken = widget.forceToken;
    _maybeSchedule();
  }

  @override
  void didUpdateWidget(covariant TutorialTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final forced = widget.forceToken != _lastForceToken;
    if (forced) {
      _lastForceToken = widget.forceToken;
      _scheduled = false;
      _schedule(force: true);
      return;
    }
    _maybeSchedule();
  }

  void _maybeSchedule() {
    // Schedule tutorial automatically if not yet seen (first launch experience)
    // This creates the guided walkthrough for new players
    if (!_scheduled && widget.steps.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Check if this tutorial has been seen by reading from GameBloc state
        final gameState = context.read<GameBloc>().state;
        if (!gameState.tutorialSeen.contains(widget.keyName)) {
          _schedule(force: false);
        }
      });
    }
  }

  void _schedule({bool force = false}) {
    if (_scheduled || widget.steps.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        builder: (_) => BlocProvider.value(
          value: context.read<GameBloc>(),
          child: TutorialDialog(
            keyName: widget.keyName,
            steps: widget.steps,
            force: force,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({
    required this.keyName,
    required this.steps,
    this.force = false,
    super.key,
  });

  final String keyName;
  final List<TutorialStepData> steps;
  final bool force;

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[index];
    final accent = step.accent;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: CyberPanel(
        accent: accent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: dot + onboarding label + skip all.
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent, blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '> ONBOARDING - ${(index + 1).toString().padLeft(2, '0')}/${widget.steps.length.toString().padLeft(2, '0')}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'Onest',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                TextButton(onPressed: _skipAll, child: const Text('SKIP ALL')),
              ],
            ),
            const SizedBox(height: 14),
            // Icon avatar + step badge + title.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Icon(step.icon, color: accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        color: accent.withValues(alpha: 0.18),
                        child: Text(
                          'STEP ${(index + 1).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: accent,
                            fontFamily: 'Orbitron',
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step.title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step.body,
              style: const TextStyle(
                color: Color(0xffd1d5db),
                fontFamily: 'Onest',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            if (step.hint != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                color: accent.withValues(alpha: 0.08),
                child: Text(
                  step.hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.9),
                    fontFamily: 'Orbitron',
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: i == widget.steps.length - 1 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: i == index
                            ? accent
                            : i < index
                            ? accent.withValues(alpha: 0.42)
                            : const Color(0xff1e2538),
                        boxShadow: i == index
                            ? [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.7),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const HudLine(),
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => index--),
                      child: const Text('< BACK'),
                    ),
                  ),
                Expanded(
                  child: TextButton(
                    onPressed: _next,
                    child: Text(
                      index < widget.steps.length - 1 ? 'NEXT >' : 'GOT IT >',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (index < widget.steps.length - 1) {
      setState(() => index++);
      return;
    }
    context.read<GameBloc>().add(TutorialSeenMarked(widget.keyName));
    Navigator.pop(context);
  }

  void _skipAll() {
    context.read<GameBloc>().add(TutorialsSkippedAll());
    Navigator.pop(context);
  }
}


void showTutorialNow(
  BuildContext context, {
  required String keyName,
  required List<TutorialStepData> steps,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => BlocProvider.value(
      value: context.read<GameBloc>(),
      child: TutorialDialog(keyName: keyName, steps: steps, force: true),
    ),
  );
}

