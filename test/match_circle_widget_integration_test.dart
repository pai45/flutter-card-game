import 'package:card_game/blocs/achievement/achievement_celebration_controller.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/match_circle/match_circle_cubit.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/predictions/match_circle_screen.dart';
import 'package:card_game/screens/predictions/match_detail_screen.dart';
import 'package:card_game/services/match_circle_repository.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/match_summary_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioController.instance.muted.value = true;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'pd_player_tag_v1': 'TEST-USER',
      'pd_selected_avatar_v1': 'rodri',
    });
  });

  testWidgets('screen renders the match header and seeded text-only feed', (
    tester,
  ) async {
    await _usePhoneSurface(tester);
    final circle = await _newCircleCubit();
    addTearDown(circle.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: circle,
        child: MaterialApp(home: MatchCircleScreen(match: _football)),
      ),
    );
    await _pumpUi(tester);

    expect(find.byKey(const ValueKey('match-circle-screen')), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
    expect(find.text('Argentina'), findsOneWidget);
    expect(
      find.text('Score predictions for France vs Argentina?'),
      findsOneWidget,
    );
    expect(find.text('Priyanshu'), findsOneWidget);
    expect(find.text('Jasper'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-circle-feed')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-circle-composer')), findsOneWidget);

    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate), findsNothing);
    expect(find.byIcon(Icons.image), findsNothing);
    expect(find.byIcon(Icons.share), findsNothing);
    expect(find.text('SHARE'), findsNothing);
  });

  testWidgets(
    'posting, liking, replying, editing, and tombstone deletion update the feed',
    (tester) async {
      await _usePhoneSurface(tester);
      var nextId = 0;
      final circle = await _newCircleCubit(
        idGenerator: () => 'test-post-${nextId++}',
      );
      addTearDown(circle.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: circle,
          child: MaterialApp(home: MatchCircleScreen(match: _football)),
        ),
      );
      await _pumpUi(tester);

      expect(circle.threadFor(_football)!.visibleCount, 3);

      await tester.enterText(
        find.byKey(const ValueKey('match-circle-composer-field')),
        '  My match take  ',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('match-circle-composer-send')),
      );
      await _pumpUi(tester);

      var thread = circle.threadFor(_football)!;
      final parent = thread.postById('test-post-0')!;
      expect(parent.text, 'My match take');
      expect(parent.author.displayName, 'PLAYER ONE');
      expect(thread.visibleCount, 4);
      expect(find.text('My match take'), findsOneWidget);

      final like = find.byKey(const ValueKey('match-circle-like-test-post-0'));
      await tester.ensureVisible(like);
      await tester.tap(like);
      await _pumpUi(tester);

      thread = circle.threadFor(_football)!;
      expect(thread.postById(parent.id)!.likes, 1);
      expect(thread.postById(parent.id)!.isLikedBy('player:TEST-USER'), isTrue);

      final reply = find.byKey(
        const ValueKey('match-circle-reply-test-post-0'),
      );
      await tester.ensureVisible(reply);
      await tester.tap(reply);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('match-circle-composer-mode')),
        findsOneWidget,
      );
      expect(find.text('REPLYING TO PLAYER ONE'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('match-circle-composer-field')),
        'A one-level reply',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('match-circle-composer-send')),
      );
      await _pumpUi(tester);

      thread = circle.threadFor(_football)!;
      final postedReply = thread.postById('test-post-1')!;
      expect(postedReply.parentId, parent.id);
      expect(thread.repliesFor(parent.id), [postedReply]);
      expect(find.text('A one-level reply'), findsOneWidget);

      await _openOwnedMenu(tester, parent.id);
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();
      expect(find.text('EDITING YOUR COMMENT'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('match-circle-composer-field')),
            )
            .controller!
            .text,
        'My match take',
      );

      await tester.enterText(
        find.byKey(const ValueKey('match-circle-composer-field')),
        'Edited match take',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('match-circle-composer-send')),
      );
      await _pumpUi(tester);

      thread = circle.threadFor(_football)!;
      expect(thread.postById(parent.id)!.text, 'Edited match take');
      expect(thread.postById(parent.id)!.isEdited, isTrue);
      expect(find.text('Edited match take'), findsOneWidget);
      expect(find.text('EDITED'), findsOneWidget);

      await _openOwnedMenu(tester, parent.id);
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(find.text('DELETE COMMENT?'), findsOneWidget);
      await tester.tap(find.text('DELETE >'));
      await _pumpUi(tester);

      thread = circle.threadFor(_football)!;
      expect(thread.postById(parent.id)!.isDeleted, isTrue);
      expect(thread.repliesFor(parent.id).single.text, 'A one-level reply');
      expect(thread.visibleCount, 4);
      expect(find.text('DELETED COMMENT'), findsOneWidget);
      expect(find.text('This comment was deleted.'), findsOneWidget);
      expect(find.text('A one-level reply'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-circle-reply-test-post-0')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Match Circle CTA stays below every detail tab and opens thread',
    (tester) async {
      await _usePhoneSurface(tester);
      final harness = await _pumpTabs(tester, match: _football);

      for (final label in const ['PREDICT', 'PICKS', 'TOPS', 'STATS']) {
        await tester.tap(find.text(label).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey('match-circle-cta')),
          findsOneWidget,
          reason: 'CTA should remain mounted on the $label tab',
        );
      }

      await tester.tap(find.byKey(const ValueKey('match-circle-cta')));
      await _pumpUi(tester);

      expect(find.byKey(const ValueKey('match-circle-screen')), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Argentina'), findsOneWidget);
      expect(harness.circle.threadFor(_football)!.matchId, _football.id);
      expect(
        find.text('Score predictions for France vs Argentina?'),
        findsOneWidget,
      );
    },
  );

  testWidgets('F1 tabs show Grand Prix header and open the F1 circle', (
    tester,
  ) async {
    await _usePhoneSurface(tester);
    final harness = await _pumpTabs(tester, match: _f1, embedded: true);

    expect(find.text('MONACO GRAND PRIX'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-circle-cta')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('match-circle-cta')));
    await _pumpUi(tester);

    expect(find.byKey(const ValueKey('match-circle-screen')), findsOneWidget);
    expect(find.text('MONACO GRAND PRIX'), findsOneWidget);
    expect(find.text('Who takes pole at Monaco Grand Prix?'), findsOneWidget);
    final thread = harness.circle.threadFor(_f1)!;
    expect(thread.sport, Sport.f1);
    expect(thread.matchId, _f1.id);
  });
}

Future<MatchCircleCubit> _newCircleCubit({
  String Function()? idGenerator,
}) async {
  final preferences = await SharedPreferences.getInstance();
  return MatchCircleCubit(
    LocalMatchCircleRepository(
      preferences: preferences,
      now: () => DateTime(2026, 7, 15, 12),
      idGenerator: idGenerator,
    ),
    SecureGameStorage(),
  );
}

Future<_TabsHarness> _pumpTabs(
  WidgetTester tester, {
  required SportMatch match,
  bool embedded = false,
}) async {
  final circle = await _newCircleCubit();
  final prediction = PredictionCubit(
    MockPredictionRepository(),
    SecureGameStorage(),
  );
  final picks = PicksCubit(MockPickRepository(), SecureGameStorage());
  final game = GameBloc(SecureGameStorage());
  await circle.ensureThread(match);

  addTearDown(circle.close);
  addTearDown(prediction.close);
  addTearDown(picks.close);
  addTearDown(game.close);

  final child = embedded
      ? Scaffold(
          body: SafeArea(
            child: MatchTabsView(
              match: match,
              headerBuilder: (value) => MatchSummaryHeader(match: value),
            ),
          ),
        )
      : MatchDetailScreen(match: match, refreshLiveScore: false);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<MatchCircleCubit>.value(value: circle),
        BlocProvider<PredictionCubit>.value(value: prediction),
        BlocProvider<PicksCubit>.value(value: picks),
        BlocProvider<GameBloc>.value(value: game),
        BlocProvider<AchievementCelebrationController>(
          create: (_) => AchievementCelebrationController(SecureGameStorage()),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await _pumpUi(tester);
  return _TabsHarness(circle: circle);
}

Future<void> _openOwnedMenu(WidgetTester tester, String postId) async {
  final menu = find.byKey(ValueKey('match-circle-menu-$postId'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

Future<void> _usePhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _TabsHarness {
  const _TabsHarness({required this.circle});

  final MatchCircleCubit circle;
}

const _france = SportTeam(
  id: 'fra',
  name: 'France',
  shortName: 'FRA',
  color: Color(0xff1d4ed8),
);

const _argentina = SportTeam(
  id: 'arg',
  name: 'Argentina',
  shortName: 'ARG',
  color: Color(0xff67b7e1),
);

final _football = SportMatch(
  id: 'world-cup-fra-arg',
  leagueId: 'world-cup',
  sport: Sport.football,
  home: _france,
  away: _argentina,
  kickoff: DateTime(2026, 7, 15, 15),
  status: MatchStatus.upcoming,
);

final _f1 = SportMatch(
  id: 'f1-monaco-2026',
  leagueId: 'formula-one',
  sport: Sport.f1,
  home: SportTeam(
    id: 'monaco-gp',
    name: 'Monaco Grand Prix',
    shortName: 'MON',
    color: Colors.cyan,
  ),
  away: SportTeam(
    id: 'f1-grid',
    name: 'Formula One Grid',
    shortName: 'F1',
    color: Colors.red,
  ),
  kickoff: DateTime(2026, 7, 19, 14),
  status: MatchStatus.upcoming,
);
