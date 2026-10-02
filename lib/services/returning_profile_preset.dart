import 'dart:convert';

import '../config/game_ladder.dart';
import '../config/enums.dart';
import '../data/football_bingo_puzzles.dart';
import '../data/guess_player_data.dart';
import '../data/basketball_teams.dart';
import '../data/final_over_kits.dart';
import '../data/grand_prix_liveries.dart';
import '../data/rival_roster.dart';
import '../models/avatar_frame_option.dart';
import '../models/avatar_option.dart';
import '../models/achievement.dart';
import '../models/basketball.dart';
import '../models/cards.dart';
import '../models/deck.dart';
import '../models/final_over.dart';
import '../models/football_bingo.dart';
import '../models/football_chess.dart';
import '../models/grand_prix.dart';
import '../models/guess_driver.dart';
import '../models/guess_player.dart';
import '../models/guess_winner.dart';
import '../models/match.dart';
import '../models/oz_coin_ledger.dart';
import '../models/picks.dart';
import '../models/player_stats.dart';
import '../models/prediction.dart';
import '../models/progression.dart';
import '../models/profile_banner_option.dart';
import '../models/quiz_trivia.dart';
import '../models/sport_match.dart';
import '../models/shop.dart';
import '../models/streak.dart';
import '../models/tennis.dart';
import '../models/unlock_progress.dart';
import '../models/xp_ledger.dart';
import 'pick_repository.dart';
import 'prediction_repository.dart';

const returningProfilePresetVersion = 1;
const returningProfileDisplayName = 'chiefpai45';

/// Fully serialized local-profile payload. Values still originate from the
/// domain models' `toJson` methods so the preset follows the same persistence
/// contracts as a career created through gameplay.
class ReturningProfilePreset {
  const ReturningProfilePreset({
    required this.secure,
    required this.preferences,
  });

  final Map<String, String> secure;
  final Map<String, dynamic> preferences;

  Map<String, dynamic> toSnapshot() => {
    'secure': secure,
    'preferences': preferences,
  };
}

Future<ReturningProfilePreset> buildReturningProfilePreset({
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final progression = PlayerProgression(
    xpByTrack: const {
      ProgressTrack.pitchDuel: 1200,
      ProgressTrack.shootout: 700,
      ProgressTrack.footballChess: 700,
      ProgressTrack.quiz: 1000,
      ProgressTrack.bingo: 600,
      ProgressTrack.guessPlayer: 900,
      ProgressTrack.finalOver: 850,
      ProgressTrack.hoopDuel: 850,
      ProgressTrack.grandPrix: 900,
      ProgressTrack.tennis: 900,
      ProgressTrack.prediction: 1700,
      ProgressTrack.cardsMeta: 950,
    },
  );
  final playerGroups = <List<PlayerCard>>[
    footballPlayerCards,
    cricketPlayerCards,
    basketballPlayerCards,
    racingPlayerCards,
    tennisPlayerCards,
  ];
  final topBySport = [for (final group in playerGroups) _topCards(group, 6)];
  final topActions = [...actionCards]
    ..sort((a, b) {
      final power = b.power.compareTo(a.power);
      return power != 0 ? power : a.id.compareTo(b.id);
    });
  final ownedPlayers = <String>{
    for (final cards in topBySport) ...cards.map((card) => card.id),
    ...defaultDeckSlots.first.attackers,
    ...defaultDeckSlots.first.defenders,
    ...defaultDeckSlots.first.finalOverBatsmen,
    defaultDeckSlots.first.keeper!,
  };
  final ownedActions = topActions.take(12).map((card) => card.id).toList();
  final basketballRoster =
      [
            PlayerRole.basketballGuard,
            PlayerRole.basketballWing,
            PlayerRole.basketballBig,
          ]
          .map(
            (role) => topBySport[2].firstWhere((card) => card.role == role).id,
          )
          .toList();
  final tennisRoster = topBySport[4].map((card) => card.id).toList();
  final racingRoster = topBySport[3].map((card) => card.id).toList();
  final deck = StoredDeckSlot(
    id: 'chief-xi',
    name: 'CHIEF XI',
    attackers: defaultDeckSlots.first.attackers,
    defenders: defaultDeckSlots.first.defenders,
    actions: ownedActions.take(6).toList(),
    keeper: defaultDeckSlots.first.keeper,
    finalOverBatsmen: defaultDeckSlots.first.finalOverBatsmen,
    basketballPlayers: basketballRoster,
    basketballStarter: basketballRoster.first,
    tennisPlayers: tennisRoster,
    tennisStarter: tennisRoster.first,
    racingPlayers: racingRoster,
    racingStarter: racingRoster.first,
    chessFormation: ChessFormation.box,
  );

  final history = _matchHistory(at);
  final quizzes = _knowledgeQuizProgress();
  final predictionActivity = await _predictionActivity(at);
  final predictions = predictionActivity.predictions;
  final predictionQuizzes = predictionActivity.quizzes;
  final picks = await _pickPositions(at);
  final streak = _sevenDayStreak(at);
  final unlocks = UnlockProgress(
    homeSport: Sport.football,
    unlockedSports: Sport.values.toSet(),
    ladderReached: {
      for (final entry in sportGameLadder.entries)
        entry.key: entry.value.length,
    },
    completedQuests: Sport.values.toSet(),
    processedIds: {
      for (final game in ArcadeGame.values) '${game.name}:preset-${game.name}',
    },
  );
  final xpLedger = _xpLedger(progression, at);
  final coinLedger = [
    OzCoinLedgerEntry(
      id: 'preset-opening-balance',
      timestamp: at.subtract(const Duration(days: 14)),
      delta: 5000,
      balanceAfter: 5000,
      type: OzCoinTransactionType.openingBalance,
      source: OzCoinTransactionSource.openingBalance,
      title: 'Veteran career balance',
      subtitle: 'RETURNING PROFILE PRESET',
    ),
  ];
  const cardBackIds = ['default', 'cyan-circuit', 'drift-violet', 'holo-foil'];
  const avatarIds = ['bellingham', 'rodri', 'raphinha', 'camavinga'];
  const bannerIds = ['south_africa', 'green_red', 'czech'];
  const frameIds = ['frame_liv', 'frame_rma', 'frame_mcl'];
  const finalOverKitIds = ['voltage', 'meridian', 'sovereign', 'obsidian'];
  const grandPrixLiveryIds = ['gridLine', 'papaya', 'racingGreen', 'midnight'];
  const basketballTeamIds = ['statoz', 'warriors', 'heat', 'celtics'];
  _requireCatalogIds(
    'card backs',
    cardBackIds,
    cardBacks.map((item) => item.id),
  );
  _requireCatalogIds(
    'avatars',
    avatarIds,
    avatarOptions.map((item) => item.id),
  );
  _requireCatalogIds(
    'banners',
    bannerIds,
    profileBannerOptions.map((item) => item.id),
  );
  _requireCatalogIds(
    'frames',
    frameIds,
    avatarFrameOptions.map((item) => item.id),
  );
  _requireCatalogIds(
    'Final Over kits',
    finalOverKitIds,
    finalOverKits.map((item) => item.id),
  );
  _requireCatalogIds(
    'Grand Prix liveries',
    grandPrixLiveryIds,
    grandPrixLiveries.map((item) => item.livery.name),
  );
  _requireCatalogIds(
    'basketball jerseys',
    basketballTeamIds,
    basketballTeams.map((item) => item.id),
  );
  final wallet = <String, dynamic>{
    'coins': 5000,
    'ownedCardIds': ownedPlayers.toList(),
    'ownedActionCardIds': ownedActions,
    'ownedCardBackIds': cardBackIds,
    'equippedCardBackId': 'cyan-circuit',
    'ownedAvatarFrameIds': frameIds,
    'equippedAvatarFrameId': 'frame_liv',
    'ownedAvatarIds': avatarIds,
    'ownedBannerIds': bannerIds,
    'ownedFinalOverKitIds': finalOverKitIds,
    'ownedGrandPrixLiveryIds': grandPrixLiveryIds,
    'ownedBasketballTeamIds': basketballTeamIds,
    'dailyDropLastClaimedAtMillis': null,
  };
  final matchRecord = MatchRecord.fromHistory(history);
  final wonPicks = picks
      .where((pick) => pick.status == PickPositionStatus.won)
      .length;
  final achievementStats = AchievementStats(
    level: progression.playerLevel,
    totalXP: progression.totalXP,
    matchesPlayed: matchRecord.played,
    matchWins: matchRecord.wins,
    bestMatchStreak: matchRecord.bestStreak,
    cleanSheets: matchRecord.cleanSheets,
    shootoutWins: matchRecord.shootoutWins,
    basketballWins: matchRecord.basketballWins,
    tennisAchievements: const {},
    predictionsMade: predictions.length,
    correctPredictions: predictions
        .where((prediction) => prediction.status == PredictionStatus.settled)
        .fold(0, (total, prediction) => total + (prediction.correctCount ?? 0)),
    picksPlaced: picks.length,
    picksWon: wonPicks,
    pickStreak: wonPicks,
    pickProfit: picks
        .where((pick) => pick.isFinal)
        .fold(0, (total, pick) => total + pick.realizedProfit),
    ownedCards: ownedPlayers.length + ownedActions.length,
    platinumOwned: ownedPlatinumCount(ownedPlayers.toList()),
    coins: 5000,
  );
  final celebratedAchievements = achievementCatalog
      .where((achievement) => achievement.unlocked(achievementStats))
      .map((achievement) => achievement.id)
      .toList();

  String encode(Object? value) => jsonEncode(value);
  final secure = <String, String>{
    'pd_display_name_v1': returningProfileDisplayName,
    'pd_onboarding_complete_v1': 'true',
    'pd_onboarding_reward_status_v1': 'seen',
    'pd_celebrated_achievements_v1': encode(celebratedAchievements),
    'pd_selected_avatar_v1': 'bellingham',
    'pd_selected_profile_banner_v1': 'south_africa',
    'pd_player_tag_v1': playerTagForName(returningProfileDisplayName),
    'pd_primary_sport_v1': Sport.football.name,
    'pd_followed_sports_v1': encode(Sport.values.map((s) => s.name).toList()),
    'pd_followed_leagues_v1': encode(['epl', 'ipl', 'nba', 'formula1', 'atp']),
    'pd_favorite_teams_v1': encode({
      'epl': 'liv',
      'ipl': 'rcb',
      'nba': 'gsw',
      'formula1': 'mcl',
      'atp': 'alcaraz',
    }),
    'pd_progression_v1': encode(progression.toJson()),
    'pd_deck_slots_v1': encode([deck.toJson()]),
    'pd_active_deck_id_v1': deck.id,
    'pd_owned_cards_v1': encode(ownedPlayers.toList()),
    'pd_match_history_v1': encode(history.map((e) => e.toJson()).toList()),
    'pd_starter_pack_claimed_v1': 'true',
    'pd_cricket_starter_pack_claimed_v1': 'true',
    'pd_basketball_starter_pack_claimed_v1': 'true',
    'pd_tennis_starter_pack_claimed_v1': 'true',
    'pd_grand_prix_starter_pack_claimed_v1': 'true',
    'pd_unlock_progress_v1': encode(unlocks.toJson()),
    'pd_daily_streak_v1': encode(streak.toJson()),
    'pd_predictions_v1': encode(predictions.map((e) => e.toJson()).toList()),
    'pd_prediction_quizzes_v1': encode(
      predictionQuizzes.map((e) => e.toJson()).toList(),
    ),
    'pd_pick_positions_v1': encode(picks.map((e) => e.toJson()).toList()),
    for (final sport in Sport.values)
      sport == Sport.football
          ? 'pd_quiz_progress_v1'
          : 'pd_quiz_progress_${sport.name}_v1': encode(
        quizzes.toJson(),
      ),
  };
  final preferences = <String, dynamic>{
    'pitch_duel_wallet': encode(wallet),
    'pd_xp_ledger_v1': encode(xpLedger.map((e) => e.toJson()).toList()),
    'pd_oz_coin_ledger_v1': encode(coinLedger.map((e) => e.toJson()).toList()),
    'pd_football_chess_stats_v1': encode(
      const FootballChessStats(
        wins: 1,
        losses: 1,
        draws: 1,
        bestStreak: 1,
      ).toJson(),
    ),
    'pd_grand_prix_stats_v1': encode(
      const GrandPrixStats(
        races: 3,
        wins: 1,
        podiums: 2,
        bestPosition: 1,
        bestStreak: 1,
        bestLapMsByCircuit: {'emeraldPark': 62418},
        lastLivery: GrandPrixLivery.papaya,
        lastLaps: 3,
      ).toJson(),
    ),
    'pd_basketball_stats_v1': encode(
      BasketballStats(
        games: 3,
        wins: 2,
        losses: 1,
        bestStreak: 2,
        mostPoints: 32,
        bestMargin: 7,
        totalDunks: 9,
        totalBlocks: 5,
        totalPerfects: 7,
        lastRosterIds: basketballRoster,
        lastStarterId: basketballRoster.first,
        hintsSeen: true,
        lastTeamId: 'warriors',
      ).toJson(),
    ),
    'pd_final_over_stats_v1': encode(
      const FinalOverStats(
        chases: 3,
        wins: 2,
        bestScore: 51,
        bestStars: 3,
        sixes: 11,
        fours: 15,
        bestCombo: 5,
        hintsSeen: true,
        kitId: 'meridian',
        tier: FinalOverTier.elite,
      ).toJson(),
    ),
    'pd_tennis_profile_v1': encode(
      TennisProfile(
        starterPackClaimed: true,
        ownedPlayerIds: tennisRoster,
        selectedPlayerId: tennisRoster.first,
        lastOpponentId: tennisRoster[1],
        setsPlayed: 3,
        setsWon: 2,
        bestWinStreak: 2,
        totalAces: 18,
        longestRally: 24,
        cleanHolds: 7,
        breaksConverted: 5,
        completedLessons: const {1, 2, 3},
        bestEndless: 1180,
        bestTarget: 640,
        settledMatchIds: const [
          'preset-tennis-1',
          'preset-tennis-2',
          'preset-tennis-3',
        ],
      ).toJson(),
    ),
    'pd_football_bingo_archive_v1': encode(_bingoArchive(at).toJson()),
    'pd_guess_player_archive_football_v2': encode(
      _guessPlayerArchive(
        Sport.football,
        footballGuessTimelines,
        footballPlayerCards,
        at,
      ).toJson(),
    ),
    'pd_guess_player_archive_cricket_v2': encode(
      _guessPlayerArchive(
        Sport.cricket,
        cricketGuessTimelines,
        cricketPlayerCards,
        at,
      ).toJson(),
    ),
    'pd_guess_player_archive_basketball_v2': encode(
      _guessPlayerArchive(
        Sport.basketball,
        basketballGuessTimelines,
        basketballPlayerCards,
        at,
      ).toJson(),
    ),
    'pd_guess_player_reward_settlements_v1': encode([
      for (final sport in [Sport.football, Sport.cricket, Sport.basketball])
        for (var i = 0; i < 3; i++)
          'guess-player:${sport.name}:${guessPlayerDayKey(DateTime(at.year, at.month, at.day - i))}',
    ]),
    'pd_guess_driver_archive_v1': encode(_guessDriverArchive(at).toJson()),
    'pd_tennis_guess_winner_archive_v1': encode(
      _guessWinnerArchive(at).toJson(),
    ),
  };
  return ReturningProfilePreset(secure: secure, preferences: preferences);
}

List<PlayerCard> _topCards(List<PlayerCard> cards, int count) {
  final sorted = [...cards]
    ..sort((a, b) {
      final rating = b.rating.compareTo(a.rating);
      return rating != 0 ? rating : a.id.compareTo(b.id);
    });
  return sorted.take(count).toList(growable: false);
}

void _requireCatalogIds(
  String label,
  Iterable<String> requested,
  Iterable<String> available,
) {
  final known = available.toSet();
  final missing = requested.where((id) => !known.contains(id)).toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'Unknown $label in returning preset: ${missing.join(', ')}',
    );
  }
}

List<MatchHistoryEntry> _matchHistory(DateTime now) {
  const modes = [
    'match',
    'shootout',
    'finalover',
    'basketball',
    'grandprix',
    'tennis',
  ];
  return [
    for (var modeIndex = 0; modeIndex < modes.length; modeIndex++)
      for (var attempt = 0; attempt < 3; attempt++)
        MatchHistoryEntry(
          id: 'preset-${modes[modeIndex]}-${attempt + 1}',
          mode: modes[modeIndex],
          deckName: modes[modeIndex] == 'match' ? 'CHIEF XI' : 'VETERAN RUN',
          timestampIso: now
              .subtract(
                Duration(days: attempt * 2 + modeIndex, hours: modeIndex),
              )
              .toIso8601String(),
          resultLabel: attempt == 1
              ? 'Defeat'
              : modes[modeIndex] == 'grandprix'
              ? 'Podium'
              : modes[modeIndex] == 'finalover'
              ? 'CHASE COMPLETE'
              : 'Victory',
          playerScore: modes[modeIndex] == 'grandprix'
              ? attempt + 1
              : 3 - attempt,
          opponentScore: modes[modeIndex] == 'grandprix' ? 20 : attempt + 1,
          xpEarned: 18 + modeIndex * 3 + attempt,
          rounds: const [],
        ),
  ];
}

QuizProgress _knowledgeQuizProgress() => QuizProgress({
  for (final mode in QuizMode.values)
    mode: QuizModeProgress(
      sets: {
        for (var set = 1; set <= 3; set++)
          set: QuizSetProgress(
            completed: true,
            bestCorrect: 10 - set,
            attempts: 1,
          ),
      },
    ),
});

List<String> _fixtureIdsFor(Sport sport) => switch (sport) {
  Sport.football => ['epl_mu_whu', 'epl_avl_bha', 'fifa_arg_jor'],
  Sport.cricket => ['ipl_pjk_rcb', 'ipl_csk_mi', 'ipl_mi_pjk'],
  Sport.basketball => ['401857080', '401857081', 'wnba_demo_dal_phx'],
  Sport.motorsport => ['f1_british_gp', 'f1_belgian_gp', 'f1_hungarian_gp'],
  Sport.tennis => [
    'wimbledon_mens_final_26',
    'wimbledon_womens_final_26',
    '178881',
  ],
};

Future<({List<UserPrediction> predictions, List<PredictionQuiz> quizzes})>
_predictionActivity(DateTime now) async {
  final repository = MockPredictionRepository();
  final fixtures = {
    for (final fixture in repository.seedFixtures) fixture.id: fixture,
  };
  final predictions = <UserPrediction>[];
  final quizzes = <PredictionQuiz>[];
  for (final sport in Sport.values) {
    final fixtureIds = _fixtureIdsFor(sport);
    for (var i = 0; i < fixtureIds.length; i++) {
      final fixtureId = fixtureIds[i];
      final fixture = fixtures[fixtureId];
      if (fixture == null || fixture.sport != sport) {
        throw StateError('Invalid $sport preset fixture: $fixtureId');
      }
      final catalogQuizzes = await repository.quizzesFor(fixtureId);
      if (catalogQuizzes.isEmpty || catalogQuizzes.first.questions.isEmpty) {
        throw StateError('No catalog quiz for preset fixture: $fixtureId');
      }
      final quiz = catalogQuizzes.first;
      quizzes.add(quiz);
      predictions.add(
        UserPrediction(
          matchId: fixtureId,
          quizId: quiz.id,
          answers: {for (final question in quiz.questions) question.id: 0},
          submittedAt: now.subtract(Duration(days: i + 1, hours: sport.index)),
          status: i == 2 ? PredictionStatus.open : PredictionStatus.settled,
          correctCount: i == 2 ? null : (i == 0 ? quiz.questions.length : 1),
          rewardEarned: i == 0
              ? quiz.questions.fold(
                  0,
                  (total, question) => total + question.reward,
                )
              : i == 1
              ? quiz.questions.first.reward
              : 0,
        ),
      );
    }
  }
  return (predictions: predictions, quizzes: quizzes);
}

Future<List<PickPosition>> _pickPositions(DateTime now) async {
  final markets = await MockPickRepository().markets();
  final positions = <PickPosition>[];
  for (final sport in Sport.values) {
    final pool = markets
        .where((market) => market.sport == sport)
        .take(3)
        .toList();
    if (pool.length != 3) {
      throw StateError('Expected three catalog pick markets for ${sport.name}');
    }
    for (var i = 0; i < pool.length; i++) {
      final market = pool[i];
      final outcome = market.outcomes.first;
      final stake = outcome.probabilityPercent;
      final status = i == 0
          ? PickPositionStatus.won
          : i == 1
          ? PickPositionStatus.lost
          : PickPositionStatus.pending;
      positions.add(
        PickPosition(
          id: 'preset-${sport.name}-pick-${i + 1}',
          marketId: market.id,
          marketQuestion: market.question,
          marketType: market.type,
          leagueLabel: market.leagueLabel,
          outcomeId: outcome.id,
          outcomeLabel: outcome.label,
          stakeOz: stake,
          shareCount: 1,
          averageProbabilityPercent: outcome.probabilityPercent.toDouble(),
          submittedAt: now.subtract(Duration(days: i + 1, hours: sport.index)),
          status: status,
          resolvedAt: status == PickPositionStatus.pending
              ? null
              : now.subtract(Duration(days: i)),
          payoutOz: status == PickPositionStatus.won ? 100 : 0,
          resultNote: status == PickPositionStatus.pending
              ? 'Market still open'
              : status == PickPositionStatus.won
              ? 'Veteran pick won'
              : 'Veteran pick lost',
        ),
      );
    }
  }
  return positions;
}

StreakSnapshot _sevenDayStreak(DateTime now) {
  final days = [
    for (var i = 6; i >= 0; i--)
      streakDayKey(DateTime(now.year, now.month, now.day - i)),
  ];
  return StreakSnapshot.fromJson({
    'activeDays': {
      'overall': days,
      'predict': days,
      'pick': days,
      'games': days,
      'pitchDuel': days,
      'penaltyShootout': days,
    },
    'activitiesByDay': {
      for (final day in days)
        day: ['predict', 'pick', 'pitchDuel', 'penaltyShootout', 'guessPlayer'],
    },
    'claimedMilestones': [3, 7],
    'announcedMilestones': [3, 7],
    'celebrationQueue': const [],
  });
}

List<XpLedgerEntry> _xpLedger(PlayerProgression progression, DateTime now) {
  final sourceForTrack = <ProgressTrack, XpTransactionSource>{
    ProgressTrack.pitchDuel: XpTransactionSource.match,
    ProgressTrack.shootout: XpTransactionSource.shootout,
    ProgressTrack.footballChess: XpTransactionSource.footballChess,
    ProgressTrack.quiz: XpTransactionSource.quiz,
    ProgressTrack.bingo: XpTransactionSource.bingo,
    ProgressTrack.guessPlayer: XpTransactionSource.guessPlayer,
    ProgressTrack.finalOver: XpTransactionSource.finalOver,
    ProgressTrack.hoopDuel: XpTransactionSource.basketball,
    ProgressTrack.grandPrix: XpTransactionSource.grandPrix,
    ProgressTrack.tennis: XpTransactionSource.tennis,
    ProgressTrack.prediction: XpTransactionSource.prediction,
    ProgressTrack.cardsMeta: XpTransactionSource.openingBalance,
  };
  var balance = 0;
  final chronological = <XpLedgerEntry>[];
  for (var i = 0; i < ProgressTrack.values.length; i++) {
    final track = ProgressTrack.values[i];
    final delta = progression.xpFor(track);
    balance += delta;
    chronological.add(
      XpLedgerEntry(
        id: 'preset-xp-${track.name}',
        timestamp: now.subtract(Duration(days: 13 - i)),
        delta: delta,
        balanceAfter: balance,
        type: XpTransactionType.openingBalance,
        source: sourceForTrack[track]!,
        title: '${track.displayLabel} career XP',
        details: 'RETURNING PROFILE PRESET',
      ),
    );
  }
  return chronological.reversed.toList();
}

FootballBingoArchive _bingoArchive(DateTime now) {
  final records = <String, FootballBingoProgress>{};
  for (var i = 0; i < 3; i++) {
    final day = DateTime(now.year, now.month, now.day - i);
    final puzzle = footballBingoPuzzles[i];
    records[footballBingoDayKey(day)] = FootballBingoProgress(
      puzzleId: puzzle.id,
      startedAt: day,
      solvedCellIds: puzzle.cells.map((cell) => cell.id).toList(),
      currentIndex: puzzle.cells.length,
      lifelines: 4,
      completed: true,
      cellOrderIds: puzzle.cells.map((cell) => cell.id).toList(),
      elapsedSeconds: 78 + i * 12,
    );
  }
  return FootballBingoArchive(
    firstUnlockDayKey: records.keys.last,
    progressByDay: records,
  );
}

GuessPlayerArchive _guessPlayerArchive(
  Sport sport,
  List<GuessPlayerTimeline> timelines,
  List<PlayerCard> players,
  DateTime now,
) {
  final repository = LocalGuessPlayerPuzzleRepository(
    sport: sport,
    timelines: timelines,
    players: players,
  );
  final records = <String, GuessPlayerDayRecord>{};
  for (var i = 0; i < 3; i++) {
    final day = DateTime(now.year, now.month, now.day - i);
    final dayKey = guessPlayerDayKey(day);
    final puzzle = repository.puzzleForDay(day);
    final target = players.firstWhere((player) => player.id == puzzle.playerId);
    final won = i != 1;
    records[dayKey] = GuessPlayerDayRecord(
      dayKey: dayKey,
      puzzleId: puzzle.id,
      playerId: target.id,
      targetPlayerName: target.name,
      status: won ? GuessPlayerResultStatus.won : GuessPlayerResultStatus.lost,
      guessedPlayerIds: [
        won
            ? target.id
            : players.firstWhere((player) => player.id != target.id).id,
      ],
      revealedClueCount: i + 2,
      attemptsRemaining: won ? 5 - i : 0,
      score: won ? 900 - i * 100 : 0,
      xpEarned: won ? 25 - i * 4 : 5,
      elapsedMs: 32000 + i * 7000,
      startedAtEpochMs: now
          .subtract(Duration(days: i, minutes: 2))
          .millisecondsSinceEpoch,
      completedAtEpochMs: now
          .subtract(Duration(days: i))
          .millisecondsSinceEpoch,
    );
  }
  return GuessPlayerArchive(resultsByDay: records);
}

GuessDriverArchive _guessDriverArchive(DateTime now) => GuessDriverArchive(
  resultsByDay: {
    for (var i = 0; i < 3; i++)
      streakDayKey(
        DateTime(now.year, now.month, now.day - i),
      ): GuessDriverDailyResult(
        won: i != 1,
        heartsRemaining: i == 1 ? 0 : 4 - i,
        targetDriverName: [
          'Lewis Hamilton',
          'Max Verstappen',
          'Lando Norris',
        ][i],
      ),
  },
);

GuessWinnerArchive _guessWinnerArchive(DateTime now) => GuessWinnerArchive(
  resultsByDay: {
    for (var i = 0; i < 3; i++)
      streakDayKey(
        DateTime(now.year, now.month, now.day - i),
      ): GuessWinnerDailyResult(
        won: i != 1,
        heartsRemaining: i == 1 ? 0 : 4 - i,
        targetWinnerName: [
          'Carlos Alcaraz',
          'Jannik Sinner',
          'Novak Djokovic',
        ][i],
      ),
  },
);
