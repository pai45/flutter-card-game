import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/picks/picks_cubit.dart';
import '../../../blocs/picks/picks_state.dart';
import '../../../blocs/prediction/prediction_cubit.dart';
import '../../../blocs/prediction/prediction_state.dart';
import '../../../config/game_ladder.dart';
import '../../../config/theme.dart';
import '../../../design_system/match_discovery.generated.dart';
import '../../../models/picks.dart';
import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';
import '../../../models/unlock_progress.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/match_discovery.dart';
import 'pick_trade_sheet.dart';
import '../match_prediction_screen.dart';

class TrendingMatchesView extends StatefulWidget {
  const TrendingMatchesView({
    required this.onOpenMatch,
    required this.onOpenMarket,
    required this.animateIntro,
    this.onOpenQuiz,
    this.onIntroPlayed,
    this.header,
    super.key,
  });
  final ValueChanged<SportMatch> onOpenMatch;
  final ValueChanged<String> onOpenMarket;
  final ValueChanged<Sport>? onOpenQuiz;
  final bool animateIntro;
  final VoidCallback? onIntroPlayed;
  final Widget? header;
  @override
  State<TrendingMatchesView> createState() => _TrendingMatchesViewState();
}

class _EditorialCycle {
  const _EditorialCycle(
    this.sport,
    this.matches,
    this.compact,
    this.missions,
    this.events,
    this.future,
  );
  final Sport sport;
  final List<String> matches, missions, events;
  final String? compact, future;
}

class _TrendingMatchesViewState extends State<TrendingMatchesView> {
  final Map<Sport, _EditorialCycle> _cycles = {};
  bool _introPlayed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final cubit = context.read<PredictionCubit>();
    final unlocks =
        context.read<GameBloc?>()?.state.unlocks ?? const UnlockProgress();
    for (final sport in MatchDiscoveryTokens.sportOrder.map(
      (name) => Sport.values.firstWhere((sport) => sport.name == name),
    )) {
      if (!mounted) return;
      if (unlocks.isSportUnlocked(sport)) await cubit.loadSport(sport);
    }
  }

  _EditorialCycle _select(
    Sport sport,
    PredictionState state,
    PicksState picks,
  ) {
    int priority(SportMatch m) =>
        (state.isFavoriteMatch(m) ? 4 : 0) +
        (state.followedLeagueIds.contains(m.leagueId) ? 2 : 0) +
        (state
                .predictionsForMatch(m.id)
                .any((p) => p.status == PredictionStatus.open)
            ? 1
            : 0);
    final seen = <String>{};
    final fixtures =
        state.fixtures.where((m) => m.sport == sport && seen.add(m.id)).toList()
          ..sort((a, b) {
            final p = priority(b).compareTo(priority(a));
            if (p != 0) return p;
            final live = (b.status == MatchStatus.live ? 1 : 0).compareTo(
              a.status == MatchStatus.live ? 1 : 0,
            );
            if (live != 0) return live;
            final time = a.kickoff.compareTo(b.kickoff);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    final matches = fixtures
        .take(MatchDiscoveryTokens.cycleCounts['matches']!)
        .map((m) => m.id)
        .toList();
    final compact = fixtures
        .skip(MatchDiscoveryTokens.cycleCounts['matches']!)
        .firstOrNull
        ?.id;
    final missions = fixtures
        .where(
          (m) =>
              m.status == MatchStatus.upcoming &&
              state.quizzes.values.any(
                (q) => q.matchId == m.id && q.entryFee == 0,
              ),
        )
        .take(MatchDiscoveryTokens.cycleCounts['missions']!)
        .map((m) => m.id)
        .toList();
    final events = picks.markets
        .where(
          (m) =>
              m.sport == sport &&
              m.type == PickMarketType.event &&
              m.outcomes.isNotEmpty,
        )
        .take(MatchDiscoveryTokens.cycleCounts['events']!)
        .map((m) => m.id)
        .toList();
    final excluded = _featured(
      picks.markets,
    ).map((market) => market.id).toSet();
    final futures =
        picks.markets
            .where(
              (market) =>
                  market.sport == sport &&
                  market.type == PickMarketType.future &&
                  market.outcomes.isNotEmpty &&
                  !excluded.contains(market.id),
            )
            .toList()
          ..sort((a, b) {
            int rank(PickMarket market) =>
                (market.canBuy ? 4 : 0) +
                (RegExp(
                      MatchDiscoveryTokens.futurePriorityPattern,
                      caseSensitive: false,
                    ).hasMatch(market.question)
                    ? 2
                    : 0);
            final order = rank(b).compareTo(rank(a));
            return order != 0 ? order : a.id.compareTo(b.id);
          });
    return _EditorialCycle(
      sport,
      matches,
      compact,
      missions,
      events,
      futures.firstOrNull?.id,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<PredictionCubit, PredictionState>(
    builder: (context, state) => BlocBuilder<PicksCubit, PicksState>(
      builder: (context, picks) {
        final unlocks = context.select<GameBloc?, UnlockProgress>(
          (b) => b?.state.unlocks ?? const UnlockProgress(),
        );
        final ordered = MatchDiscoveryTokens.sportOrder
            .map((name) => Sport.values.firstWhere((s) => s.name == name))
            .where(unlocks.isSportUnlocked);
        // Freeze each sport's IDs after its load; values and statuses remain live.
        for (final sport in ordered) {
          if (!_cycles.containsKey(sport) &&
              (!state.loadingSports.contains(sport)) &&
              (state.loadedSports.contains(sport) ||
                  state.fixtures.any((m) => m.sport == sport)) &&
              !picks.loading) {
            final selected = _select(sport, state, picks);
            if (selected.matches.isNotEmpty ||
                selected.events.isNotEmpty ||
                selected.future != null) {
              _cycles[sport] = selected;
            }
          }
        }
        final markets = _featured(
          picks.markets.where((m) => unlocks.isSportUnlocked(m.sport)).toList(),
        );
        if (!_introPlayed && _cycles.isNotEmpty) {
          _introPlayed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onIntroPlayed?.call();
          });
        }
        SportMatch? match(String id) =>
            state.fixtures.where((m) => m.id == id).firstOrNull;
        final children = <Widget>[
          if (markets.isNotEmpty) ...[
            _FeaturedPicks(markets: markets, onOpen: widget.onOpenMarket),
            const SizedBox(height: MatchDiscoveryTokens.moduleGap),
          ],
          for (final sport in ordered)
            if (_cycles[sport] case final cycle?) ...[
              if (cycle.matches.isNotEmpty) ...[
                for (var i = 0; i < cycle.matches.length; i++)
                  if (match(cycle.matches[i]) case final fixture?) ...[
                    if (i > 0) const SizedBox(height: 16),
                    EditorialMatchCard(
                      key: ValueKey('editorial-match-${fixture.id}'),
                      match: fixture,
                      followed: state.isFavoriteMatch(fixture),
                      competitionLabel: state.leagueFor(fixture.leagueId)?.name,
                      onTap: () => widget.onOpenMatch(fixture),
                    ),
                  ],
                const SizedBox(height: MatchDiscoveryTokens.moduleGap),
              ],
              if (cycle.events.isNotEmpty) ...[
                EditorialEventsPanel(
                  markets: cycle.events
                      .expand((id) => picks.markets.where((m) => m.id == id))
                      .toList(),
                  onOpen: widget.onOpenMarket,
                ),
                const SizedBox(height: MatchDiscoveryTokens.moduleGap),
              ],
              EditorialPairedGrid(
                children: [
                  if (widget.onOpenQuiz != null) _quiz(context, sport, unlocks),
                  if (cycle.compact != null)
                    if (match(cycle.compact!) case final fixture?)
                      EditorialMatchCard(
                        match: fixture,
                        followed: state.isFavoriteMatch(fixture),
                        competitionLabel: state
                            .leagueFor(fixture.leagueId)
                            ?.name,
                        compact: true,
                        onTap: () => widget.onOpenMatch(fixture),
                      ),
                  for (final id in cycle.missions)
                    if (match(id) case final fixture?)
                      if (state.quizzes.values
                              .where((q) => q.matchId == id && q.entryFee == 0)
                              .firstOrNull
                          case final quiz?)
                        EditorialMission(
                          match: fixture,
                          quiz: quiz,
                          prediction: state.predictionFor(id, quiz.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MatchPredictionScreen(
                                match: fixture,
                                quizId: quiz.id,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
              if (cycle.future != null)
                if (picks.markets
                        .where(
                          (m) =>
                              m.id == cycle.future &&
                              m.type == PickMarketType.future,
                        )
                        .firstOrNull
                    case final future?) ...[
                  const SizedBox(height: MatchDiscoveryTokens.moduleGap),
                  EditorialMarketCard(
                    market: future,
                    featured: true,
                    onOpen: () => widget.onOpenMarket(future.id),
                    onBuy: (outcome) => showPickTradeSheet(
                      context: context,
                      market: future,
                      outcome: outcome,
                    ),
                  ),
                ],
              const SizedBox(height: MatchDiscoveryTokens.moduleGap),
            ],
          if ((state.loading || state.loadingSports.isNotEmpty) &&
              _cycles.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (widget.header != null) widget.header!,
        ];
        return ListView(
          key: const PageStorageKey('match-trending-feed'),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
          children: [
            for (final child in children)
              if (child is _FeaturedPicks)
                child
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MatchDiscoveryTokens.page,
                  ),
                  child: child,
                ),
          ],
        );
      },
    ),
  );
  Widget _quiz(BuildContext context, Sport sport, UnlockProgress unlocks) {
    final game = switch (sport) {
      Sport.football => ArcadeGame.footballQuiz,
      Sport.cricket => ArcadeGame.cricketQuiz,
      Sport.basketball => ArcadeGame.basketballQuiz,
      _ => ArcadeGame.motorsportQuiz,
    };
    final locked = !unlocks.isGameUnlocked(game);
    return EditorialPlate(
      onTap: () => widget.onOpenQuiz?.call(sport),
      signalAccent: editorialSportAccent(sport),
      motionId: 'quiz:${sport.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialStatusArea(label: sport.name, sport: sport),
          EditorialInset(
            padding: EdgeInsets.zero,
            edge: Colors.transparent,
            child: SizedBox(
              height: 104,
              child: CyberGameIllustration(
                art: CyberGameArt.quiz,
                game: game,
                accent: Cyber.cyan,
                animate: !locked,
              ),
            ),
          ),
          Text(
            game.title,
            style: Cyber.display(14).copyWith(fontWeight: FontWeight.w600),
          ),
          EditorialAction(locked ? 'Locked · Play quiz' : 'Play quiz'),
        ],
      ),
    );
  }
}

List<PickMarket> _featured(List<PickMarket> markets) {
  final seen = <String>{}, out = <PickMarket>[];
  for (var i = 0; i < MatchDiscoveryTokens.carouselIds.length; i++) {
    final sport = Sport.values.firstWhere(
      (s) => s.name == [...MatchDiscoveryTokens.sportOrder, 'football'][i],
    );
    final m =
        markets
            .where(
              (m) =>
                  m.id == MatchDiscoveryTokens.carouselIds[i] &&
                  m.sport == sport &&
                  !seen.contains(m.id) &&
                  m.outcomes.isNotEmpty,
            )
            .firstOrNull ??
        markets
            .where(
              (m) =>
                  m.sport == sport &&
                  m.type == PickMarketType.match &&
                  !seen.contains(m.id) &&
                  m.outcomes.isNotEmpty,
            )
            .firstOrNull;
    if (m != null) {
      seen.add(m.id);
      out.add(m);
    }
  }
  return out;
}

class _FeaturedPicks extends StatefulWidget {
  const _FeaturedPicks({required this.markets, required this.onOpen});
  final List<PickMarket> markets;
  final ValueChanged<String> onOpen;
  @override
  State<_FeaturedPicks> createState() => _FeaturedPicksState();
}

class _FeaturedPicksState extends State<_FeaturedPicks> {
  final controller = ScrollController();
  int active = 0;
  double width = 300;
  @override
  void initState() {
    super.initState();
    controller.addListener(_scroll);
  }

  void _scroll() {
    final next = (controller.offset / (width + 16)).round().clamp(
      0,
      widget.markets.length - 1,
    );
    if (next != active) setState(() => active = next);
  }

  void move(int index) {
    if (index < 0 || index >= widget.markets.length) return;
    controller.jumpTo(
      (index * (width + 16)).clamp(0, controller.position.maxScrollExtent),
    );
  }

  @override
  void dispose() {
    controller.removeListener(_scroll);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      width = ((box.maxWidth - MatchDiscoveryTokens.page * 2) * .88).clamp(
        0,
        340,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                      event.logicalKey == LogicalKeyboardKey.arrowLeft)) {
                move(
                  active +
                      (event.logicalKey == LogicalKeyboardKey.arrowRight
                          ? 1
                          : -1),
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: SingleChildScrollView(
              key: const PageStorageKey('featured-winner-picks'),
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: MatchDiscoveryTokens.page,
              ),
              child: EditorialEqualRow(
                itemWidth: width,
                gap: 16,
                children: [
                  for (var i = 0; i < widget.markets.length; i++)
                    EditorialMarketCard(
                      market: widget.markets[i],
                      featured: true,
                      onOpen: () => widget.onOpen(widget.markets[i].id),
                      onBuy: (outcome) => showPickTradeSheet(
                        context: context,
                        market: widget.markets[i],
                        outcome: outcome,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MatchDiscoveryTokens.carouselDotGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.markets.length; i++)
                Semantics(
                  label: 'Show featured Pick ${i + 1}',
                  selected: i == active,
                  button: true,
                  child: InkWell(
                    onTap: () => move(i),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 4,
                          color: i == active ? Cyber.cyan : Cyber.border,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
