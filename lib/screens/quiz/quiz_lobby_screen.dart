import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/quiz/quiz_cubit.dart';
import '../../blocs/quiz/quiz_state.dart';
import '../../config/theme.dart';
import '../../models/quiz_trivia.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import 'quiz_play_screen.dart';

/// The Football Quiz lobby: a 2×2 ladder of mode tiles (EASY → MEDIUM → HARD →
/// GLOBAL). Easy is always open; the rest unlock by clearing the prior tier, so
/// locked tiles wear a padlock + "CLEAR … TO UNLOCK". Unlocked tiles surface the
/// player's best run, pulling them back for another go.
class QuizLobbyScreen extends StatelessWidget {
  const QuizLobbyScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  void _play(BuildContext context, QuizMode mode) {
    playSound(SoundEffect.playMatch);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuizPlayScreen(mode: mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Football Quiz',
      subtitle: 'TRIVIA GAUNTLET',
      leading: _BackButton(onTap: onBack),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Cyber.cyan),
            );
          }
          const modes = QuizMode.values;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ProgressHeader(progress: state.progress),
              const SizedBox(height: 16),
              Text(
                'CHOOSE YOUR LEVEL',
                style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1.8),
              ),
              const SizedBox(height: 12),
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 14),
                Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col > 0) const SizedBox(width: 14),
                      Expanded(
                        child: CyberDealtCard(
                          index: row * 2 + col,
                          child: _ModeTile(
                            mode: modes[row * 2 + col],
                            unlocked: state.isUnlocked(modes[row * 2 + col]),
                            progress: state.progressFor(modes[row * 2 + col]),
                            onPlay: () =>
                                _play(context, modes[row * 2 + col]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap();
      },
      child: const Center(
        child: Icon(Icons.arrow_back_ios_new, size: 18, color: Cyber.cyan),
      ),
    );
  }
}

/// Top summary: cleared count + a progress bar across the four modes.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});

  final QuizProgress progress;

  @override
  Widget build(BuildContext context) {
    final cleared = progress.clearedCount;
    final total = QuizMode.values.length;
    return CyberPanel(
      accent: Cyber.violet,
      solidBackground: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: Cyber.violet, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'KNOWLEDGE LADDER',
                  style: Cyber.display(15, color: Colors.white, letterSpacing: 1.2),
                ),
              ),
              Text(
                '$cleared/$total',
                style: Cyber.display(16, color: Cyber.violet)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CyberProgressBar(value: total == 0 ? 0 : cleared / total, accent: Cyber.violet),
          const SizedBox(height: 8),
          Text(
            cleared == total
                ? 'Every level cleared — you are a football oracle.'
                : 'Clear a level to unlock the next. Every answer pays XP.',
            style: Cyber.body(12, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.unlocked,
    required this.progress,
    required this.onPlay,
  });

  final QuizMode mode;
  final bool unlocked;
  final QuizModeProgress progress;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    final borderColor = unlocked
        ? accent.withValues(alpha: 0.7)
        : Cyber.line.withValues(alpha: 0.30);

    return Opacity(
      opacity: unlocked ? 1 : 0.6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unlocked ? onPlay : null,
        child: Container(
          height: 168,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: unlocked
                ? Color.lerp(Cyber.panel, accent, 0.06)
                : Cyber.panel.withValues(alpha: 0.55),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: unlocked ? 0.16 : 0.08),
                      border: Border.all(
                        color: accent.withValues(alpha: unlocked ? 0.6 : 0.25),
                      ),
                    ),
                    child: Icon(
                      unlocked ? mode.icon : Icons.lock_outline,
                      color: unlocked ? accent : Cyber.muted,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (unlocked && progress.cleared)
                    const Icon(Icons.verified, color: Cyber.success, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mode.label,
                style: Cyber.display(
                  18,
                  color: unlocked ? Colors.white : Cyber.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mode.blurb,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
              ),
              const Spacer(),
              if (unlocked)
                _UnlockedFooter(mode: mode, progress: progress)
              else
                _LockedFooter(mode: mode),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockedFooter extends StatelessWidget {
  const _UnlockedFooter({required this.mode, required this.progress});

  final QuizMode mode;
  final QuizModeProgress progress;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    if (!progress.hasRun) {
      return Row(
        children: [
          Icon(Icons.play_circle_outline, color: accent, size: 15),
          const SizedBox(width: 6),
          Text(
            'PLAY · +${mode.reward} XP EACH',
            style: Cyber.label(9, color: accent, letterSpacing: 0.8),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BEST ${progress.bestCorrect}/${progress.bestTotal}',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            Text(
              '${(progress.bestPct * 100).round()}%',
              style: Cyber.display(12, color: accent)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        CyberProgressBar(
          value: progress.bestPct,
          accent: accent,
          height: 6,
          animate: false,
        ),
      ],
    );
  }
}

class _LockedFooter extends StatelessWidget {
  const _LockedFooter({required this.mode});

  final QuizMode mode;

  @override
  Widget build(BuildContext context) {
    final prev = mode.unlockedBy;
    return Row(
      children: [
        const Icon(Icons.lock_outline, color: Cyber.muted, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            prev == null ? 'LOCKED' : 'CLEAR ${prev.label} TO UNLOCK',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }
}
