import 'package:card_game/blocs/friends/friends_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/data/leaderboard_leagues.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/leaderboard/leaderboard_screen.dart';
import 'package:card_game/screens/leaderboard/widgets/league_dial.dart';
import 'package:card_game/screens/leaderboard/widgets/rank_board.dart';
import 'package:card_game/screens/profile/rival_profile_screen.dart';
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

  group('leaderboard league catalogue', () {
    test('every sport has leagues, and the first one is the default', () {
      const expectedDefaults = {
        Sport.football: 'EPL',
        Sport.cricket: 'IPL',
        Sport.basketball: 'NBA',
        Sport.motorsport: 'F1',
        Sport.tennis: 'ATP',
      };
      for (final sport in Sport.values) {
        final catalogue = leaderboardLeaguesFor(sport);
        expect(catalogue, isNotEmpty, reason: '${sport.name} has no leagues');
        expect(catalogue.first.shortCode, expectedDefaults[sport]);
        for (final league in catalogue) {
          expect(league.sport, sport);
          // A league with no clubs would divide by zero when badging rivals.
          expect(league.clubs, isNotEmpty, reason: league.shortCode);
        }
      }
    });

    test('league ids are unique across every sport', () {
      final ids = <String>[];
      for (final sport in Sport.values) {
        ids.addAll(leaderboardLeaguesFor(sport).map((l) => l.id));
      }
      expect(ids.toSet().length, ids.length);
    });

    test('leagueById resolves across sports', () {
      expect(leaderboardLeagueById('ipl')?.sport, Sport.cricket);
      expect(leaderboardLeagueById('nascar')?.shortCode, 'NASCAR');
      expect(leaderboardLeagueById('nope'), isNull);
    });
  });

  group('league dial on the players board', () {
    testWidgets('shows under PLAYERS only, defaulting to the first league', (
      tester,
    ) async {
      await _pumpLeaderboard(tester);

      // The board opens on TEAMS, which has no timeframe row and no dial.
      expect(find.byType(LeagueDial), findsNothing);

      await tester.tap(find.text('PLAYERS'));
      await tester.pumpAndSettle();

      expect(find.byType(LeagueDial), findsOneWidget);
      expect(
        _dial(tester).selectedId,
        leaderboardLeaguesFor(Sport.football).first.id,
      );
      // Shares the row with the remaining timeframe segments. Season is the
      // default now that the short-lived Weekly board has been removed.
      expect(find.text('WEEKLY'), findsNothing);
      expect(find.text('SEASON'), findsOneWidget);
      expect(find.text('ALL-TIME'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('wraps from the first league in both directions', (
      tester,
    ) async {
      await _pumpLeaderboard(tester);
      await tester.tap(find.text('PLAYERS'));
      await tester.pumpAndSettle();

      final firstLeague = _dial(tester).selectedId;
      await tester.drag(find.byType(LeagueDial), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(_dial(tester).selectedId, isNot(firstLeague));

      _dial(tester).onSelect(firstLeague);
      await tester.pumpAndSettle();
      expect(_dial(tester).selectedId, firstLeague);

      await tester.drag(find.byType(LeagueDial), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(_dial(tester).selectedId, isNot(firstLeague));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('spinning to another league re-ranks the board', (
      tester,
    ) async {
      await _pumpLeaderboard(tester);
      await tester.tap(find.text('PLAYERS'));
      await tester.pumpAndSettle();

      final before = _rowNames(tester);
      expect(before, isNotEmpty);
      final firstLeague = _dial(tester).selectedId;

      await _spinDial(tester);

      final after = _rowNames(tester);
      expect(_dial(tester).selectedId, isNot(firstLeague));
      expect(after, isNot(before), reason: 'league must re-rank the roster');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('scores descend with rank on every league', (tester) async {
      await _pumpLeaderboard(tester);
      await tester.tap(find.text('PLAYERS'));
      await tester.pumpAndSettle();

      final dial = _dial(tester);
      for (final league in leaderboardLeaguesFor(Sport.football)) {
        dial.onSelect(league.id);
        await tester.pumpAndSettle();
        final rows = tester.widgetList<RankRow>(find.byType(RankRow)).toList();
        for (var i = 1; i < rows.length; i++) {
          expect(
            rows[i].entry.score,
            lessThanOrEqualTo(rows[i - 1].entry.score),
            reason:
                '${league.shortCode}: #${rows[i].entry.rank} scores above '
                '#${rows[i - 1].entry.rank}',
          );
        }
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('each league gives the user a different standing', (
      tester,
    ) async {
      await _pumpLeaderboard(tester);
      await tester.tap(find.text('PLAYERS'));
      await tester.pumpAndSettle();

      final dial = _dial(tester);
      final ranks = <int>{};
      for (final league in leaderboardLeaguesFor(Sport.football)) {
        dial.onSelect(league.id);
        await tester.pumpAndSettle();
        ranks.add(
          tester.widget<RankUserBar>(find.byType(RankUserBar)).user.rank,
        );
      }
      expect(ranks.length, greaterThan(1));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rivals still carry a club badge and open their dossier', (
      tester,
    ) async {
      await _pumpLeaderboard(tester);
      await tester.tap(find.text('PLAYERS'));
      await tester.pumpAndSettle();

      final clubs = leaderboardLeaguesFor(Sport.football).first.clubs;
      final rows = tester.widgetList<RankRow>(find.byType(RankRow)).toList();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(clubs, contains(row.entry.subtitle));
        // A non-null `team` would make the row inert — the club must ride on
        // `subtitle` instead.
        expect(row.entry.team, isNull);
      }

      final rival = rows.firstWhere((row) => !row.entry.isUser);
      final rivalRow = find.text(rival.entry.name);
      await tester.ensureVisible(rivalRow);
      await tester.pumpAndSettle();
      await tester.tap(rivalRow);
      await tester.pumpAndSettle();
      expect(find.byType(RivalProfileScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}

// ── Harness ──────────────────────────────────────────────────────────────────

LeagueDial _dial(WidgetTester tester) =>
    tester.widget<LeagueDial>(find.byType(LeagueDial));

List<String> _rowNames(WidgetTester tester) => [
  for (final row in tester.widgetList<RankRow>(find.byType(RankRow)))
    row.entry.name,
];

/// Flicks the wheel one detent. The dial is a [ListWheelScrollView] laid on its
/// side, so drive it with a drag rather than a tap.
Future<void> _spinDial(WidgetTester tester) async {
  final start = _dial(tester).selectedId;
  for (final dx in [-64.0, 64.0]) {
    await tester.drag(find.byType(LeagueDial), Offset(dx, 0));
    await tester.pumpAndSettle();
    if (_dial(tester).selectedId != start) return;
  }
  fail('dragging the dial did not change the selected league');
}

Future<void> _pumpLeaderboard(WidgetTester tester) async {
  final gameBloc = GameBloc(SecureGameStorage());
  addTearDown(gameBloc.close);
  final cubit = _DialCubit(_DialRepo());
  addTearDown(cubit.close);
  // The rival dossier reached from a row builds against FriendsCubit.
  final friends = FriendsCubit(SecureGameStorage());
  addTearDown(friends.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<GameBloc>.value(value: gameBloc),
        BlocProvider<PredictionCubit>.value(value: cubit),
        BlocProvider<FriendsCubit>.value(value: friends),
      ],
      child: MaterialApp(home: LeaderboardScreen(onNavigate: (_) {})),
    ),
  );
  await tester.pumpAndSettle();
}

class _DialCubit extends PredictionCubit {
  _DialCubit(PredictionRepository repository)
    : super(repository, SecureGameStorage()) {
    emit(const PredictionState().copyWith(loading: false));
  }
}

class _DialRepo implements PredictionRepository {
  @override
  Future<List<League>> leagues() async => const [];

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
