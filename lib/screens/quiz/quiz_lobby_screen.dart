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
import '../../services/quiz_bank.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import 'quiz_play_screen.dart';

/// A set is [mastered] at a flawless 10/10, [cleared] once finished at any
/// score, [available] when open but unplayed, [locked] until the previous set
/// is finished, and [upcoming] when the question database doesn't reach it yet.
/// There is no fail state — the score only decides mastery stars.
enum QuizSetVisualState { mastered, cleared, available, locked, upcoming }

/// The five difficulty rungs of every mode. Band `k` owns sets `10(k-1)+1…10k`,
/// so the chapter selector doubles as the difficulty ladder.
const List<String> kQuizBandNames = [
  'FOUNDATION',
  'PROSPECT',
  'CONTENDER',
  'SPECIALIST',
  'LEGEND',
];

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
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: QuizMode.values.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.92,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, index) {
                          final mode = QuizMode.values[index];
                          return CyberDealtCard(
                            key: ValueKey('quiz-mode-${mode.name}'),
                            index: mode.index,
                            initialDelay: const Duration(milliseconds: 120),
                            child: _ModeTile(
                              sport: sport,
                              mode: mode,
                              progress: progress.forMode(mode),
                              onTap: () => _openSets(context, mode),
                            ),
                          );
                        },
                      ),
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
  bool _loadingBank = true;

  /// How many of the 50 sets the question database actually reaches. Anything
  /// past this renders as [QuizSetVisualState.upcoming] rather than falling back
  /// to filler questions.
  int _authoredSets = 0;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  Future<void> _loadBank() async {
    await QuizBank.ensureLoaded(widget.sport, widget.mode);
    if (!mounted) return;
    setState(() {
      _authoredSets = QuizBank.authoredSetCount(widget.sport, widget.mode);
      _loadingBank = false;
    });
  }

  bool _isPlayable(int setNumber) => setNumber <= _authoredSets;

  int _nextChallenge(QuizModeProgress progress) {
    for (var set = 1; set <= kQuizSetCount; set++) {
      if (!_isPlayable(set)) break;
      if (progress.isSetUnlocked(set) && !progress.setProgress(set).completed) {
        return set;
      }
    }
    return _authoredSets < 1 ? 1 : _authoredSets;
  }

  QuizSetVisualState _visualState(QuizModeProgress progress, int setNumber) {
    final set = progress.setProgress(setNumber);
    if (set.mastered) return QuizSetVisualState.mastered;
    if (set.completed) return QuizSetVisualState.cleared;
    if (!_isPlayable(setNumber)) return QuizSetVisualState.upcoming;
    if (!progress.isSetUnlocked(setNumber)) return QuizSetVisualState.locked;
    return QuizSetVisualState.available;
  }

  Future<void> _startSet(int setNumber) async {
    if (_launchingSet != null) return;
    if (!_isPlayable(setNumber)) return;
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

    playSound(SoundEffect.coinSpend);
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
          if (_loadingBank) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.textPrimary),
            );
          }

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
                        sport: widget.sport,
                        mode: mode,
                        setNumber: nextChallenge,
                        progress: progress.setProgress(nextChallenge),
                        ladderComplete:
                            _authoredSets > 0 &&
                            progress.completedCount >= _authoredSets,
                        awaitingContent: _authoredSets == 0,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: SectionLabel(label: 'SET CHAPTERS'),
                          ),
                          Text(
                            '${progress.completedCount}/$kQuizSetCount CLEARED',
                            style: Cyber.label(
                              9,
                              color: mode.accent,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Icon(
                            Icons.star_rounded,
                            color: Cyber.gold,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${progress.starCount}/${progress.maxStars}',
                            style:
                                Cyber.label(
                                  9,
                                  color: Cyber.gold,
                                  letterSpacing: 0.4,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ChapterSelector(
                        selected: selectedChapter,
                        accent: mode.accent,
                        authoredSets: _authoredSets,
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
      (sum, mode) => sum + progress.forMode(mode).completedCount,
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
    required this.sport,
    required this.mode,
    required this.progress,
    required this.onTap,
  });

  final Sport sport;
  final QuizMode mode;
  final QuizModeProgress progress;
  final VoidCallback onTap;

  int get _nextSet {
    for (var set = 1; set <= kQuizSetCount; set++) {
      if (progress.isSetUnlocked(set) && !progress.setProgress(set).completed) {
        return set;
      }
    }
    return kQuizSetCount;
  }

  @override
  Widget build(BuildContext context) {
    final accent = mode.accent;
    final complete = progress.completedCount == kQuizSetCount;
    return Semantics(
      button: true,
      label:
          '${mode.label} category, ${progress.completedCount} of $kQuizSetCount sets cleared, ${progress.starCount} stars, ${complete ? 'complete' : 'next set $_nextSet'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      border: Border.all(color: accent.withValues(alpha: 0.42)),
                    ),
                    child: Icon(mode.iconFor(sport), color: accent, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '+${mode.reward} XP / CORRECT',
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7,
                        color: Cyber.gold,
                        letterSpacing: 0.4,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(15, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                mode.blurbFor(sport),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.65),
              ),
              const SizedBox(height: 3),
              Text(
                complete ? 'LADDER COMPLETE' : 'NEXT SET $_nextSet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  7.5,
                  color: complete ? Cyber.success : accent.withValues(alpha: 0.9),
                  letterSpacing: 0.7,
                ),
              ),
              const Spacer(),
              CyberProgressBar(
                value: progress.completedCount / kQuizSetCount,
                accent: accent,
                height: 6,
                animate: false,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Cyber.gold, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    '${progress.starCount}',
                    style: Cyber.label(8.5, color: Cyber.gold).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.completedCount}/$kQuizSetCount',
                    style: Cyber.display(11, color: accent).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
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
    required this.sport,
    required this.mode,
    required this.setNumber,
    required this.progress,
    required this.ladderComplete,
    required this.awaitingContent,
  });

  final Sport sport;
  final QuizMode mode;
  final int setNumber;
  final QuizSetProgress progress;
  final bool ladderComplete;

  /// No sets are authored for this mode yet — say so plainly instead of
  /// pointing the player at a set they cannot open.
  final bool awaitingContent;

  @override
  Widget build(BuildContext context) {
    final accent = awaitingContent
        ? Cyber.muted
        : ladderComplete
        ? Cyber.success
        : mode.accent;
    final replay = progress.hasRun && !progress.mastered;
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                awaitingContent
                    ? Icons.hourglass_empty
                    : ladderComplete
                    ? Icons.workspace_premium
                    : mode.iconFor(sport),
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  awaitingContent
                      ? 'IN DEVELOPMENT'
                      : ladderComplete
                      ? 'LADDER COMPLETE'
                      : 'NEXT CHALLENGE',
                  style: Cyber.label(10, color: accent, letterSpacing: 1.6),
                ),
              ),
              CyberChip(
                label: awaitingContent
                    ? 'SOON'
                    : ladderComplete
                    ? 'CLEARED'
                    : 'SET $setNumber',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            awaitingContent
                ? '${mode.label} LADDER LOADING'
                : ladderComplete
                ? '${mode.label} KNOWLEDGE MASTERED'
                : '${mode.label} · SET $setNumber',
            style: Cyber.display(20, letterSpacing: 1.1),
          ),
          const SizedBox(height: 7),
          Text(
            awaitingContent
                ? 'This ladder is still being written. Try another mode or sport.'
                : ladderComplete
                ? 'Replay any set to chase a flawless 3-star run.'
                : replay
                ? 'Best ${progress.bestCorrect}/$kQuizQuestionsPerSet · ${progress.stars}/3 stars · replay for a perfect run.'
                : '10 questions · instant verdict after every answer.',
            style: Cyber.body(12, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

/// The five difficulty bands of a mode, one tab each. Band `k` covers sets
/// `10(k-1)+1…10k` and gets harder as you climb, so the rung name carries the
/// real information and the set range is the fine print.
class _ChapterSelector extends StatelessWidget {
  const _ChapterSelector({
    required this.selected,
    required this.accent,
    required this.authoredSets,
    required this.onSelected,
  });

  final int selected;
  final Color accent;
  final int authoredSets;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // No `stretch` here: this Row sits inside a vertical ListView, so stretching
    // asks for infinite height and blanks the grid. The fixed-height tabs
    // define the row.
    return Row(
      children: [
        for (var chapter = 0; chapter < kQuizBandNames.length; chapter++) ...[
          if (chapter > 0) const SizedBox(width: 6),
          Expanded(
            child: _ChapterTab(
              chapter: chapter,
              selected: selected == chapter,
              // A band nobody can reach yet stays legible but reads as inert.
              authored: chapter * 10 < authoredSets,
              accent: accent,
              onTap: () => onSelected(chapter),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChapterTab extends StatelessWidget {
  const _ChapterTab({
    required this.chapter,
    required this.selected,
    required this.authored,
    required this.accent,
    required this.onTap,
  });

  final int chapter;
  final bool selected;
  final bool authored;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstSet = chapter * 10 + 1;
    final ink = selected
        ? accent
        : authored
        ? Cyber.muted
        : Cyber.muted.withValues(alpha: 0.55);

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${kQuizBandNames[chapter]}, sets $firstSet through ${firstSet + 9}',
      child: GestureDetector(
        key: ValueKey('quiz-chapter-$chapter'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : Cyber.panel2,
            border: Border.all(color: selected ? accent : Cyber.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Difficulty rung — the reason to care which chapter you're on.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  kQuizBandNames[chapter],
                  maxLines: 1,
                  style: Cyber.label(7.5, color: ink, letterSpacing: 0.3),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${firstSet.toString().padLeft(2, '0')}–${firstSet + 9}',
                style:
                    Cyber.label(
                      8.5,
                      color: selected
                          ? accent
                          : ink.withValues(alpha: authored ? 0.75 : 0.45),
                      letterSpacing: 0.4,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
      ),
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
    final enabled =
        visualState != QuizSetVisualState.locked &&
        visualState != QuizSetVisualState.upcoming &&
        !launching;
    final graded = visualState == QuizSetVisualState.mastered ||
        visualState == QuizSetVisualState.cleared;
    final color = switch (visualState) {
      QuizSetVisualState.mastered => Cyber.gold,
      QuizSetVisualState.cleared => Cyber.success,
      QuizSetVisualState.available => mode.accent,
      QuizSetVisualState.locked || QuizSetVisualState.upcoming => Cyber.muted,
    };
    final icon = switch (visualState) {
      QuizSetVisualState.mastered => Icons.workspace_premium,
      QuizSetVisualState.cleared => Icons.replay_circle_filled,
      QuizSetVisualState.available => Icons.play_circle_fill,
      QuizSetVisualState.locked => Icons.lock,
      QuizSetVisualState.upcoming => Icons.hourglass_empty,
    };
    final status = switch (visualState) {
      QuizSetVisualState.mastered => 'PERFECT',
      QuizSetVisualState.cleared => 'REPLAY',
      QuizSetVisualState.available => 'PLAY',
      QuizSetVisualState.locked => 'FINISH ${setNumber - 1}',
      QuizSetVisualState.upcoming => 'SOON',
    };

    return Semantics(
      button: enabled,
      enabled: enabled,
      label:
          'Set $setNumber, ${visualState.name}${progress.hasRun ? ', best ${progress.bestCorrect} of $kQuizQuestionsPerSet, ${progress.stars} of 3 stars' : ''}',
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Color.lerp(Cyber.panel2, color, 0.07),
              border: Border.all(color: color.withValues(alpha: 0.62)),
              // Glow rule: only the tile being opened is "live".
              boxShadow: launching
                  ? Cyber.glow(color, alpha: 0.22, blur: 12)
                  : null,
            ),
            // Four stacked rows in a 5-column grid cell is tight; scaleDown
            // keeps the stars + best-score line legible at large text scales
            // instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(height: 5),
                  Text(
                    setNumber.toString().padLeft(2, '0'),
                    style: Cyber.display(15, color: color),
                  ),
                  const SizedBox(height: 4),
                  if (graded)
                    CyberStarRating(earned: progress.stars, size: 11)
                  else
                    Text(
                      launching ? 'OPENING' : status,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: Cyber.label(6.5, color: color, letterSpacing: 0.35),
                    ),
                  if (graded || visualState == QuizSetVisualState.available) ...[
                    const SizedBox(height: 4),
                    Text(
                      graded
                          ? (launching
                                ? 'OPENING'
                                : '$status · ${progress.bestCorrect}/$kQuizQuestionsPerSet')
                          : '+${mode.reward} XP EACH',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: Cyber.label(
                        5.8,
                        color: graded
                            ? Cyber.muted
                            : color.withValues(alpha: 0.8),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
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
              'Finish all $kQuizQuestionsPerSet questions to unlock the next set — any score clears it. '
              'Score $kQuizQuestionsPerSet/$kQuizQuestionsPerSet for 3 stars.',
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
                              Icon(
                                mode.iconFor(sport),
                                color: mode.accent,
                                size: 26,
                              ),
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
                                      '${sport.name.toUpperCase()} · ${mode.blurbFor(sport)}',
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
                            icon: Icons.star_rounded,
                            label: '3-STAR SCORE',
                            value:
                                '$kQuizQuestionsPerSet / $kQuizQuestionsPerSet',
                            accent: Cyber.gold,
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
