import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/quiz/quiz_cubit.dart';
import '../../blocs/quiz/quiz_state.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/quiz_trivia.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../shop/widgets/shop_card.dart';
import 'quiz_play_screen.dart';

class QuizLobbyScreen extends StatelessWidget {
  const QuizLobbyScreen({required this.sport, required this.onBack, super.key});

  final Sport sport;
  final VoidCallback onBack;

  void _openSets(BuildContext context, QuizMode mode) {
    playSound(SoundEffect.uiTap);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => QuizSetScreen(sport: sport, mode: mode)));
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '${sport.name.toUpperCase()} QUIZ',
      subtitle: 'TRIVIA SET LADDER',
      leading: _BackButton(onTap: onBack),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Cyber.cyan),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ProgressHeader(sport: sport, progress: state.progressForSport(sport)),
              const SizedBox(height: 16),
              Text(
                'CHOOSE YOUR CATEGORY',
                style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1.8),
              ),
              const SizedBox(height: 12),
              for (final mode in QuizMode.values) ...[
                CyberDealtCard(
                  index: mode.index,
                  child: _ModeTile(
                    mode: mode,
                    progress: state.progressFor(sport, mode),
                    onTap: () => _openSets(context, mode),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class QuizSetScreen extends StatefulWidget {
  const QuizSetScreen({required this.sport, required this.mode, super.key});

  final Sport sport;
  final QuizMode mode;

  @override
  State<QuizSetScreen> createState() => _QuizSetScreenState();
}

class _QuizSetScreenState extends State<QuizSetScreen> {
  int? _launchingSet;

  Future<void> _startSet(int setNumber) async {
    if (_launchingSet != null) return;
    final quiz = context.read<QuizCubit>();
    if (!quiz.isSetUnlocked(widget.sport, widget.mode, setNumber)) return;

    final game = context.read<GameBloc>();
    if (game.state.coins < kQuizEntryCost) {
      _showMessage('Need $kQuizEntryCost coins to play this quiz set.');
      return;
    }

    setState(() => _launchingSet = setNumber);
    playSound(SoundEffect.playMatch);
    game.add(
      CoinsSpent(
        kQuizEntryCost,
        source: OzCoinTransactionSource.quizEntry,
        title: '${widget.sport.name.toUpperCase()} QUIZ ENTRY',
        subtitle: '${widget.mode.label} SET $setNumber',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPlayScreen(sport: widget.sport, mode: widget.mode, setNumber: setNumber),
      ),
    );
    if (mounted) setState(() => _launchingSet = null);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1700),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    return GameScaffold(
      title: '${mode.label} Sets',
      subtitle: '25 COINS PER ATTEMPT',
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          final progress = state.progressFor(widget.sport, mode);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SetHeader(mode: mode, progress: progress),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.28,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: kQuizSetCount,
                itemBuilder: (context, index) {
                  final setNumber = index + 1;
                  return _SetTile(
                    mode: mode,
                    setNumber: setNumber,
                    progress: progress.setProgress(setNumber),
                    unlocked: progress.isSetUnlocked(setNumber),
                    launching: _launchingSet == setNumber,
                    onTap: () => _startSet(setNumber),
                  );
                },
              ),
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

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.sport, required this.progress});

  final Sport sport;
  final QuizProgress progress;

  @override
  Widget build(BuildContext context) {
    final passed = QuizMode.values.fold<int>(
      0,
      (sum, mode) => sum + progress.forMode(mode).passedCount,
    );
    final total = QuizMode.values.length * kQuizSetCount;
    return CyberPanel(
      accent: Cyber.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.public, color: Cyber.violet, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'KNOWLEDGE SETS',
                  style: Cyber.display(
                    15,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                '$passed/$total',
                style: Cyber.display(16, color: Cyber.violet),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CyberProgressBar(value: passed / total, accent: Cyber.violet),
          const SizedBox(height: 8),
          Text(
            'All categories are open. Complete each set to unlock the next one inside that category.',
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
    required this.progress,
    required this.onTap,
  });

  final QuizMode mode;
  final QuizModeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(
          color: Color.lerp(Cyber.panel, accent, 0.055),
          border: Border.all(color: accent.withValues(alpha: 0.42)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                border: Border.all(color: accent.withValues(alpha: 0.46)),
              ),
              child: Icon(mode.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: Cyber.display(18, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.passedCount}/$kQuizSetCount SETS · +${mode.reward} XP/CORRECT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      9,
                      color: Cyber.muted,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CyberProgressBar(
                    value: progress.passedCount / kQuizSetCount,
                    accent: accent,
                    height: 6,
                    animate: false,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: accent, size: 24),
          ],
        ),
      ),
    );
  }
}

class _SetHeader extends StatelessWidget {
  const _SetHeader({required this.mode, required this.progress});

  final QuizMode mode;
  final QuizModeProgress progress;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    return CyberPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(mode.icon, color: accent, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${mode.label} LADDER',
                  style: Cyber.display(15, color: Colors.white),
                ),
              ),
              Text(
                '${progress.passedCount}/$kQuizSetCount',
                style: Cyber.display(16, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 11),
          CyberProgressBar(
            value: progress.passedCount / kQuizSetCount,
            accent: accent,
            height: 7,
          ),
          const SizedBox(height: 8),
          Text(
            'Pass with 5 or fewer wrong answers. Each attempt costs $kQuizEntryCost coins.',
            style: Cyber.body(12, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.mode,
    required this.setNumber,
    required this.progress,
    required this.unlocked,
    required this.launching,
    required this.onTap,
  });

  final QuizMode mode;
  final int setNumber;
  final QuizSetProgress progress;
  final bool unlocked;
  final bool launching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    final passed = progress.passed;
    return Opacity(
      opacity: unlocked ? 1 : 0.48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unlocked && !launching ? onTap : null,
        child: ShopCardFrame(
          accent: passed ? Cyber.success : accent,
          focal: launching,
          elevated: unlocked,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? Color.lerp(Cyber.panel, accent, 0.045)
                        : Cyber.panel.withValues(alpha: 0.52),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            passed
                                ? Icons.verified_rounded
                                : unlocked
                                ? Icons.play_circle_outline
                                : Icons.lock_outline,
                            color: passed
                                ? Cyber.success
                                : unlocked
                                ? accent
                                : Cyber.muted,
                            size: 18,
                          ),
                          const Spacer(),
                          Text(
                            '#$setNumber',
                            style: Cyber.display(
                              15,
                              color: unlocked ? accent : Cyber.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'SET $setNumber',
                        style: Cyber.display(
                          15,
                          color: unlocked ? Colors.white : Cyber.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        unlocked
                            ? mode.blurb
                            : 'COMPLETE SET ${setNumber - 1} TO UNLOCK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          7.5,
                          color: Cyber.muted,
                          letterSpacing: 0.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 36,
                color: Colors.black.withValues(alpha: 0.88),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  !unlocked
                      ? 'COMPLETE SET ${setNumber - 1}'
                      : launching
                      ? 'OPENING...'
                      : progress.hasRun
                      ? 'BEST ${progress.bestCorrect}/$kQuizQuestionsPerSet · $kQuizEntryCost COINS'
                      : 'PLAY · $kQuizEntryCost COINS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(
                    unlocked ? 8.5 : 7.5,
                    color: !unlocked
                        ? Cyber.muted
                        : passed
                        ? Cyber.success
                        : accent,
                    letterSpacing: 0.55,
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
