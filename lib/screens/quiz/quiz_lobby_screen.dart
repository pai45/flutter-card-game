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
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import 'quiz_play_screen.dart';

enum QuizSetVisualState { cleared, retry, available, locked }

class QuizLobbyScreen extends StatelessWidget {
  const QuizLobbyScreen({required this.sport, required this.onBack, super.key});

  final Sport sport;
  final VoidCallback onBack;

  void _openSets(BuildContext context, QuizMode mode) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizSetScreen(sport: sport, mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '${sport.name.toUpperCase()} QUIZ',
      subtitle: 'KNOWLEDGE ARENA',
      leading: _BackButton(onTap: onBack),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Cyber.cyan),
            );
          }
          final progress = state.progressForSport(sport);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CyberSlideUpFadeIn(
                        child: _KnowledgeArenaHero(
                          sport: sport,
                          progress: progress,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel(label: 'CHOOSE A CATEGORY'),
                      const SizedBox(height: 10),
                      for (final mode in QuizMode.values) ...[
                        CyberDealtCard(
                          key: ValueKey('quiz-mode-${mode.name}'),
                          index: mode.index,
                          initialDelay: const Duration(milliseconds: 120),
                          child: _ModeTile(
                            mode: mode,
                            progress: progress.forMode(mode),
                            onTap: () => _openSets(context, mode),
                          ),
                        ),
                        if (mode != QuizMode.values.last)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
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
  int? _selectedChapter;
  int? _launchingSet;

  int _nextChallenge(QuizModeProgress progress) {
    for (var set = 1; set <= kQuizSetCount; set++) {
      if (progress.isSetUnlocked(set) && !progress.setProgress(set).passed) {
        return set;
      }
    }
    return kQuizSetCount;
  }

  QuizSetVisualState _visualState(QuizModeProgress progress, int setNumber) {
    final set = progress.setProgress(setNumber);
    if (set.passed) return QuizSetVisualState.cleared;
    if (!progress.isSetUnlocked(setNumber)) return QuizSetVisualState.locked;
    if (set.hasRun) return QuizSetVisualState.retry;
    return QuizSetVisualState.available;
  }

  Future<void> _startSet(int setNumber) async {
    if (_launchingSet != null) return;
    final quiz = context.read<QuizCubit>();
    if (!quiz.isSetUnlocked(widget.sport, widget.mode, setNumber)) return;

    setState(() => _launchingSet = setNumber);
    final game = context.read<GameBloc>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntryBriefing(
        sport: widget.sport,
        mode: widget.mode,
        setNumber: setNumber,
        coins: game.state.coins,
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _launchingSet = null);
      return;
    }
    if (game.state.coins < kQuizEntryCost) {
      setState(() => _launchingSet = null);
      _showMessage('Need $kQuizEntryCost coins to play this quiz set.');
      return;
    }

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
        builder: (_) => QuizPlayScreen(
          sport: widget.sport,
          mode: widget.mode,
          setNumber: setNumber,
        ),
      ),
    );
    if (!mounted) return;
    final updated = quiz.progressFor(widget.sport, widget.mode);
    setState(() {
      _launchingSet = null;
      _selectedChapter = (_nextChallenge(updated) - 1) ~/ 10;
    });
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
      title: '${mode.label} SETS',
      subtitle: 'KNOWLEDGE LADDER',
      leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      rightSlot: const _CoinBalance(),
      child: BlocBuilder<QuizCubit, QuizState>(
        builder: (context, state) {
          final progress = state.progressFor(widget.sport, mode);
          final nextChallenge = _nextChallenge(progress);
          final selectedChapter = _selectedChapter ?? (nextChallenge - 1) ~/ 10;
          final firstSet = selectedChapter * 10 + 1;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NextChallengeCard(
                        mode: mode,
                        setNumber: nextChallenge,
                        progress: progress.setProgress(nextChallenge),
                        ladderComplete: progress.passedCount == kQuizSetCount,
                        launching: _launchingSet == nextChallenge,
                        onTap: () => _startSet(nextChallenge),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: SectionLabel(label: 'SET CHAPTERS'),
                          ),
                          Text(
                            '${progress.passedCount}/$kQuizSetCount CLEARED',
                            style: Cyber.label(
                              9,
                              color: mode.accent,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ChapterSelector(
                        selected: selectedChapter,
                        accent: mode.accent,
                        onSelected: (chapter) {
                          playSound(SoundEffect.uiTap);
                          setState(() => _selectedChapter = chapter);
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 350 ? 4 : 5;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: 0.8,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: 10,
                            itemBuilder: (context, index) {
                              final setNumber = firstSet + index;
                              final visualState = _visualState(
                                progress,
                                setNumber,
                              );
                              return _SetTile(
                                key: ValueKey('quiz-set-$setNumber'),
                                mode: mode,
                                setNumber: setNumber,
                                progress: progress.setProgress(setNumber),
                                visualState: visualState,
                                launching: _launchingSet == setNumber,
                                onTap: () => _startSet(setNumber),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _LadderRule(mode: mode),
                    ],
                  ),
                ),
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
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: const Center(
          child: Icon(Icons.arrow_back_ios_new, size: 18, color: Cyber.cyan),
        ),
      ),
    );
  }
}

class _KnowledgeArenaHero extends StatelessWidget {
  const _KnowledgeArenaHero({required this.sport, required this.progress});

  final Sport sport;
  final QuizProgress progress;

  @override
  Widget build(BuildContext context) {
    final passed = QuizMode.values.fold<int>(
      0,
      (sum, mode) => sum + progress.forMode(mode).passedCount,
    );
    final total = QuizMode.values.length * kQuizSetCount;
    final progressValue = total == 0 ? 0.0 : passed / total;
    final progressPercent = (progressValue * 100).round();

    return Semantics(
      container: true,
      label:
          'Knowledge Arena. ${sport.name} trivia with four categories. '
          '$passed of $total sets cleared. Every attempt contains 10 questions.',
      child: CyberPanel(
        accent: Cyber.cyan,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
              child: Row(
                children: [
                  Container(width: 5, height: 5, color: Cyber.cyan),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'QUIZ GRID // ${sport.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7.5,
                        color: Cyber.cyan,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: 1,
                    color: Cyber.cyan.withValues(alpha: 0.16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '04 TRACKS',
                    style: Cyber.label(
                      7.5,
                      color: Cyber.muted,
                      letterSpacing: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    height: 72,
                    child: ChamferedActionSurface(
                      clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
                      borderColor: Cyber.cyan.withValues(alpha: 0.58),
                      child: ColoredBox(
                        color: Color.lerp(Cyber.panel2, Cyber.cyan, 0.08)!,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              _sportIcon(sport),
                              color: Cyber.cyan,
                              size: 30,
                            ),
                            Positioned(
                              top: 9,
                              right: 9,
                              child: Container(
                                width: 5,
                                height: 5,
                                color: Cyber.cyan,
                              ),
                            ),
                            Positioned(
                              left: 9,
                              bottom: 8,
                              child: Text(
                                'TRIVIA',
                                style: Cyber.label(
                                  6.5,
                                  color: Cyber.muted,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'KNOWLEDGE',
                            style: Cyber.display(15.5, letterSpacing: 1.35),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ARENA',
                          style: Cyber.display(
                            22,
                            color: Cyber.cyan,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'CLEAR SETS // CLIMB THE LADDER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            7,
                            color: Cyber.muted,
                            letterSpacing: 0.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 54, color: Cyber.border),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$passed',
                          style:
                              Cyber.display(
                                27,
                                color: Cyber.cyan,
                                letterSpacing: 0.3,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '/ $total',
                          style: Cyber.label(
                            9,
                            color: Cyber.muted,
                            letterSpacing: 0.4,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'SETS CLEARED',
                          textAlign: TextAlign.right,
                          style: Cyber.label(
                            6,
                            color: Cyber.muted,
                            letterSpacing: 0.65,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'TOTAL MASTERY',
                        style: Cyber.label(
                          7.5,
                          color: Cyber.muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$progressPercent%',
                        style: Cyber.label(
                          8.5,
                          color: Cyber.cyan,
                          letterSpacing: 0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _ArenaProgressTrack(value: progressValue),
                ],
              ),
            ),
            Container(
              color: Cyber.panel2.withValues(alpha: 0.72),
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Row(
                children: [
                  const Icon(Icons.route_outlined, color: Cyber.cyan, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MISSION BRIEF',
                          style: Cyber.label(
                            7,
                            color: Cyber.cyan,
                            letterSpacing: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Clear sets to advance each category ladder.',
                          style: Cyber.body(10.5, color: Cyber.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ChamferedActionSurface(
                    clipper: const HudChamferClipper(bigCut: 8, smallCut: 3),
                    borderColor: Cyber.cyan.withValues(alpha: 0.42),
                    child: Container(
                      width: 58,
                      height: 38,
                      color: Cyber.bg.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '10',
                            style:
                                Cyber.display(
                                  14,
                                  color: Cyber.cyan,
                                  letterSpacing: 0.3,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Q / RUN',
                            style: Cyber.label(
                              5.8,
                              color: Cyber.muted,
                              letterSpacing: 0.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaProgressTrack extends StatelessWidget {
  const _ArenaProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: CyberProgressBar(
                  value: value,
                  accent: Cyber.cyan,
                  height: 8,
                ),
              ),
              for (final checkpoint in const [0.25, 0.5, 0.75])
                Positioned(
                  left: constraints.maxWidth * checkpoint - 0.5,
                  top: 1,
                  bottom: 1,
                  child: Container(
                    width: 1,
                    color: Cyber.bg.withValues(alpha: 0.82),
                  ),
                ),
            ],
          ),
        );
      },
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

  int get _nextSet {
    for (var set = 1; set <= kQuizSetCount; set++) {
      if (progress.isSetUnlocked(set) && !progress.setProgress(set).passed) {
        return set;
      }
    }
    return kQuizSetCount;
  }

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    final complete = progress.passedCount == kQuizSetCount;
    return Semantics(
      button: true,
      label:
          '${mode.label} category, ${progress.passedCount} of $kQuizSetCount sets cleared, ${complete ? 'complete' : 'next set $_nextSet'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                ),
                child: Icon(mode.icon, color: accent, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mode.label,
                            style: Cyber.display(17, letterSpacing: 1.2),
                          ),
                        ),
                        Text(
                          '+${mode.reward} XP / CORRECT',
                          style: Cyber.label(8, color: Cyber.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${mode.blurb} · ${complete ? 'LADDER COMPLETE' : 'NEXT SET $_nextSet'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        8,
                        color: complete ? Cyber.success : Cyber.muted,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CyberProgressBar(
                            value: progress.passedCount / kQuizSetCount,
                            accent: accent,
                            height: 6,
                            animate: false,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${progress.passedCount}/$kQuizSetCount',
                          style: Cyber.display(11, color: accent),
                        ),
                      ],
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
}

class _CoinBalance extends StatelessWidget {
  const _CoinBalance();

  @override
  Widget build(BuildContext context) {
    final coins = context.select<GameBloc, int>((bloc) => bloc.state.coins);
    return Semantics(
      label: '$coins coins available',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Cyber.gold.withValues(alpha: 0.08),
          border: Border.all(color: Cyber.gold.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll, color: Cyber.gold, size: 16),
            const SizedBox(width: 5),
            Text('$coins', style: Cyber.display(11, color: Cyber.gold)),
          ],
        ),
      ),
    );
  }
}

class _NextChallengeCard extends StatelessWidget {
  const _NextChallengeCard({
    required this.mode,
    required this.setNumber,
    required this.progress,
    required this.ladderComplete,
    required this.launching,
    required this.onTap,
  });

  final QuizMode mode;
  final int setNumber;
  final QuizSetProgress progress;
  final bool ladderComplete;
  final bool launching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ladderComplete ? Cyber.success : mode.accent;
    final retry = progress.hasRun && !progress.passed;
    return CyberPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ladderComplete ? Icons.workspace_premium : mode.icon,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  ladderComplete ? 'LADDER COMPLETE' : 'NEXT CHALLENGE',
                  style: Cyber.label(10, color: accent, letterSpacing: 1.6),
                ),
              ),
              CyberChip(
                label: ladderComplete ? 'CLEARED' : 'SET $setNumber',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            ladderComplete
                ? '${mode.label} KNOWLEDGE MASTERED'
                : '${mode.label} · SET $setNumber',
            style: Cyber.display(20, letterSpacing: 1.1),
          ),
          const SizedBox(height: 7),
          Text(
            ladderComplete
                ? 'Replay any cleared set to improve your best score.'
                : retry
                ? 'Best ${progress.bestCorrect}/$kQuizQuestionsPerSet · Ready for another attempt.'
                : '10 questions · Pass with at least 5 correct.',
            style: Cyber.body(12, color: Cyber.muted),
          ),
          const SizedBox(height: 16),
          HudCtaButton(
            key: const ValueKey('quiz-next-challenge-button'),
            label: launching
                ? 'OPENING...'
                : ladderComplete
                ? 'REPLAY SET $setNumber'
                : retry
                ? 'RETRY SET $setNumber'
                : 'PLAY SET $setNumber',
            helper: '$kQuizEntryCost COINS · +${mode.reward} XP PER CORRECT',
            accent: accent,
            height: 64,
            enabled: !launching,
            onTap: launching ? null : onTap,
          ),
        ],
      ),
    );
  }
}

class _ChapterSelector extends StatelessWidget {
  const _ChapterSelector({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final int selected;
  final Color accent;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var chapter = 0; chapter < 5; chapter++) ...[
          if (chapter > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == chapter,
              label: 'Sets ${chapter * 10 + 1} through ${chapter * 10 + 10}',
              child: GestureDetector(
                key: ValueKey('quiz-chapter-$chapter'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(chapter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == chapter
                        ? accent.withValues(alpha: 0.16)
                        : Cyber.panel2,
                    border: Border.all(
                      color: selected == chapter ? accent : Cyber.border,
                    ),
                  ),
                  child: Text(
                    '${(chapter * 10 + 1).toString().padLeft(2, '0')}–${chapter * 10 + 10}',
                    style: Cyber.label(
                      8.5,
                      color: selected == chapter ? accent : Cyber.muted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    super.key,
    required this.mode,
    required this.setNumber,
    required this.progress,
    required this.visualState,
    required this.launching,
    required this.onTap,
  });

  final QuizMode mode;
  final int setNumber;
  final QuizSetProgress progress;
  final QuizSetVisualState visualState;
  final bool launching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = visualState != QuizSetVisualState.locked && !launching;
    final color = switch (visualState) {
      QuizSetVisualState.cleared => Cyber.success,
      QuizSetVisualState.retry => Cyber.amber,
      QuizSetVisualState.available => mode.accent,
      QuizSetVisualState.locked => Cyber.muted,
    };
    final icon = switch (visualState) {
      QuizSetVisualState.cleared => Icons.check_circle,
      QuizSetVisualState.retry => Icons.replay_circle_filled,
      QuizSetVisualState.available => Icons.play_circle_fill,
      QuizSetVisualState.locked => Icons.lock,
    };
    final status = switch (visualState) {
      QuizSetVisualState.cleared => 'CLEARED',
      QuizSetVisualState.retry => 'RETRY',
      QuizSetVisualState.available => 'PLAY',
      QuizSetVisualState.locked => 'CLEAR ${setNumber - 1}',
    };

    return Semantics(
      button: enabled,
      enabled: enabled,
      label:
          'Set $setNumber, ${visualState.name}${progress.hasRun ? ', best ${progress.bestCorrect} of $kQuizQuestionsPerSet' : ''}',
      child: Opacity(
        opacity: enabled || visualState == QuizSetVisualState.cleared ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Color.lerp(Cyber.panel2, color, 0.07),
              border: Border.all(color: color.withValues(alpha: 0.62)),
              boxShadow: launching
                  ? Cyber.glow(color, alpha: 0.22, blur: 12)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 6),
                Text(
                  setNumber.toString().padLeft(2, '0'),
                  style: Cyber.display(15, color: color),
                ),
                const SizedBox(height: 5),
                Text(
                  launching ? 'OPENING' : status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Cyber.label(6.5, color: color, letterSpacing: 0.35),
                ),
                if (progress.hasRun) ...[
                  const SizedBox(height: 4),
                  Text(
                    'BEST ${progress.bestCorrect}/$kQuizQuestionsPerSet',
                    maxLines: 1,
                    style: Cyber.label(5.8, color: Cyber.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LadderRule extends StatelessWidget {
  const _LadderRule({required this.mode});

  final QuizMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel2.withValues(alpha: 0.88),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: mode.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clear a set with 5 or more correct answers to unlock the next one.',
              style: Cyber.body(11.5, color: Cyber.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryBriefing extends StatelessWidget {
  const _EntryBriefing({
    required this.sport,
    required this.mode,
    required this.setNumber,
    required this.coins,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= kQuizEntryCost;
    final missing = (kQuizEntryCost - coins).clamp(0, kQuizEntryCost);
    return Container(
      decoration: BoxDecoration(
        color: Cyber.bg,
        border: Border(top: BorderSide(color: mode.accent, width: 2)),
      ),
      child: CyberPlainBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ENTRY BRIEFING',
                            style: Cyber.display(17, letterSpacing: 1.6),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close entry briefing',
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close, color: Cyber.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CyberPanel(
                      accent: mode.accent,
                      glow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(mode.icon, color: mode.accent, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${mode.label} · SET $setNumber',
                                      style: Cyber.display(18),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${sport.name.toUpperCase()} · ${mode.blurb}',
                                      style: Cyber.label(
                                        8.5,
                                        color: Cyber.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _BriefingStat(
                            icon: Icons.help_outline,
                            label: 'QUESTIONS',
                            value: '$kQuizQuestionsPerSet',
                            accent: mode.accent,
                          ),
                          const SizedBox(height: 9),
                          _BriefingStat(
                            icon: Icons.verified_outlined,
                            label: 'PASS SCORE',
                            value: '5 / $kQuizQuestionsPerSet',
                            accent: Cyber.success,
                          ),
                          const SizedBox(height: 9),
                          _BriefingStat(
                            icon: Icons.bolt,
                            label: 'REWARD',
                            value: '+${mode.reward} XP / CORRECT',
                            accent: Cyber.gold,
                          ),
                          const SizedBox(height: 9),
                          _BriefingStat(
                            icon: Icons.toll,
                            label: 'ENTRY',
                            value: '$kQuizEntryCost COINS',
                            accent: Cyber.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canAfford
                            ? Cyber.panel2
                            : Cyber.danger.withValues(alpha: 0.08),
                        border: Border.all(
                          color: canAfford ? Cyber.border : Cyber.danger,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canAfford
                                ? Icons.account_balance_wallet
                                : Icons.error_outline,
                            color: canAfford ? Cyber.gold : Cyber.danger,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              canAfford
                                  ? 'BALANCE · $coins COINS'
                                  : 'NEED $missing MORE COINS',
                              style: Cyber.label(
                                10,
                                color: canAfford ? Colors.white : Cyber.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    HudCtaButton(
                      key: const ValueKey('quiz-confirm-entry'),
                      label: 'START SET',
                      helper: canAfford
                          ? '$kQuizEntryCost COINS WILL BE SPENT'
                          : 'NEED $missing MORE COINS',
                      accent: mode.accent,
                      enabled: canAfford,
                      onTap: canAfford
                          ? () => Navigator.of(context).pop(true)
                          : null,
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

class _BriefingStat extends StatelessWidget {
  const _BriefingStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
          ),
        ),
        Text(value, style: Cyber.label(10, color: accent)),
      ],
    );
  }
}

IconData _sportIcon(Sport sport) => switch (sport) {
  Sport.football => Icons.sports_soccer,
  Sport.cricket => Icons.sports_cricket,
  Sport.motorsport => Icons.sports_motorsports,
  Sport.basketball => Icons.sports_basketball,
  Sport.tennis => Icons.sports_tennis,
};
