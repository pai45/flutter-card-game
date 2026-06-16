import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../utils/prediction_helpers.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/fixture_card.dart';
import '../../widgets/team_logo.dart';
import 'match_prediction_screen.dart';
import 'widgets/history_hud.dart';

void showPredictionMatchHistory(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PredictionMatchHistoryScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PredictionMatchHistoryScreen extends StatefulWidget {
  const PredictionMatchHistoryScreen({super.key});

  @override
  State<PredictionMatchHistoryScreen> createState() =>
      _PredictionMatchHistoryScreenState();
}

class _PredictionMatchHistoryScreenState
    extends State<PredictionMatchHistoryScreen> {
  _MatchFilter _filter = _MatchFilter.all;
  Map<String, PredictionQuiz?> _quizzes = {};
  bool _loadingQuizzes = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    final cubit = context.read<PredictionCubit>();
    final loaded = <String, PredictionQuiz?>{};
    for (final id in cubit.state.predictions.keys) {
      loaded[id] = await cubit.quizFor(id);
    }
    if (!mounted) return;
    setState(() {
      _quizzes = loaded;
      _loadingQuizzes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: BlocBuilder<PredictionCubit, PredictionState>(
              builder: (context, state) {
                final entries = _buildEntries(state);
                final items = <_MatchHistoryItem>[
                  for (final entry in entries)
                    if (_quizzes[entry.match.id] != null)
                      _MatchHistoryItem(
                        entry: entry,
                        quiz: _quizzes[entry.match.id]!,
                      ),
                ];
                final counts = {
                  for (final filter in _MatchFilter.values)
                    filter: items.where((item) => item.matches(filter)).length,
                };
                final filtered = items
                    .where((item) => item.matches(_filter))
                    .toList();
                final totalAnswers = state.predictions.values.fold<int>(
                  0,
                  (sum, p) => sum + p.answers.length,
                );
                final accuracy = totalAnswers == 0
                    ? 0
                    : (state.correctPredictions / totalAnswers * 100).round();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryHeaderBar(
                      title: 'MY MATCHES HISTORY',
                      accent: Cyber.violet,
                      onBack: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: HistoryStatCell(
                              label: 'MATCHES',
                              value: '${state.predictionsMade}',
                              accent: Cyber.violet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HistoryStatCell(
                              label: 'ACCURACY',
                              value: '$accuracy%',
                              accent: Cyber.violet,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HistoryStatCell(
                              label: 'RANK',
                              value: '122',
                              accent: Cyber.violet,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MatchFilterBar(
                      active: _filter,
                      counts: counts,
                      onSelect: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _loadingQuizzes
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Cyber.cyan,
                                strokeWidth: 2,
                              ),
                            )
                          : filtered.isEmpty
                          ? _EmptyHistory(
                              hasAnyQuizzes: items.isNotEmpty,
                              filterLabel: _filterLabel(_filter),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _MatchQuizCard(
                                  item: item,
                                  onDetails: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MatchPredictionScreen(
                                        match: item.entry.match,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_HistoryEntry> _buildEntries(PredictionState state) {
    final entries = <_HistoryEntry>[];
    for (final prediction in state.predictions.values) {
      SportMatch? match;
      for (final fixture in state.fixtures) {
        if (fixture.id == prediction.matchId) {
          match = fixture;
          break;
        }
      }
      if (match == null) continue;
      entries.add(
        _HistoryEntry(
          match: match,
          league: state.leagueFor(match.leagueId),
          prediction: prediction,
        ),
      );
    }
    entries.sort(
      (a, b) => b.prediction.submittedAt.compareTo(a.prediction.submittedAt),
    );
    return entries;
  }
}

String _filterLabel(_MatchFilter filter) => switch (filter) {
  _MatchFilter.all => 'ALL',
  _MatchFilter.won => 'WON',
  _MatchFilter.lost => 'LOST',
  _MatchFilter.live => 'LIVE',
  _MatchFilter.pending => 'PENDING',
  _MatchFilter.unresolved => 'UNRESOLVED',
};

class _HistoryEntry {
  const _HistoryEntry({
    required this.match,
    required this.league,
    required this.prediction,
  });

  final SportMatch match;
  final League? league;
  final UserPrediction prediction;
}

enum _MatchFilter { all, won, lost, live, pending, unresolved }

enum _MatchQuizStatus { pending, live, unresolved, won, lost }

class _MatchHistoryItem {
  const _MatchHistoryItem({required this.entry, required this.quiz});

  final _HistoryEntry entry;
  final PredictionQuiz quiz;

  SportMatch get match => entry.match;
  UserPrediction get prediction => entry.prediction;

  _MatchQuizStatus get status {
    if (match.status == MatchStatus.live) return _MatchQuizStatus.live;
    if (prediction.status == PredictionStatus.settled) {
      return (prediction.correctCount ?? 0) > 0
          ? _MatchQuizStatus.won
          : _MatchQuizStatus.lost;
    }
    if (match.status == MatchStatus.finished || quiz.settleable) {
      return _MatchQuizStatus.unresolved;
    }
    return _MatchQuizStatus.pending;
  }

  int get answered => prediction.answers.length;
  int get total => quiz.questions.length;
  int get correct => prediction.correctCount ?? _previewCorrect;

  int get _previewCorrect {
    var count = 0;
    for (final question in quiz.questions) {
      if (questionOutcome(question, prediction) == QuestionOutcome.correct) {
        count++;
      }
    }
    return count;
  }

  int get potentialXp => quiz.maxReward;

  bool matches(_MatchFilter filter) {
    return switch (filter) {
      _MatchFilter.all => true,
      _MatchFilter.won => status == _MatchQuizStatus.won,
      _MatchFilter.lost => status == _MatchQuizStatus.lost,
      _MatchFilter.live => status == _MatchQuizStatus.live,
      _MatchFilter.pending => status == _MatchQuizStatus.pending,
      _MatchFilter.unresolved => status == _MatchQuizStatus.unresolved,
    };
  }
}

/// Match quiz card on the shared fixture silhouette: status tag in the notch,
/// league kicker + the mirrored teams/centre-score row, and a state-specific
/// bottom strip.
class _MatchQuizCard extends StatelessWidget {
  const _MatchQuizCard({required this.item, required this.onDetails});

  final _MatchHistoryItem item;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return FixtureCardFrame(
      onTap: onDetails,
      tag: _MatchTag(item: item),
      body: _MatchCardBody(item: item),
      bottomStrip: _MatchHistoryStrip(item: item),
    );
  }
}

class _MatchTag extends StatelessWidget {
  const _MatchTag({required this.item});

  final _MatchHistoryItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case _MatchQuizStatus.pending:
        return FixtureTagText(
          text: _kickoffTag(item.match.kickoff),
          color: kFixtureTimeGold,
        );
      case _MatchQuizStatus.live:
        final minute = item.match.liveMinute;
        return FixtureLiveTag(label: minute != null ? "LIVE $minute'" : 'LIVE');
      case _MatchQuizStatus.won:
        return const FixtureTagText(text: 'WON', color: Cyber.success);
      case _MatchQuizStatus.lost:
        return const FixtureTagText(text: 'LOST', color: Cyber.red);
      case _MatchQuizStatus.unresolved:
        return const FixtureTagText(text: 'REVIEW', color: Cyber.amber);
    }
  }
}

/// Same-day kickoffs show the time (`19:30`); otherwise the date (`14 JUN`).
String _kickoffTag(DateTime kickoff) {
  final local = kickoff.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${local.day} ${months[local.month - 1]}';
}

class _MatchCardBody extends StatelessWidget {
  const _MatchCardBody({required this.item});

  final _MatchHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final match = item.match;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.entry.league?.shortCode ?? match.leagueId.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(
            8,
            color: Cyber.muted.withValues(alpha: 0.85),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        _TeamsRow(match: match),
      ],
    );
  }
}

/// Horizontal teams + centre-score layout, lifted from the match prediction
/// card so the history card reads the same: mirrored badges with the team name
/// beneath and the football score in the middle.
class _TeamsRow extends StatelessWidget {
  const _TeamsRow({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _TeamColumn(team: match.home, alignEnd: false)),
        _ScoreCentre(match: match),
        Expanded(child: _TeamColumn(team: match.away, alignEnd: true)),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team, required this.alignEnd});

  final SportTeam team;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Mirror the badge chamfer toward the centre of the card.
        TeamLogo(team: team, width: 46, height: 46, cutBottomRight: !alignEnd),
        const SizedBox(height: 8),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.body(15, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ScoreCentre extends StatelessWidget {
  const _ScoreCentre({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.sport == Sport.football && match.hasScore) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '${match.homeScore ?? '-'}  -  ${match.awayScore ?? '-'}',
          style: Cyber.display(21, color: Colors.white, letterSpacing: 0.5)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
    }
    // Upcoming, or cricket (innings live under each name) → centre dash.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '-',
        style: TextStyle(
          color: Cyber.muted,
          fontFamily: Cyber.displayFont,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _MatchHistoryStrip extends StatelessWidget {
  const _MatchHistoryStrip({required this.item});

  final _MatchHistoryItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case _MatchQuizStatus.pending:
        return FixtureCardStrip(
          child: Row(
            children: [
              Text(
                'QUIZ ${item.answered}/${item.total}',
                style: Cyber.label(
                  9,
                  color: Cyber.muted,
                  letterSpacing: 0.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                'POTENTIAL +${item.potentialXp} XP',
                style: Cyber.label(
                  9,
                  color: Cyber.cyan.withValues(alpha: 0.85),
                  letterSpacing: 0.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      case _MatchQuizStatus.live:
        return FixtureCardStrip(
          child: Text(
            'LOCKED · ${item.answered}/${item.total} ANSWERS IN',
            style: Cyber.label(
              9,
              color: Cyber.muted,
              letterSpacing: 0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      case _MatchQuizStatus.won:
        return FixtureCardStrip(
          topBorder: Cyber.success.withValues(alpha: 0.25),
          child: Row(
            children: [
              const Icon(Icons.trending_up, color: Cyber.success, size: 13),
              const SizedBox(width: 6),
              Text(
                '+${item.prediction.rewardEarned} XP',
                style: Cyber.body(
                  12,
                  color: Cyber.success,
                  weight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _OutcomeDots(
                outcomes: questionOutcomes(item.quiz, item.prediction),
                compact: true,
              ),
            ],
          ),
        );
      case _MatchQuizStatus.lost:
        return FixtureCardStrip(
          topBorder: Cyber.red.withValues(alpha: 0.18),
          child: Row(
            children: [
              Text(
                '${item.correct}/${item.total} CORRECT',
                style: Cyber.label(
                  9,
                  color: Cyber.muted,
                  letterSpacing: 0.8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              _OutcomeDots(
                outcomes: questionOutcomes(item.quiz, item.prediction),
                compact: true,
              ),
            ],
          ),
        );
      case _MatchQuizStatus.unresolved:
        return FixtureCardStrip(
          fill: kFixtureStripGold,
          topBorder: Cyber.gold.withValues(alpha: 0.35),
          child: Row(
            children: [
              const Icon(Icons.redeem, color: Cyber.gold, size: 14),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'RESULTS READY — TAP TO REVEAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(
                    9,
                    color: Cyber.gold,
                    letterSpacing: 1,
                  ).copyWith(
                    shadows: [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _MatchFilterBar extends StatelessWidget {
  const _MatchFilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final _MatchFilter active;
  final Map<_MatchFilter, int> counts;
  final ValueChanged<_MatchFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final filter in _MatchFilter.values) ...[
            HistoryFilterChip(
              label: _filterLabel(filter),
              count: counts[filter] ?? 0,
              active: active == filter,
              accent: Cyber.violet,
              onTap: () => onSelect(filter),
            ),
            if (filter != _MatchFilter.unresolved) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _OutcomeDots extends StatelessWidget {
  const _OutcomeDots({required this.outcomes, this.compact = false});

  final List<QuestionOutcome> outcomes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 4.0 : 5.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < outcomes.length; i++) ...[
          _OutcomeDot(outcome: outcomes[i], compact: compact),
          if (i != outcomes.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

class _OutcomeDot extends StatelessWidget {
  const _OutcomeDot({required this.outcome, required this.compact});

  final QuestionOutcome outcome;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (outcome) {
      QuestionOutcome.correct => Cyber.success,
      QuestionOutcome.wrong => Cyber.red,
      QuestionOutcome.pending => Cyber.muted,
    };
    final icon = switch (outcome) {
      QuestionOutcome.correct => Icons.check,
      QuestionOutcome.wrong => Icons.close,
      QuestionOutcome.pending => Icons.more_horiz,
    };
    final box = compact ? 13.0 : 17.0;
    final iconSize = compact ? 9.0 : 11.0;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.hasAnyQuizzes,
    required this.filterLabel,
  });

  final bool hasAnyQuizzes;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    return CyberNoDataState(
      icon: hasAnyQuizzes ? Icons.filter_alt_off : Icons.sports_esports,
      title: hasAnyQuizzes ? 'No $filterLabel entries' : 'Be the 1st to play',
      message: hasAnyQuizzes
          ? 'Switch filters to review the quizzes already played.'
          : 'No one has played a prediction quiz yet. Start one and claim the first rank.',
      accent: hasAnyQuizzes ? Cyber.violet : Cyber.cyan,
      spark: hasAnyQuizzes ? Icons.tune : Icons.bolt,
    );
  }
}
