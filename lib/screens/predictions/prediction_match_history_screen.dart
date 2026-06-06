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
import '../shop/shop_screen.dart' show CoinIcon;
import 'match_prediction_screen.dart';

void showPredictionMatchHistory(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const PredictionMatchHistoryScreen(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Archive of every prediction the user has submitted — grouped by lifecycle
/// (pending · live · settled) with per-question ✓ / ✕ / ? glyphs.
class PredictionMatchHistoryScreen extends StatefulWidget {
  const PredictionMatchHistoryScreen({super.key});

  @override
  State<PredictionMatchHistoryScreen> createState() =>
      _PredictionMatchHistoryScreenState();
}

class _PredictionMatchHistoryScreenState
    extends State<PredictionMatchHistoryScreen> {
  PredictionHistoryFilter _filter = PredictionHistoryFilter.all;
  Map<String, PredictionQuiz?> _quizzes = {};
  bool _loadingQuizzes = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    final cubit = context.read<PredictionCubit>();
    final ids = cubit.state.predictions.keys.toList();
    final loaded = <String, PredictionQuiz?>{};
    for (final id in ids) {
      loaded[id] = await cubit.quizFor(id);
    }
    if (mounted) {
      setState(() {
        _quizzes = loaded;
        _loadingQuizzes = false;
      });
    }
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
                final counts = _countBuckets(entries);

                final totalPicks = state.predictions.values.fold<int>(
                  0,
                  (sum, p) => sum + p.answers.length,
                );
                final correct = state.correctPredictions;
                final accuracy = totalPicks == 0
                    ? 0
                    : (correct / totalPicks * 100).round();

                final filtered = entries
                    .where(
                      (e) => matchesHistoryFilter(
                        e.match,
                        e.prediction,
                        _filter,
                      ),
                    )
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HistoryHeader(onBack: () => Navigator.pop(context)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _HistoryStatsRow(
                        matches: state.predictionsMade,
                        accuracy: accuracy,
                        predictions: totalPicks,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterBar(
                      active: _filter,
                      counts: counts,
                      onSelect: (f) => setState(() => _filter = f),
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
                          ? const _EmptyHistory()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final entry = filtered[index];
                                final quiz = _quizzes[entry.match.id];
                                if (quiz == null) return const SizedBox.shrink();
                                return _HistoryMatchCard(
                                  match: entry.match,
                                  league: entry.league,
                                  prediction: entry.prediction,
                                  quiz: quiz,
                                  onDetails: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MatchPredictionScreen(
                                        match: entry.match,
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

  Map<PredictionHistoryFilter, int> _countBuckets(List<_HistoryEntry> entries) {
    var live = 0;
    var pending = 0;
    var out = 0;
    for (final e in entries) {
      switch (historyBucket(e.match, e.prediction)) {
        case PredictionHistoryBucket.live:
          live++;
        case PredictionHistoryBucket.pending:
          pending++;
        case PredictionHistoryBucket.out:
          out++;
      }
    }
    return {
      PredictionHistoryFilter.all: entries.length,
      PredictionHistoryFilter.live: live,
      PredictionHistoryFilter.pending: pending,
      PredictionHistoryFilter.out: out,
    };
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

// ─── Header ──────────────────────────────────────────────────────────────────

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Text(
            'MY MATCHES',
            style: Cyber.display(20, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ───────────────────────────────────────────────────────────────

class _HistoryStatsRow extends StatelessWidget {
  const _HistoryStatsRow({
    required this.matches,
    required this.accuracy,
    required this.predictions,
  });

  final int matches;
  final int accuracy;
  final int predictions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NotchedStatCard(
            label: 'MATCHES',
            value: '$matches',
            fill: Color.lerp(Cyber.violet, Cyber.bg, 0.55)!,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NotchedStatCard(
            label: 'ACCURACY',
            value: '$accuracy%',
            fill: Color.lerp(Cyber.violet, Cyber.panel, 0.35)!,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NotchedStatCard(
            label: 'PREDICTIONS',
            value: '$predictions',
            fill: Cyber.panel,
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

  static const _notchW = 7.0;
  static const _notchH = 4.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotchedStatBorderPainter(fill: fill),
      child: ClipPath(
        clipper: const _NotchedStatClipper(
          notchW: _notchW,
          notchH: _notchH,
        ),
        child: Container(
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
          child: Column(
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  10,
                  color: Colors.white.withValues(alpha: 0.8),
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Cyber.display(22, letterSpacing: 0.5).copyWith(
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
    const notchW = _NotchedStatCard._notchW;
    const notchH = _NotchedStatCard._notchH;
    final path = _notchedRect(size, notchW, notchH);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.border,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedStatBorderPainter old) =>
      old.fill != fill;
}

// ─── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final PredictionHistoryFilter active;
  final Map<PredictionHistoryFilter, int> counts;
  final ValueChanged<PredictionHistoryFilter> onSelect;

  static const _labels = {
    PredictionHistoryFilter.all: 'ALL',
    PredictionHistoryFilter.live: 'LIVE',
    PredictionHistoryFilter.pending: 'PENDING',
    PredictionHistoryFilter.out: 'OUT',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final filter in PredictionHistoryFilter.values) ...[
            _FilterChip(
              label: '${_labels[filter]} (${counts[filter] ?? 0})',
              active: active == filter,
              onTap: () => onSelect(filter),
            ),
            if (filter != PredictionHistoryFilter.out)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Cyber.cyan.withValues(alpha: 0.12) : Cyber.panel,
          border: Border.all(
            color: active ? Cyber.cyan : Cyber.border,
          ),
        ),
        child: Text(
          label,
          style: Cyber.label(
            10,
            color: active ? Cyber.cyan : Cyber.muted,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─── Match card ──────────────────────────────────────────────────────────────

class _HistoryMatchCard extends StatelessWidget {
  const _HistoryMatchCard({
    required this.match,
    required this.league,
    required this.prediction,
    required this.quiz,
    required this.onDetails,
  });

  final SportMatch match;
  final League? league;
  final UserPrediction prediction;
  final PredictionQuiz quiz;
  final VoidCallback onDetails;

  bool get _settled => prediction.status == PredictionStatus.settled;
  bool get _pending => !_settled;

  @override
  Widget build(BuildContext context) {
    final outcomes = questionOutcomes(quiz, prediction);
    final scheduleColor = _pending ? Cyber.gold : Cyber.muted;

    return Container(
      decoration: BoxDecoration(
        color: Cyber.panel,
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatPredictionTimestamp(prediction.submittedAt),
                      style: Cyber.body(11, color: Cyber.muted),
                    ),
                    Text(
                      league?.shortCode ?? match.leagueId.toUpperCase(),
                      style: Cyber.body(11, color: Cyber.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TeamScoreRow(
                  team: match.home,
                  score: match.homeScore,
                  schedule: match.status == MatchStatus.upcoming
                      ? formatKickoffSchedule(match.kickoff)
                      : null,
                  scheduleColor: scheduleColor,
                  showSchedule: true,
                ),
                const SizedBox(height: 8),
                _TeamScoreRow(
                  team: match.away,
                  score: match.awayScore,
                  showSchedule: false,
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xff243654), height: 1),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREDICTED RESULT',
                            style: Cyber.label(
                              8,
                              color: Cyber.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _OutcomeGlyphs(outcomes: outcomes),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'STATUS',
                          style: Cyber.label(
                            8,
                            color: Cyber.muted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusValue(
                          settled: _settled,
                          reward: prediction.rewardEarned,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDetails,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Cyber.panel2.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(color: Cyber.line),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.open_in_full,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Predict Details',
                    style: Cyber.body(14, weight: FontWeight.w600),
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

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.team,
    required this.score,
    this.schedule,
    this.scheduleColor,
    required this.showSchedule,
  });

  final SportTeam team;
  final String? score;
  final String? schedule;
  final Color? scheduleColor;
  final bool showSchedule;

  @override
  Widget build(BuildContext context) {
    final light = team.color.computeLuminance() > 0.55;
    final textOnBadge = light ? const Color(0xff15202e) : Colors.white;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: team.color,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            team.shortName,
            style: TextStyle(
              color: textOnBadge,
              fontFamily: Cyber.displayFont,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            team.name,
            style: Cyber.body(14, weight: FontWeight.w700),
          ),
        ),
        if (score != null)
          Text(
            score!,
            style: Cyber.body(
              13,
              weight: FontWeight.w700,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        if (showSchedule && schedule != null) ...[
          const SizedBox(width: 10),
          Text(
            schedule!,
            style: Cyber.body(
              11,
              color: scheduleColor ?? Cyber.muted,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _OutcomeGlyphs extends StatelessWidget {
  const _OutcomeGlyphs({required this.outcomes});

  final List<QuestionOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final outcome in outcomes) _OutcomeGlyph(outcome: outcome),
      ],
    );
  }
}

class _OutcomeGlyph extends StatelessWidget {
  const _OutcomeGlyph({required this.outcome});

  final QuestionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return switch (outcome) {
      QuestionOutcome.correct => Text(
        '✓',
        style: Cyber.display(16, color: Cyber.cyan, letterSpacing: 0),
      ),
      QuestionOutcome.wrong => Text(
        '✕',
        style: Cyber.display(16, color: Colors.white, letterSpacing: 0),
      ),
      QuestionOutcome.pending => Text(
        '?',
        style: Cyber.display(16, color: Cyber.cyan.withValues(alpha: 0.75)),
      ),
    };
  }
}

class _StatusValue extends StatelessWidget {
  const _StatusValue({required this.settled, required this.reward});

  final bool settled;
  final int reward;

  @override
  Widget build(BuildContext context) {
    if (!settled) {
      return Text(
        'Pending',
        style: Cyber.body(14, weight: FontWeight.w600),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CoinIcon(size: 16),
        const SizedBox(width: 4),
        Text(
          '$reward',
          style: Cyber.display(16, letterSpacing: 0.5).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No predictions in this filter yet.',
        style: Cyber.body(13, color: Cyber.muted),
      ),
    );
  }
}
