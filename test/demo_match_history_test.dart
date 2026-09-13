import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/data/demo_match_history.dart';
import 'package:card_game/models/match.dart';
import 'package:card_game/models/player_stats.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  final demos = demoMatchHistory();

  test('every game mode has demo logs', () {
    const modes = ['match', 'shootout', 'grandprix', 'basketball', 'finalover',
        'tennis'];
    for (final mode in modes) {
      expect(
        demos.where((entry) => entry.mode == mode),
        isNotEmpty,
        reason: '$mode has no demo history',
      );
    }
    // No mode may exceed the bloc's per-mode retention cap, or a player's own
    // results would be pushed out by demo data.
    for (final mode in modes) {
      expect(demos.where((entry) => entry.mode == mode).length, lessThan(12));
    }
  });

  test('every sport tab of the archive has demo logs', () {
    for (final sport in [
      Sport.football,
      Sport.cricket,
      Sport.basketball,
      Sport.motorsport,
      Sport.tennis,
    ]) {
      expect(
        demos.where((entry) => entry.sport == sport),
        isNotEmpty,
        reason: '${sport.name} tab would render empty',
      );
    }
  });

  test('every result label the tiles can style is covered', () {
    final labels = demos.map((entry) => entry.resultLabel).toSet();
    expect(
      labels,
      containsAll(<String>[
        'Victory',
        'Defeat',
        'Draw',
        'Podium',
        'Points',
        'Finished',
        'Retired',
        'CHASE COMPLETE',
        'CHASE FAILED',
        'Completed',
        'Lesson Complete',
      ]),
    );
  });

  test('XP chip states and the legacy PEN badge are covered', () {
    expect(demos.any((entry) => (entry.xpEarned ?? 0) > 0), isTrue);
    expect(demos.any((entry) => entry.xpEarned == 0), isTrue);
    expect(demos.any((entry) => (entry.xpEarned ?? 0) < 0), isTrue);
    expect(demos.any((entry) => entry.xpEarned == null), isTrue);
    expect(demos.any((entry) => entry.penaltyPlayerScore != null), isTrue);
  });

  test('round logs cover every outcome stamp, both roles, and the empty state',
      () {
    final rounds = demos.expand((entry) => entry.rounds).toList();
    expect(
      rounds.map((round) => round.outcomeLabel).toSet(),
      containsAll(<String>[
        'Goal',
        'Saved',
        'Blocked',
        'Missed',
        'Foul',
        'Red Card',
      ]),
    );
    expect(rounds.any((round) => round.playerAttacking), isTrue);
    expect(rounds.any((round) => !round.playerAttacking), isTrue);
    expect(
      demos.any((entry) => entry.mode == 'match' && entry.rounds.isEmpty),
      isTrue,
      reason: 'the detail page "No round data." state is unreachable',
    );
  });

  test('Pitch Duel round logs agree with their scoreline', () {
    for (final entry in demos.where((e) => e.mode == 'match')) {
      if (entry.rounds.isEmpty) continue;
      var player = 0;
      var cpu = 0;
      for (final round in entry.rounds) {
        if (round.outcomeLabel != 'Goal') continue;
        if (round.playerAttacking) {
          player++;
        } else {
          cpu++;
        }
      }
      expect(player, entry.playerScore, reason: '${entry.id} player goals');
      expect(cpu, entry.opponentScore, reason: '${entry.id} opponent goals');
    }
  });

  test('ids are unique and namespaced so real results never collide', () {
    final ids = demos.map((entry) => entry.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => id.startsWith('demo-')), isTrue);
  });

  test('demo logs are flagged so achievements ignore them', () {
    expect(demos.every((entry) => entry.isDemo), isTrue);
    final real = MatchHistoryEntry(
      id: 'match-1758000000000000',
      deckName: 'Starter Squad',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: 'Victory',
      playerScore: 2,
      opponentScore: 1,
      rounds: const [],
    );
    expect(real.isDemo, isFalse);
    // The achievement snapshot measures the player's own results only.
    final career = MatchRecord.fromHistory(
      [...demos, real].where((entry) => !entry.isDemo).toList(),
    );
    expect(career.played, 1);
    expect(career.wins, 1);
  });

  test('demo logs survive a JSON round trip', () {
    for (final entry in demos) {
      final restored = MatchHistoryEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.mode, entry.mode);
      expect(restored.resultLabel, entry.resultLabel);
      expect(restored.rounds.length, entry.rounds.length);
      expect(DateTime.tryParse(restored.timestampIso), isNotNull);
    }
  });

  test('GameLoaded seeds the demo logs into match history', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.add(GameLoaded());
    await bloc.stream.firstWhere((state) => state.matchHistory.isNotEmpty);

    final seeded = bloc.state.matchHistory;
    for (final mode in [
      'match',
      'shootout',
      'grandprix',
      'basketball',
      'finalover',
      'tennis',
    ]) {
      expect(
        seeded.where((entry) => entry.mode == mode),
        isNotEmpty,
        reason: '$mode history is empty after load',
      );
    }
  });

  test('a stored result of the same id wins over its demo', () async {
    final storage = SecureGameStorage();
    final mine = MatchHistoryEntry(
      id: 'demo-match-victory',
      deckName: 'My Real Squad',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: 'Defeat',
      playerScore: 0,
      opponentScore: 2,
      rounds: const [],
    );
    await storage.saveMatchHistory([mine]);

    final bloc = GameBloc(storage);
    addTearDown(bloc.close);
    bloc.add(GameLoaded());
    await bloc.stream.firstWhere((state) => state.matchHistory.isNotEmpty);

    final kept = bloc.state.matchHistory
        .where((entry) => entry.id == 'demo-match-victory')
        .toList();
    expect(kept.length, 1);
    expect(kept.single.deckName, 'My Real Squad');
  });
}
