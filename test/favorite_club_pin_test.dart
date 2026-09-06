import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/data/favorite_team_matcher.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/screens/predictions/widgets/match_prediction_card.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('team identity matching', () {
    test('resolves a catalogue favourite against ESPN-shaped fixture data', () {
      // EPL fixtures reach the app from live ESPN enrichment, where the team
      // carries a numeric id and ESPN's own naming — never the catalogue id.
      const espnCity = SportTeam(
        id: '382',
        name: 'Manchester City',
        shortName: 'MNC',
        color: Color(0xff6cabdd),
      );
      expect(teamMatchesFavorite(espnCity, 'epl', 'mc'), isTrue);
      expect(teamMatchesFavorite(espnCity, 'epl', 'mu'), isFalse);
    });

    test('matches on the raw catalogue id too', () {
      const mockLiverpool = SportTeam(
        id: 'liv',
        name: 'Liverpool',
        shortName: 'LFC',
        color: Color(0xffc8102e),
      );
      expect(teamMatchesFavorite(mockLiverpool, 'epl', 'liv'), isTrue);
    });

    test('favoriteSideOf reports the correct side', () {
      final match = _match('m1', home: _espnLiverpool, away: _espnArsenal);
      final side = favoriteSideOf(match, const {'epl': 'liv'});
      expect(side, isNotNull);
      expect(side!.isHome, isTrue);
      expect(side.teamId, 'liv');

      final awaySide = favoriteSideOf(
        _match('m2', home: _espnArsenal, away: _espnLiverpool),
        const {'epl': 'liv'},
      );
      expect(awaySide!.isHome, isFalse);
    });

    test('ignores a favourite belonging to another sport', () {
      final match = _match('m1', home: _espnLiverpool, away: _espnArsenal);
      // 'lal' is the NBA Lakers — a basketball favourite must never claim a
      // football fixture, however the name normalises.
      expect(favoriteSideOf(match, const {'nba': 'lal'}), isNull);
    });

    test('favoriteClubsForSport keeps only the sport in play', () {
      final clubs = favoriteClubsForSport(Sport.football, const {
        'epl': 'liv',
        'nba': 'lal',
      });
      expect(clubs.map((c) => c.teamId), ['liv']);
    });
  });

  group('YOUR CLUB pin', () {
    testWidgets('lifts the club fixture above the rest of the day', (
      tester,
    ) async {
      final cubit = _PinCubit(_PinRepo());
      addTearDown(cubit.close);
      cubit.seed(_dayFixtures(), favoriteTeams: const {'epl': 'liv'});

      await _pumpHome(tester, cubit);

      // The pin header names the club; the card itself carries no badge.
      expect(find.text('YOUR CLUB · LIVERPOOL'), findsOneWidget);
      expect(find.text('YOUR CLUB'), findsNothing);

      final cards = tester
          .widgetList<MatchPredictionCard>(find.byType(MatchPredictionCard))
          .toList();
      expect(cards.first.match.id, 'liv-ars');
      expect(cards.first.favorite, isNotNull);

      // Pinned once, never duplicated back into its league group.
      expect(cards.where((c) => c.match.id == 'liv-ars'), hasLength(1));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('marks the club fixture wherever it renders', (tester) async {
      final cubit = _PinCubit(_PinRepo());
      addTearDown(cubit.close);
      // Two club fixtures on the day: one takes the pin, the other stays in the
      // league list and must still carry the marker.
      cubit.seed([
        ..._dayFixtures(),
        _match('liv-cfc', home: _espnChelsea, away: _espnLiverpool, hour: 21),
      ], favoriteTeams: const {'epl': 'liv'});

      await _pumpHome(tester, cubit);

      final marked = tester
          .widgetList<MatchPredictionCard>(find.byType(MatchPredictionCard))
          .where((card) => card.favorite != null)
          .map((card) => card.match.id)
          .toSet();
      expect(marked, {'liv-ars', 'liv-cfc'});

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no favourite club leaves the feed untouched', (tester) async {
      final cubit = _PinCubit(_PinRepo());
      addTearDown(cubit.close);
      cubit.seed(_dayFixtures());

      await _pumpHome(tester, cubit);

      expect(find.textContaining('YOUR CLUB'), findsNothing);
      final cards = tester
          .widgetList<MatchPredictionCard>(find.byType(MatchPredictionCard))
          .toList();
      // Only the on-screen slice of the ListView is built, so assert the
      // leading order: repository order, with nothing hoisted.
      expect(cards.map((c) => c.match.id).take(2), ['cfc-new', 'liv-ars']);
      expect(cards.every((c) => c.favorite == null), isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });
}

// ── Harness ──────────────────────────────────────────────────────────────────

class _PinCubit extends PredictionCubit {
  _PinCubit(PredictionRepository repository)
    : super(repository, SecureGameStorage());

  void seed(
    List<SportMatch> fixtures, {
    Map<String, String> favoriteTeams = const {},
  }) {
    emit(
      const PredictionState().copyWith(
        loading: false,
        leagues: const [_epl],
        fixtures: fixtures,
        favoriteTeams: favoriteTeams,
        followedLeagueIds: favoriteTeams.keys.toList(),
      ),
    );
  }
}

class _PinRepo implements PredictionRepository {
  @override
  Future<List<League>> leagues() async => const [_epl];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async =>
      const [];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(
    List<SportMatch> fixtures,
    Sport sport,
  ) async => fixtures;

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async => const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async => null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async => null;

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => const [];
}

Future<void> _pumpHome(WidgetTester tester, PredictionCubit cubit) async {
  final gameBloc = GameBloc(SecureGameStorage());
  addTearDown(gameBloc.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<GameBloc>.value(value: gameBloc),
        BlocProvider<PredictionCubit>.value(value: cubit),
      ],
      child: MaterialApp(
        home: PredictionHomeScreen(
          activeTab: 0,
          onTabChanged: (_) {},
          // 1 = the football sport tab (see sportTabOrder).
          activeMatchSportTab: 1,
          onMatchSportTabChanged: (_) {},
          activeGamesSportTab: 0,
          onGamesSportTabChanged: (_) {},
          onNavigate: (_) {},
          onOpenMatch: (_) {},
          onOpenMarket: (_) {},
          onOpenLeague: (_) {},
          onOpenLeagueGames: (_) {},
          onOpenGame: () {},
          onOpenShootout: () {},
          onOpenQuiz: (_) {},
          onOpenFootballBingo: () {},
          onOpenFootballChess: () {},
          onOpenGuessPlayer: () {},
          onOpenGrandPrix: () {},
          onOpenF1GuessDriver: () {},
          onOpenTennisGuessWinner: () {},
          onOpenBasketball: () {},
          onOpenBasketballGuessPlayer: () {},
          onOpenCricketGuessPlayer: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

const _epl = League(
  id: 'epl',
  name: 'English Premier League',
  shortCode: 'EPL',
  accent: Color(0xffa855f7),
);

// ESPN-shaped teams: numeric ids, ESPN naming — exactly what the live feed
// hands the match list for the Premier League.
const _espnLiverpool = SportTeam(
  id: '364',
  name: 'Liverpool',
  shortName: 'LIV',
  color: Color(0xffc8102e),
);
const _espnArsenal = SportTeam(
  id: '359',
  name: 'Arsenal',
  shortName: 'ARS',
  color: Color(0xffef0107),
);
const _espnChelsea = SportTeam(
  id: '363',
  name: 'Chelsea',
  shortName: 'CHE',
  color: Color(0xff1f4fd6),
);
const _espnNewcastle = SportTeam(
  id: '361',
  name: 'Newcastle United',
  shortName: 'NEW',
  color: Color(0xff241f20),
);
const _espnWestHam = SportTeam(
  id: '371',
  name: 'West Ham United',
  shortName: 'WHU',
  color: Color(0xff7a263a),
);
const _espnVilla = SportTeam(
  id: '362',
  name: 'Aston Villa',
  shortName: 'AVL',
  color: Color(0xff95bfe5),
);

SportMatch _match(
  String id, {
  required SportTeam home,
  required SportTeam away,
  int hour = 18,
}) {
  final now = DateTime.now();
  return SportMatch(
    id: id,
    leagueId: _epl.id,
    sport: Sport.football,
    home: home,
    away: away,
    kickoff: DateTime(now.year, now.month, now.day, hour),
    status: MatchStatus.upcoming,
  );
}

/// Three fixtures on today's card, with the club's game deliberately seeded in
/// the middle so a passing test cannot be an accident of insertion order.
List<SportMatch> _dayFixtures() => [
  _match('cfc-new', home: _espnChelsea, away: _espnNewcastle, hour: 17),
  _match('liv-ars', home: _espnLiverpool, away: _espnArsenal, hour: 18),
  _match('whu-avl', home: _espnWestHam, away: _espnVilla, hour: 19),
];
