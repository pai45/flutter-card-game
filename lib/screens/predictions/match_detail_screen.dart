import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/picks/picks_state.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/match_circle/match_circle_cubit.dart';
import '../../blocs/match_circle/match_circle_state.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../data/rival_roster.dart';
import '../../data/team_palettes.dart';
import '../../models/match_circle.dart';
import '../../models/picks.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../services/live_score_service.dart';
import '../../services/match_circle_repository.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_filter_chips.dart';
import '../../widgets/cricket_lineup_view.dart';
import '../../widgets/cricket_scorecard_view.dart';
import '../../widgets/basketball_scorecard_view.dart';
import '../../widgets/tennis_scorecard_view.dart';
import '../../widgets/match_summary_header.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../leaderboard/leaderboard_screen.dart' show showRivalDossier;
import '../leaderboard/widgets/rank_board.dart';
import 'all_picks_screen.dart';
import 'market_detail_screen.dart';
import 'match_circle_screen.dart';
import 'match_prediction_screen.dart';
import 'widgets/pick_market_card.dart';
import 'widgets/pick_trade_sheet.dart';
import 'widgets/standings_table.dart' show DetailTopBar;
import '../../widgets/match_pitch_view.dart';

class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({
    required this.match,
    this.initialTab = 0,
    this.refreshLiveScore = true,
    super.key,
  });

  final SportMatch match;
  final int initialTab;
  final bool refreshLiveScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('match-detail-screen'),
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DetailTopBar(title: 'MATCH'),
              Expanded(
                child: MatchTabsView(
                  match: match,
                  initialTab: initialTab,
                  refreshLiveScore: refreshLiveScore,
                  headerBuilder: (m) => MatchSummaryHeader(match: m),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reusable PREDICT / PICKS / TOPS / STATS tabbed body.
///
/// Lives here (not in a shared file) so it keeps package-private access to the
/// tab widgets below (`_MatchPicksTab`, `_MatchLeaderboardTab`,
/// `_ScoreboardTab`). Used full-screen by [MatchDetailScreen] and inline on the
/// match home page by the F1 weekend hub. Owns the active-tab state and the
/// football live-score polling; [headerBuilder] receives the live-enriched
/// match so headers can reflect score updates.
class MatchTabsView extends StatefulWidget {
  const MatchTabsView({
    required this.match,
    required this.headerBuilder,
    this.initialTab = 0,
    this.refreshLiveScore = false,
    super.key,
  });

  final SportMatch match;
  final Widget Function(SportMatch match) headerBuilder;
  final int initialTab;
  final bool refreshLiveScore;

  @override
  State<MatchTabsView> createState() => _MatchTabsViewState();
}

class _MatchTabsViewState extends State<MatchTabsView> {
  static const _tabs = ['PREDICT', 'PICKS', 'TOPS', 'STATS'];

  late int _activeTab = widget.initialTab.clamp(0, _tabs.length - 1);
  late SportMatch _match = widget.match;
  final LiveScoreService _liveScoreService = LiveScoreService();
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    if (widget.refreshLiveScore) {
      unawaited(_refreshLiveScore());
    }
  }

  @override
  void didUpdateWidget(covariant MatchTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.match, widget.match)) {
      _match = widget.match;
      _liveTimer?.cancel();
      if (widget.refreshLiveScore) {
        unawaited(_refreshLiveScore());
      }
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _setTab(int tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
  }

  Future<void> _refreshLiveScore() async {
    final enriched = await _liveScoreService.enrich(_match);
    if (!mounted) return;
    setState(() => _match = enriched);
    _configureLivePolling(enriched);
  }

  void _configureLivePolling(SportMatch match) {
    _liveTimer?.cancel();
    if (!_shouldPoll(match)) return;
    _liveTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_refreshLiveScore()),
    );
  }

  bool _shouldPoll(SportMatch match) =>
      match.sport == Sport.football &&
      match.status == MatchStatus.live &&
      match.liveStatusNote == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.headerBuilder(_match),
        CyberUnderlineTabs(
          labels: _tabs,
          activeIndex: _activeTab,
          onTap: _setTab,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey<int>(_activeTab),
              child: switch (_activeTab) {
                0 => MatchPredictionScreen(
                  match: _match,
                  embedded: true,
                  showTopBar: false,
                  showMatchHeader: false,
                  onOpenPicks: () => _setTab(1),
                ),
                1 => _MatchPicksTab(match: _match),
                2 => _MatchLeaderboardTab(
                  match: _match,
                  onJoin: () => _setTab(0),
                ),
                _ => _ScoreboardTab(match: _match),
              },
            ),
          ),
        ),
        _MatchCircleCta(match: _match),
      ],
    );
  }
}

class _MatchCircleCta extends StatefulWidget {
  const _MatchCircleCta({required this.match});

  final SportMatch match;

  @override
  State<_MatchCircleCta> createState() => _MatchCircleCtaState();
}

class _MatchCircleCtaState extends State<_MatchCircleCta> {
  MatchCircleCubit? _cubit;
  MatchCircleCubit? _ownedCubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final inherited = context.read<MatchCircleCubit?>();
    _cubit = inherited;
    if (_cubit == null) {
      _ownedCubit = MatchCircleCubit(
        LocalMatchCircleRepository(),
        SecureGameStorage(),
      );
      _cubit = _ownedCubit;
    }
    unawaited(_cubit!.ensureThread(widget.match));
  }

  @override
  void didUpdateWidget(covariant _MatchCircleCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (matchCircleThreadKey(oldWidget.match) !=
        matchCircleThreadKey(widget.match)) {
      unawaited(_cubit?.ensureThread(widget.match));
    }
  }

  @override
  void dispose() {
    unawaited(_ownedCubit?.close());
    super.dispose();
  }

  void _openCircle() {
    final cubit = _cubit;
    if (cubit == null) return;
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: MatchCircleScreen(match: widget.match),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<MatchCircleCubit, MatchCircleState>(
      bloc: cubit,
      builder: (context, state) {
        final thread = state.threadFor(widget.match);
        final loading = state.loading(widget.match) && thread == null;
        final countLabel = thread == null
            ? null
            : compactMatchCircleCount(thread.visibleCount);
        final semanticCount = countLabel == null
            ? ''
            : ', $countLabel discussion posts';
        return Semantics(
          key: const ValueKey('match-circle-cta'),
          button: true,
          label: 'Open Match Circle$semanticCount',
          child: Material(
            color: Colors.transparent,
            child: Ink(
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.panel.withValues(alpha: 0.88),
                    const Color(0xff17233d),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: Cyber.cyan.withValues(alpha: 0.16)),
                ),
              ),
              child: InkWell(
                onTap: _openCircle,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Match Circle',
                        style: Cyber.body(12, weight: FontWeight.w700),
                      ),
                      const SizedBox(width: 5),
                      if (loading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Cyber.cyan,
                          ),
                        )
                      else if (countLabel != null)
                        Text(
                          countLabel,
                          style: Cyber.body(10, color: Cyber.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MatchPicksTab extends StatelessWidget {
  const _MatchPicksTab({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PicksCubit, PicksState>(
      builder: (context, state) {
        if (state.loading) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
            children: const [
              _AllPicksCta(),
              SizedBox(height: 80),
              Center(child: CircularProgressIndicator(color: Cyber.cyan)),
            ],
          );
        }
        final markets =
            state.markets.where((market) => market.matchId == match.id).toList()
              ..sort(_compareMatchMarkets);
        if (markets.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
            children: const [
              _AllPicksCta(),
              CyberNoDataState(
                icon: Icons.ads_click,
                title: 'No picks for this match',
                message:
                    'Match-linked picks will appear here when markets open.',
                accent: Cyber.lime,
                spark: Icons.schedule,
              ),
            ],
          );
        }
        return ListView.separated(
          key: const ValueKey('match-picks-list'),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          itemCount: markets.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == 0) return const _AllPicksCta();
            final market = markets[index - 1];
            return PickMarketCard(
              market: market,
              positions: state.positionsForMarket(market.id),
              onOpen: () => _openMarket(context, market.id),
              onBuy: (outcome) => showPickTradeSheet(
                context: context,
                market: market,
                outcome: outcome,
              ),
            );
          },
        );
      },
    );
  }

  void _openMarket(BuildContext context, String marketId) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketDetailScreen(marketId: marketId),
      ),
    );
  }
}

class _AllPicksCta extends StatelessWidget {
  const _AllPicksCta();

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      key: const ValueKey('view-all-picks-cta'),
      onTap: () => _openAllPicks(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.ads_click, color: Cyber.lime, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VIEW ALL PICKS',
                    style: Cyber.display(
                      13,
                      color: Colors.white,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Browse every open market',
                    style: Cyber.body(11, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Cyber.lime, size: 20),
          ],
        ),
      ),
    );
  }

  void _openAllPicks(BuildContext context) {
    playSound(SoundEffect.uiTap);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AllPicksScreen()));
  }
}

class _MatchLeaderboardTab extends StatefulWidget {
  const _MatchLeaderboardTab({required this.match, this.onJoin});

  final SportMatch match;

  /// Jumps to the PREDICT tab so an unranked player can enter the board.
  final VoidCallback? onJoin;

  @override
  State<_MatchLeaderboardTab> createState() => _MatchLeaderboardTabState();
}

class _MatchLeaderboardTabState extends State<_MatchLeaderboardTab> {
  List<PredictionQuiz> _quizzes = const [];
  List<MatchPredictionLeaderboardEntry> _entries = const [];
  int _selectedIndex = 0;
  bool _loading = true;
  Timer? _lockTimer;
  String _untilLock = '';

  PredictionQuiz? get _selectedQuiz => _quizzes.isEmpty
      ? null
      : _quizzes[_selectedIndex.clamp(0, _quizzes.length - 1)];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _startLockTimer();
  }

  @override
  void didUpdateWidget(covariant _MatchLeaderboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id) {
      _selectedIndex = 0;
      unawaited(_load());
      _startLockTimer();
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  /// Drives the amber LOCKS IN pill. Ticks every second but only rebuilds when
  /// the rendered label actually changes.
  void _startLockTimer() {
    _lockTimer?.cancel();
    _untilLock = _lockLabel();
    if (_untilLock.isEmpty) return;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _lockLabel();
      if (next == _untilLock) return;
      if (!mounted) return;
      setState(() => _untilLock = next);
    });
  }

  String _lockLabel() {
    if (widget.match.status != MatchStatus.upcoming) return '';
    final remaining = widget.match.kickoff.difference(DateTime.now());
    if (remaining <= Duration.zero) return '';
    return formatBoardCountdown(remaining);
  }

  Future<void> _load() async {
    final cubit = context.read<PredictionCubit?>();
    if (cubit == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _quizzes = const [];
        _entries = const [];
      });
      return;
    }
    final quizzes = await cubit.quizzesFor(widget.match.id);
    final index = quizzes.isEmpty
        ? 0
        : _selectedIndex.clamp(0, quizzes.length - 1);
    final entries = quizzes.isEmpty
        ? const <MatchPredictionLeaderboardEntry>[]
        : await cubit.matchLeaderboard(widget.match.id, quizzes[index].id);
    if (!mounted) return;
    setState(() {
      _quizzes = quizzes;
      _selectedIndex = index;
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _selectQuiz(int index) async {
    if (index == _selectedIndex || index < 0 || index >= _quizzes.length) {
      return;
    }
    playSound(SoundEffect.uiTap);
    setState(() {
      _selectedIndex = index;
      _loading = true;
    });
    final cubit = context.read<PredictionCubit?>();
    final entries = cubit == null
        ? const <MatchPredictionLeaderboardEntry>[]
        : await cubit.matchLeaderboard(widget.match.id, _quizzes[index].id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _openRival(LeaderboardEntry entry) {
    if (entry.isUser) return;
    playSound(SoundEffect.uiTap);
    HapticFeedback.selectionClick();
    showRivalDossier(context, entry.name);
  }

  /// The board rows, already ranked by the cubit. The player only appears here
  /// once their card is settled — see [PredictionCubit.matchLeaderboard].
  List<LeaderboardEntry> _boardEntries() {
    return [
      for (final entry in _entries)
        LeaderboardEntry(
          rank: entry.rank,
          name: entry.name,
          score: entry.points,
          movement: entry.movement,
          isNew: entry.isNew,
          badge: entry.badge,
          isUser: entry.isUser,
          xp: entry.points,
          subtitle: '${entry.correct} CORRECT',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Cyber.cyan));
    }

    final quiz = _selectedQuiz;
    if (quiz == null) {
      return const CyberNoDataState(
        icon: Icons.emoji_events_outlined,
        title: 'No leaderboard yet',
        message: 'Prediction leaderboards appear when quiz sets open.',
        accent: Cyber.gold,
        spark: Icons.lock_clock,
      );
    }

    final accent = sportModuleFor(widget.match.sport).accent;
    final prediction = context.watch<PredictionCubit>().state.predictionFor(
      widget.match.id,
      quiz.id,
    );
    final entries = _boardEntries();
    const meta = (unit: 'PTS');

    // A thin field (< 3) skips the podium and lists everyone as flat rows.
    final usePodium = entries.length >= 3;
    final podium = usePodium ? entries.take(3).toList() : const <LeaderboardEntry>[];
    final rest = usePodium ? entries.skip(3).toList() : entries;

    return Column(
      key: const ValueKey('match-leaderboard-tab'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_quizzes.length > 1) ...[
                  CyberUnderlineTabs(
                    labels: [
                      for (final quiz in _quizzes) quiz.title.toUpperCase(),
                    ],
                    activeIndex: _selectedIndex,
                    accent: Cyber.gold,
                    onTap: _selectQuiz,
                  ),
                  const SizedBox(height: 14),
                ],
                _BoardMetaStrip(
                  untilLock: _untilLock,
                  answered: prediction?.answers.length ?? 0,
                  total: quiz.questions.length,
                  players: entries.length,
                  accent: accent,
                ),
                const SizedBox(height: 12),
                _BoardHeader(
                  label: _leaderboardModeLabel(widget.match, prediction, quiz),
                ),
                const SizedBox(height: 14),
                if (entries.isEmpty)
                  _LeaderboardEmpty(match: widget.match, prediction: prediction)
                else ...[
                  RankPodium(
                    entries: podium,
                    meta: meta,
                    accent: accent,
                    animateCards: true,
                    onTapEntry: _openRival,
                  ),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    for (var i = 0; i < rest.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StaggeredCardEntrance(
                          index: i + podium.length,
                          animate: true,
                          maxAnimatedIndex: entries.length,
                          child: RankRow(
                            entry: rest[i],
                            accent: accent,
                            meta: meta,
                            onTap: () => _openRival(rest[i]),
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
        _MatchBoardUserBar(
          entries: entries,
          prediction: prediction,
          quiz: quiz,
          accent: accent,
          onJoin: widget.onJoin,
        ),
      ],
    );
  }
}

/// The docked "where you stand" card, in its three states: settled (a real
/// rank), submitted-but-unsettled (pending), and not played (join).
class _MatchBoardUserBar extends StatelessWidget {
  const _MatchBoardUserBar({
    required this.entries,
    required this.prediction,
    required this.quiz,
    required this.accent,
    this.onJoin,
  });

  final List<LeaderboardEntry> entries;
  final UserPrediction? prediction;
  final PredictionQuiz quiz;
  final Color accent;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    const meta = (unit: 'PTS');
    final total = quiz.questions.length;

    for (final entry in entries) {
      if (!entry.isUser) continue;
      final correct = prediction?.correctCount ?? 0;
      return RankUserBar(
        user: LeaderboardEntry(
          rank: entry.rank,
          name: entry.name,
          score: entry.score,
          movement: entry.movement,
          isNew: entry.isNew,
          badge: entry.badge,
          isUser: true,
          xp: entry.xp,
          subtitle: '$correct / $total CORRECT',
        ),
        meta: meta,
        accent: accent,
      );
    }

    final name = kRivalRoster.firstWhere((seed) => seed.isUser).name;
    final answered = prediction?.answers.length ?? 0;
    final pending = prediction != null;
    return RankUserBar(
      user: LeaderboardEntry(
        rank: 0,
        name: name,
        score: 0,
        movement: 0,
        isUser: true,
        subtitle: pending
            ? '$answered / $total LOCKED · PENDING'
            : 'PLAY THE QUIZ TO ENTER',
      ),
      meta: meta,
      accent: accent,
      label: 'Your standing',
      rankText: pending ? '#--' : 'UNRANKED',
      showScore: false,
      ctaLabel: pending ? null : 'JOIN',
      onTap: pending ? null : onJoin,
    );
  }
}

/// Countdown to lock plus the two board telemetry cells.
class _BoardMetaStrip extends StatelessWidget {
  const _BoardMetaStrip({
    required this.untilLock,
    required this.answered,
    required this.total,
    required this.players,
    required this.accent,
  });

  final String untilLock;
  final int answered;
  final int total;
  final int players;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (untilLock.isNotEmpty)
          CountdownPill(label: 'LOCKS IN', remaining: untilLock),
        const Spacer(),
        _BoardMetaCell(
          label: 'PREDICTIONS',
          value: '$answered/$total',
          color: Cyber.gold,
        ),
        const SizedBox(width: 18),
        _BoardMetaCell(
          label: 'PLAYERS',
          value: '$players',
          color: accent,
        ),
      ],
    );
  }
}

class _BoardMetaCell extends StatelessWidget {
  const _BoardMetaCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(
          value,
          style: Cyber.display(
            14,
            color: color,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

/// The state-driven board caption (LOCKED IN · CROWD VOTES, FINAL RESULTS, …)
/// over a hairline rule.
class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Cyber.label(10, color: Cyber.gold, letterSpacing: 1.6)),
        const SizedBox(height: 8),
        Container(height: 1, color: Cyber.gold.withValues(alpha: 0.22)),
      ],
    );
  }
}

class _LeaderboardEmpty extends StatelessWidget {
  const _LeaderboardEmpty({required this.match, required this.prediction});

  final SportMatch match;
  final UserPrediction? prediction;

  @override
  Widget build(BuildContext context) {
    final canJoin = match.predictable || prediction != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: CyberNoDataState(
        icon: canJoin ? Icons.sports_esports : Icons.emoji_events_outlined,
        title: canJoin ? 'Be the 1st to play' : 'No players yet',
        message: canJoin
            ? 'Play this prediction quiz and set the rank to beat.'
            : 'No prediction quiz results were submitted before this board closed.',
        accent: canJoin ? Cyber.cyan : Cyber.gold,
        spark: canJoin ? Icons.bolt : Icons.lock_clock,
      ),
    );
  }
}

class _ScoreboardTab extends StatefulWidget {
  const _ScoreboardTab({required this.match});

  final SportMatch match;

  @override
  State<_ScoreboardTab> createState() => _ScoreboardTabState();
}

class _ScoreboardTabState extends State<_ScoreboardTab> {
  late String _activeTab = widget.match.sport == Sport.basketball
      ? 'BOX SCORE'
      : (widget.match.sport == Sport.tennis ? 'SETS' : 'FACTS');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyberFilterChips(
          labels: widget.match.sport == Sport.basketball
              ? const ['BOX SCORE', 'LINEUP', 'COMMENTARY']
              : (widget.match.sport == Sport.tennis
                    ? const ['SETS', 'LINEUP', 'COMMENTARY']
                    : const ['FACTS', 'LINEUP', 'COMMENTARY']),
          selected: _activeTab,
          accent: Cyber.cyan,
          onSelect: (value) => setState(() => _activeTab = value),
        ),
        Expanded(
          child:
              (_activeTab == 'FACTS' ||
                  _activeTab == 'BOX SCORE' ||
                  _activeTab == 'SETS')
              ? (widget.match.sport == Sport.cricket &&
                        widget.match.cricketScorecard != null)
                    ? ListView(
                        key: const ValueKey('match-scoreboard-cricket-facts'),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        children: [
                          CricketScorecardView(
                            scorecard: widget.match.cricketScorecard!,
                            accent: Cyber.cyan,
                          ),
                        ],
                      )
                    : (widget.match.sport == Sport.basketball &&
                          widget.match.basketballScorecard != null)
                    ? ListView(
                        key: const ValueKey(
                          'match-scoreboard-basketball-facts',
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        children: [
                          BasketballScorecardView(
                            scorecard: widget.match.basketballScorecard!,
                            accent: const Color(
                              0xffff6600,
                            ), // WNBA orange/nba reference
                          ),
                        ],
                      )
                    : (widget.match.sport == Sport.tennis &&
                          widget.match.tennisScorecard != null)
                    ? ListView(
                        key: const ValueKey('match-scoreboard-tennis-facts'),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        children: [
                          _MatchFactPanel(match: widget.match),
                          const SizedBox(height: 14),
                          TennisScorecardView(
                            scorecard: widget.match.tennisScorecard!,
                            match: widget.match,
                            accent: Cyber.cyan,
                          ),
                        ],
                      )
                    : ListView(
                        key: const ValueKey('match-scoreboard-facts'),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        children: [
                          _MatchFactPanel(match: widget.match),
                          if (widget.match.sport == Sport.motorsport &&
                              _f1NonQualifyingSessions(
                                widget.match.f1Sessions,
                              ).isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _F1SessionsPanel(match: widget.match),
                          ],
                          if (widget.match.sport == Sport.motorsport &&
                              widget.match.f1DriverStandings != null) ...[
                            const SizedBox(height: 14),
                            _DriverStandingsPanel(match: widget.match),
                          ],
                          if (widget.match.teamStats?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 14),
                            _TeamStatsPanel(match: widget.match),
                          ],
                          const SizedBox(height: 14),
                          _TimelinePanel(match: widget.match),
                          const SizedBox(height: 14),
                          _StatePanel(match: widget.match),
                        ],
                      )
              : _activeTab == 'LINEUP'
              ? _LineupsTab(match: widget.match)
              : _CommentaryTab(match: widget.match),
        ),
      ],
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final events = match.timelineEvents;
    if (events == null || events.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Panel(
      title: 'MATCH TIMELINE',
      accent: Cyber.cyan,
      child: Column(
        children: events.map((event) => _TimelineRow(event: event)).toList(),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});
  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final isHome = event.isHomeTeam;

    Widget eventIcon;
    switch (event.type) {
      case MatchEventType.goal:
        eventIcon = const Icon(
          Icons.sports_soccer,
          size: 16,
          color: Colors.white,
        );
        break;
      case MatchEventType.yellowCard:
        eventIcon = Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.yellow,
            borderRadius: BorderRadius.circular(2),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 2),
        );
        break;
      case MatchEventType.redCard:
        eventIcon = Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 2),
        );
        break;
      case MatchEventType.substitution:
        eventIcon = const Icon(Icons.swap_horiz, size: 18, color: Cyber.lime);
        break;
    }

    final timeWidget = SizedBox(
      width: 40,
      child: Text(
        "${event.minute}'",
        textAlign: TextAlign.center,
        style: Cyber.display(
          14,
          color: Cyber.cyan,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );

    final playerWidget = Expanded(
      child: Column(
        crossAxisAlignment: isHome
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            event.playerName,
            style: Cyber.body(14, weight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (event.secondaryPlayerName != null)
            Text(
              event.secondaryPlayerName!,
              style: Cyber.label(10, color: Cyber.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (isHome) playerWidget else const Expanded(child: SizedBox()),
          if (isHome) const SizedBox(width: 8),
          if (isHome) eventIcon,
          timeWidget,
          if (!isHome) eventIcon,
          if (!isHome) const SizedBox(width: 8),
          if (!isHome) playerWidget else const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _LineupsTab extends StatelessWidget {
  const _LineupsTab({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.sport == Sport.cricket) {
      return CricketLineupView(match: match);
    }
    if (match.sport == Sport.motorsport) {
      return _F1QualifyingLineupView(match: match);
    }
    return MatchPitchView(match: match);
  }
}

class _CommentaryTab extends StatelessWidget {
  const _CommentaryTab({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final commentary = match.commentary;
    if (commentary == null || commentary.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.chat_bubble_outline,
        title: 'No commentary yet',
        message:
            'Play-by-play commentary will appear here once the match starts.',
        accent: Cyber.cyan,
        spark: Icons.mic,
      );
    }
    return ListView.separated(
      key: const ValueKey('match-commentary-list'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: commentary.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = commentary[index];
        return _CommentaryRow(item: item);
      },
    );
  }
}

class _CommentaryRow extends StatelessWidget {
  const _CommentaryRow({required this.item});
  final MatchCommentary item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.34),
        border: Border.all(color: Cyber.line.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.minute.isNotEmpty) ...[
            SizedBox(
              width: 36,
              child: Text(
                item.minute,
                style: Cyber.display(
                  12,
                  color: Cyber.cyan,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              item.text,
              style: Cyber.body(13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchFactPanel extends StatelessWidget {
  const _MatchFactPanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'MATCH FACTS',
      child: Column(
        children: [
          _FactRow(label: 'STATUS', value: _statusText(match)),
          _FactRow(label: 'LAST UPDATED', value: _formatLiveUpdated(match)),
          _FactRow(label: 'KICKOFF', value: _formatDateTime(match.kickoff)),
          _FactRow(label: 'LEAGUE', value: match.leagueId.toUpperCase()),
          _FactRow(label: 'SPORT', value: match.sport.name.toUpperCase()),
        ],
      ),
    );
  }
}

class _DriverStandingsPanel extends StatelessWidget {
  const _DriverStandingsPanel({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final standings = match.f1DriverStandings;
    if (standings == null || standings.isEmpty) return const SizedBox.shrink();

    return _Panel(
      title: 'DRIVER STANDINGS',
      accent: Cyber.gold,
      child: Column(
        children: [
          for (var i = 0; i < standings.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Cyber.line.withValues(alpha: 0.1),
              ),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${i + 1}',
                      style:
                          Cyber.display(
                            14,
                            color: i < 3 ? Cyber.gold : Cyber.muted,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      standings[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(
                        14,
                        weight: i < 3 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _F1SessionsPanel extends StatelessWidget {
  const _F1SessionsPanel({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    // Qualifying lives on the LINEUP tab as the starting grid.
    final sessions = _f1NonQualifyingSessions(match.f1Sessions);
    if (sessions.isEmpty) return const SizedBox.shrink();

    return _Panel(
      title: 'SESSION RESULTS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var s = 0; s < sessions.length; s++) ...[
            if (s > 0) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 1,
                color: Cyber.line.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              sessions[s].name.toUpperCase(),
              style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            if (sessions[s].results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Not yet run.',
                  style: Cyber.body(12, color: Cyber.muted),
                ),
              )
            else
              for (final result in sessions[s].results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    result,
                    style: Cyber.body(13, color: Colors.white),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// F1 LINEUP tab — ESPN qualifying order as the starting grid.
class _F1QualifyingLineupView extends StatelessWidget {
  const _F1QualifyingLineupView({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final sessions = _f1QualifyingSessions(match.f1Sessions);
    if (sessions.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.grid_view_outlined,
        title: 'Grid not set',
        message:
            'Qualifying results will lock the starting grid here once the session runs.',
        accent: Cyber.cyan,
        spark: Icons.flag_outlined,
      );
    }

    final hasAnyResults = sessions.any((s) => s.results.isNotEmpty);
    if (!hasAnyResults) {
      return const CyberNoDataState(
        icon: Icons.timer_outlined,
        title: 'Qualifying pending',
        message:
            'The session is on the schedule — grid order drops here when times are in.',
        accent: Cyber.gold,
        spark: Icons.electric_bolt,
      );
    }

    return ListView(
      key: const ValueKey('f1-qualifying-lineup'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        for (var s = 0; s < sessions.length; s++) ...[
          if (s > 0) const SizedBox(height: 14),
          _F1QualifyingGridPanel(session: sessions[s]),
        ],
      ],
    );
  }
}

class _F1QualifyingGridPanel extends StatelessWidget {
  const _F1QualifyingGridPanel({required this.session});
  final F1SessionResult session;

  @override
  Widget build(BuildContext context) {
    final isSprint = session.isSprintQualifying;
    final title = isSprint ? 'SPRINT QUALIFYING' : 'STARTING GRID';
    final accent = isSprint ? Cyber.magenta : Cyber.cyan;

    return _Panel(
      title: title,
      accent: accent,
      child: Column(
        children: [
          if (session.results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Not yet run.',
                style: Cyber.body(13, color: Cyber.muted),
              ),
            )
          else
            for (var i = 0; i < session.results.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Cyber.line.withValues(alpha: 0.1),
                ),
              _F1GridRow(
                entry: session.results[i],
                index: i,
                isPole: i == 0 && !isSprint,
              ),
            ],
        ],
      ),
    );
  }
}

class _F1GridRow extends StatelessWidget {
  const _F1GridRow({
    required this.entry,
    required this.index,
    required this.isPole,
  });

  final String entry;
  final int index;
  final bool isPole;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseF1ResultEntry(entry);
    final posColor = isPole
        ? Cyber.gold
        : (index < 3 ? Cyber.cyan : Cyber.muted);
    final nameWeight = isPole || index < 3 ? FontWeight.w800 : FontWeight.w600;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: isPole
          ? BoxDecoration(
              color: Color.alphaBlend(
                Cyber.gold.withValues(alpha: 0.08),
                Cyber.panel,
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'P${parsed.position ?? (index + 1)}',
              style: Cyber.display(13, color: posColor).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.driver,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(14, weight: nameWeight),
                ),
                if (parsed.constructor != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    parsed.constructor!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.0),
                  ),
                ],
              ],
            ),
          ),
          if (isPole) ...[
            const SizedBox(width: 8),
            Text(
              'POLE',
              style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1.4),
            ),
          ],
          if (parsed.time != null) ...[
            const SizedBox(width: 10),
            Text(
              parsed.time!,
              style: Cyber.display(
                12,
                color: isPole ? Cyber.gold : Cyber.muted,
              ).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<F1SessionResult> _f1QualifyingSessions(List<F1SessionResult>? sessions) {
  if (sessions == null || sessions.isEmpty) return const [];
  return sessions.where((s) => s.isQualifying).toList(growable: false);
}

List<F1SessionResult> _f1NonQualifyingSessions(List<F1SessionResult>? sessions) {
  if (sessions == null || sessions.isEmpty) return const [];
  return sessions.where((s) => !s.isQualifying).toList(growable: false);
}

({int? position, String driver, String? constructor, String? time})
_parseF1ResultEntry(String entry) {
  final positionMatch = RegExp(r'^\s*(\d+)[.)]\s*').firstMatch(entry);
  final int? position = positionMatch == null
      ? null
      : int.tryParse(positionMatch.group(1)!);
  final stripped = entry
      .replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '')
      .trim();
  final timeMatch = RegExp(r'\(([^)]+)\)\s*$').firstMatch(stripped);
  final String? time = timeMatch?.group(1)?.trim();
  final withoutTime = timeMatch == null
      ? stripped
      : stripped.substring(0, timeMatch.start).trim();
  final parts = withoutTime.split(' · ');
  final driver = parts.first.trim();
  final constructor = parts.length > 1 ? parts[1].trim() : null;
  return (
    position: position,
    driver: driver.isEmpty ? entry : driver,
    constructor: constructor == null || constructor.isEmpty ? null : constructor,
    time: time == null || time.isEmpty ? null : time,
  );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final note = match.liveStatusNote;
    final (icon, title, message, accent) = switch (match.status) {
      MatchStatus.upcoming => (
        Icons.schedule,
        'PRE-MATCH',
        note ?? 'Scoreboard opens when the match starts.',
        Cyber.gold,
      ),
      MatchStatus.live => (
        Icons.sensors,
        'LIVE NOW',
        note ??
            (match.liveMinute != null
                ? 'Live clock: ${match.liveMinute} minutes.'
                : 'Live match data is active.'),
        Cyber.danger,
      ),
      MatchStatus.finished => (
        Icons.flag_outlined,
        'FULL TIME',
        note ?? match.resultLine ?? 'Final score has been recorded.',
        Cyber.muted,
      ),
    };
    return _Panel(
      title: 'SCORECARD',
      accent: accent,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Cyber.display(15, letterSpacing: 0.8)),
                const SizedBox(height: 5),
                Text(message, style: Cyber.body(12, color: Cyber.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Head-to-head team statistics as labelled split bars — one bar per metric,
/// filled from each side in its own team colour. This is a static data block,
/// so per the glow rule nothing here glows; separation comes from the flat
/// panel fill and the team colours themselves.
class _TeamStatsPanel extends StatelessWidget {
  const _TeamStatsPanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final stats = match.teamStats;
    if (stats == null || stats.isEmpty) return const SizedBox.shrink();

    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;

    return _Panel(
      title: 'TEAM STATS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatsLegend(color: homeColor, label: match.home.shortName),
              const Spacer(),
              _StatsLegend(
                color: awayColor,
                label: match.away.shortName,
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final stat in stats)
            _TeamStatRow(
              stat: stat,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
        ],
      ),
    );
  }
}

class _StatsLegend extends StatelessWidget {
  const _StatsLegend({
    required this.color,
    required this.label,
    this.alignEnd = false,
  });

  final Color color;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final swatch = Container(width: 9, height: 9, color: color);
    final text = Text(
      label.toUpperCase(),
      style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.2),
    );
    return Row(
      children: alignEnd
          ? [text, const SizedBox(width: 6), swatch]
          : [swatch, const SizedBox(width: 6), text],
    );
  }
}

class _TeamStatRow extends StatelessWidget {
  const _TeamStatRow({
    required this.stat,
    required this.homeColor,
    required this.awayColor,
  });

  final TeamStatLine stat;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    // Flex needs whole numbers, and a side that recorded nothing should still
    // leave a sliver of colour rather than vanishing.
    final homeFlex = (stat.homeShare * 1000).round().clamp(4, 996);
    final numberStyle = Cyber.label(
      13,
      letterSpacing: 0.6,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(stat.homeDisplay, style: numberStyle),
              Expanded(
                child: Text(
                  stat.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Cyber.label(
                    9.5,
                    color: Cyber.muted,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(stat.awayDisplay, style: numberStyle),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(
                  flex: homeFlex,
                  child: ColoredBox(color: homeColor),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 1000 - homeFlex,
                  child: ColoredBox(color: awayColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.accent = Cyber.cyan,
  });

  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff10192d),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Cyber.label(10, color: accent, letterSpacing: 1.4),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: Cyber.label(9, color: Cyber.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Cyber.body(12, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String _leaderboardModeLabel(
  SportMatch match,
  UserPrediction? prediction,
  PredictionQuiz quiz,
) {
  if (prediction?.status == PredictionStatus.settled) return 'FINAL RESULTS';
  if (match.status == MatchStatus.finished) {
    return prediction != null && quiz.settleable
        ? 'FINAL RANKS READY'
        : 'MATCH CLOSED';
  }
  if (match.status == MatchStatus.live) {
    return 'LOCKED PICKS';
  }
  if (prediction?.status == PredictionStatus.locked) {
    return 'LOCKED IN · CROWD VOTES';
  }
  if (prediction != null) return 'DRAFT ACTIVE · REVIEW & LOCK';
  return 'JOIN BEFORE LOCK';
}

int _compareMatchMarkets(PickMarket a, PickMarket b) {
  final statusRank = _marketStatusRank(
    a.status,
  ).compareTo(_marketStatusRank(b.status));
  if (statusRank != 0) return statusRank;
  return a.closesAt.compareTo(b.closesAt);
}

int _marketStatusRank(PickMarketStatus status) => switch (status) {
  PickMarketStatus.live => 0,
  PickMarketStatus.upcoming => 1,
  PickMarketStatus.closed || PickMarketStatus.unresolved => 2,
  PickMarketStatus.settled || PickMarketStatus.voided => 3,
};

String _statusText(SportMatch match) => switch (match.status) {
  MatchStatus.upcoming => _formatTime(match.kickoff),
  MatchStatus.live =>
    match.liveMinute != null ? "LIVE ${match.liveMinute}'" : 'LIVE',
  MatchStatus.finished => 'FT',
};

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$mo-$d ${_formatTime(local)}';
}

String _formatLiveUpdated(SportMatch match) {
  final updated = match.liveLastUpdated;
  if (updated == null) return 'Unavailable';
  return _formatDateTime(updated);
}
