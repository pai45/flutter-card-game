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
import '../../widgets/team_logo.dart';
import 'match_prediction_screen.dart';

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
                    _HistoryHeader(
                      title: 'MY MATCHES HISTORY',
                      accent: Cyber.violet,
                      onBack: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _HistoryStatsRow(
                        accent: Cyber.violet,
                        fills: const [
                          Color(0xff4d2b7a),
                          Color(0xff342f63),
                          Color(0xff243557),
                        ],
                        firstLabel: 'MATCHES',
                        firstValue: '${state.predictionsMade}',
                        accuracy: accuracy,
                        rank: 122,
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
                          ? _EmptyHistory(hasAnyQuizzes: items.isNotEmpty)
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
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

class _MatchQuizCard extends StatelessWidget {
  const _MatchQuizCard({required this.item, required this.onDetails});

  final _MatchHistoryItem item;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final palette = _matchPalette(item.status);
    final match = item.match;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDetails,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xff10192d),
          border: Border.all(color: Cyber.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _TeamScoreRow(
                          team: match.home,
                          score: match.homeScore,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.entry.league?.shortCode ??
                            match.leagueId.toUpperCase(),
                        style: Cyber.label(
                          10,
                          color: Cyber.muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TeamScoreRow(
                          team: match.away,
                          score: match.awayScore,
                        ),
                      ),
                      _ScheduleLabel(item: item),
                    ],
                  ),
                ],
              ),
            ),
            if (item.status != _MatchQuizStatus.pending &&
                item.status != _MatchQuizStatus.live)
              _StatusStrip(label: palette.label, color: palette.color),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Metric(
                    label: 'QUIZ',
                    value: '${item.answered}/${item.total}',
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _Metric(
                      label: 'POTENTIAL XP',
                      value: '${item.potentialXp} XP',
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Metric(
                    label: 'STATUS',
                    value: palette.value(item),
                    alignEnd: true,
                    valueColor: palette.color,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Text(
                    formatPredictionTimestamp(item.prediction.submittedAt),
                    style: Cyber.body(10, color: Cyber.muted),
                  ),
                  const Spacer(),
                  _OutcomeDots(
                    outcomes: questionOutcomes(item.quiz, item.prediction),
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

class _ScheduleLabel extends StatelessWidget {
  const _ScheduleLabel({required this.item});

  final _MatchHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final text = switch (item.status) {
      _MatchQuizStatus.pending => formatKickoffSchedule(item.match.kickoff),
      _MatchQuizStatus.live =>
        item.match.liveMinute == null ? 'Live' : "${item.match.liveMinute}'",
      _ => item.match.resultLine ?? 'Full time',
    };
    final color = switch (item.status) {
      _MatchQuizStatus.pending => Cyber.gold,
      _MatchQuizStatus.live => Cyber.red,
      _MatchQuizStatus.unresolved => Cyber.amber,
      _MatchQuizStatus.won => Cyber.success,
      _MatchQuizStatus.lost => Cyber.red,
    };
    return Text(
      text,
      textAlign: TextAlign.right,
      style: Cyber.body(11, color: color, weight: FontWeight.w800),
    );
  }
}

class _MatchPalette {
  const _MatchPalette({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final String Function(_MatchHistoryItem item) value;
}

_MatchPalette _matchPalette(_MatchQuizStatus status) {
  return switch (status) {
    _MatchQuizStatus.pending => const _MatchPalette(
      label: 'PENDING',
      color: Cyber.gold,
      value: _pendingValue,
    ),
    _MatchQuizStatus.live => const _MatchPalette(
      label: 'LIVE',
      color: Cyber.red,
      value: _liveValue,
    ),
    _MatchQuizStatus.unresolved => const _MatchPalette(
      label: 'UNRESOLVED',
      color: Cyber.amber,
      value: _reviewValue,
    ),
    _MatchQuizStatus.won => const _MatchPalette(
      label: 'WON',
      color: Cyber.success,
      value: _wonValue,
    ),
    _MatchQuizStatus.lost => const _MatchPalette(
      label: 'LOST',
      color: Cyber.red,
      value: _lostValue,
    ),
  };
}

String _pendingValue(_MatchHistoryItem item) => 'Pending';
String _liveValue(_MatchHistoryItem item) => 'Locked';
String _reviewValue(_MatchHistoryItem item) => 'Review';
String _wonValue(_MatchHistoryItem item) =>
    '+${item.prediction.rewardEarned} XP';
String _lostValue(_MatchHistoryItem item) => '${item.correct}/${item.total}';

class _MatchFilterBar extends StatelessWidget {
  const _MatchFilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final _MatchFilter active;
  final Map<_MatchFilter, int> counts;
  final ValueChanged<_MatchFilter> onSelect;

  String _label(_MatchFilter filter) => switch (filter) {
    _MatchFilter.all => 'ALL',
    _MatchFilter.won => 'WON',
    _MatchFilter.lost => 'LOST',
    _MatchFilter.live => 'LIVE',
    _MatchFilter.pending => 'PENDING',
    _MatchFilter.unresolved => 'UNRESOLVED',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final filter in _MatchFilter.values) ...[
            _FilterChip(
              label: '${_label(filter)} (${counts[filter] ?? 0})',
              active: active == filter,
              activeColor: Cyber.violet,
              onTap: () => onSelect(filter),
            ),
            if (filter != _MatchFilter.unresolved) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.title,
    required this.accent,
    required this.onBack,
  });

  final String title;
  final Color accent;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(19, color: accent, letterSpacing: 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStatsRow extends StatelessWidget {
  const _HistoryStatsRow({
    required this.accent,
    required this.fills,
    required this.firstLabel,
    required this.firstValue,
    required this.accuracy,
    required this.rank,
  });

  final Color accent;
  final List<Color> fills;
  final String firstLabel;
  final String firstValue;
  final int accuracy;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NotchedStatCard(
            label: firstLabel,
            value: firstValue,
            fill: fills[0],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NotchedStatCard(
            label: 'ACCURACY',
            value: '$accuracy%',
            fill: fills[1],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NotchedStatCard(
            label: 'CURRENT RANK',
            value: '$rank',
            fill: fills[2],
          ),
        ),
      ],
    );
  }
}

class _NotchedStatCard extends StatelessWidget {
  const _NotchedStatCard({
    required this.label,
    required this.value,
    required this.fill,
  });

  final String label;
  final String value;
  final Color fill;

  static const _notchW = 9.0;
  static const _notchH = 7.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotchedStatBorderPainter(fill: fill),
      child: ClipPath(
        clipper: const _NotchedStatClipper(notchW: _notchW, notchH: _notchH),
        child: Container(
          height: 78,
          alignment: Alignment.center,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  9,
                  color: Colors.white.withValues(alpha: 0.72),
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Cyber.display(22, letterSpacing: 0).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _NotchedStatClipper extends CustomClipper<Path> {
  const _NotchedStatClipper({required this.notchW, required this.notchH});

  final double notchW;
  final double notchH;

  @override
  Path getClip(Size size) => _notchedRect(size, notchW, notchH);

  @override
  bool shouldReclip(covariant _NotchedStatClipper old) =>
      old.notchW != notchW || old.notchH != notchH;
}

Path _notchedRect(Size size, double notchW, double notchH) {
  final w = size.width;
  final h = size.height;
  final cx = w / 2;
  return Path()
    ..moveTo(0, 0)
    ..lineTo(cx - notchW, 0)
    ..lineTo(cx, notchH)
    ..lineTo(cx + notchW, 0)
    ..lineTo(w, 0)
    ..lineTo(w, h)
    ..lineTo(cx + notchW, h)
    ..lineTo(cx, h - notchH)
    ..lineTo(cx - notchW, h)
    ..lineTo(0, h)
    ..close();
}

class _NotchedStatBorderPainter extends CustomPainter {
  const _NotchedStatBorderPainter({required this.fill});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedRect(
      size,
      _NotchedStatCard._notchW,
      _NotchedStatCard._notchH,
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Cyber.border,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedStatBorderPainter old) =>
      old.fill != fill;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.14) : Cyber.panel2,
          border: Border.all(color: active ? activeColor : Cyber.border),
        ),
        child: Text(
          label,
          style: Cyber.label(
            10,
            color: active ? activeColor : Cyber.muted,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({required this.team, required this.score});

  final SportTeam team;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamLogo(team: team, width: 28, height: 28),
        const SizedBox(width: 9),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: team.name),
                if (score != null) TextSpan(text: '  $score'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              13,
              weight: FontWeight.w800,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.22),
      child: Text(
        label,
        style: Cyber.label(10, color: color, letterSpacing: 0.7),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool alignEnd;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.label(8, color: Cyber.muted)),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: Cyber.body(
            12,
            color: valueColor ?? Colors.white,
            weight: FontWeight.w900,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

class _OutcomeDots extends StatelessWidget {
  const _OutcomeDots({required this.outcomes});

  final List<QuestionOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final outcome in outcomes) ...[
          _OutcomeDot(outcome: outcome),
          const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _OutcomeDot extends StatelessWidget {
  const _OutcomeDot({required this.outcome});

  final QuestionOutcome outcome;

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
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, size: 11, color: color),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasAnyQuizzes});

  final bool hasAnyQuizzes;

  @override
  Widget build(BuildContext context) {
    return CyberNoDataState(
      icon: hasAnyQuizzes ? Icons.filter_alt_off : Icons.sports_esports,
      title: hasAnyQuizzes ? 'No quizzes in this filter' : 'Be the 1st to play',
      message: hasAnyQuizzes
          ? 'Switch filters to review the quizzes already played.'
          : 'No one has played a prediction quiz yet. Start one and claim the first rank.',
      accent: hasAnyQuizzes ? Cyber.violet : Cyber.cyan,
      spark: hasAnyQuizzes ? Icons.tune : Icons.bolt,
    );
  }
}
