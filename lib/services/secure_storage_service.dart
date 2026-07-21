import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sport_match.dart';
import '../models/basketball.dart';
import '../models/final_over.dart';
import '../models/deck.dart';
import '../models/football_bingo.dart';
import '../models/football_chess.dart';
import '../models/grand_prix.dart';
import '../models/match.dart';
import '../models/oz_coin_ledger.dart';
import '../models/picks.dart';
import '../models/prediction.dart';
import '../models/progression.dart';
import '../models/quiz_trivia.dart';
import '../models/referral.dart';
import '../models/streak.dart';
import '../models/tennis.dart';
import '../models/xp_ledger.dart';
import '../models/guess_player.dart';
import '../models/guess_driver.dart';
import '../models/guess_winner.dart';
import '../data/final_over_kits.dart';
import '../data/grand_prix_liveries.dart';
import '../data/rival_roster.dart' show randomPlayerTag;

/// Maps a legacy `border_*` avatar-frame id to the renamed `frame_*` form so a
/// player's pre-rename owned/equipped frames keep resolving after the migration.
String _migrateFrameId(String id) =>
    id.startsWith('border_') ? id.replaceFirst('border_', 'frame_') : id;

class WalletSnapshot {
  const WalletSnapshot({
    required this.coins,
    required this.ownedCardIds,
    required this.ownedActionCardIds,
    required this.ownedCardBackIds,
    required this.equippedCardBackId,
    required this.ownedAvatarFrameIds,
    required this.equippedAvatarFrameId,
    required this.ownedAvatarIds,
    required this.ownedBannerIds,
    required this.ownedFinalOverKitIds,
    required this.ownedGrandPrixLiveryIds,
    required this.dailyDropLastClaimedAtMillis,
  });

  factory WalletSnapshot.initial() => WalletSnapshot(
    coins: 0,
    ownedCardIds: const [],
    ownedActionCardIds: const [],
    ownedCardBackIds: const ['default'],
    equippedCardBackId: 'default',
    ownedAvatarFrameIds: const [],
    equippedAvatarFrameId: '',
    ownedAvatarIds: const [],
    ownedBannerIds: const [],
    ownedFinalOverKitIds: defaultOwnedFinalOverKitIds(),
    ownedGrandPrixLiveryIds: defaultOwnedGrandPrixLiveryIds(),
    dailyDropLastClaimedAtMillis: null,
  );

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) => WalletSnapshot(
    coins: json['coins'] as int? ?? 0,
    ownedCardIds: List<String>.from(json['ownedCardIds'] as List? ?? const []),
    ownedActionCardIds: List<String>.from(
      json['ownedActionCardIds'] as List? ?? const [],
    ),
    ownedCardBackIds: List<String>.from(
      json['ownedCardBackIds'] as List? ?? const ['default'],
    ),
    equippedCardBackId: json['equippedCardBackId'] as String? ?? 'default',
    // Reads the new keys, falling back to the legacy `*Border*` keys, and
    // migrates legacy `border_*` ids to the `frame_*` form (rename safety net).
    ownedAvatarFrameIds: List<String>.from(
      json['ownedAvatarFrameIds'] as List? ??
          json['ownedAvatarBorderIds'] as List? ??
          const [],
    ).map(_migrateFrameId).toList(),
    equippedAvatarFrameId: _migrateFrameId(
      json['equippedAvatarFrameId'] as String? ??
          json['equippedAvatarBorderId'] as String? ??
          '',
    ),
    ownedAvatarIds: List<String>.from(
      json['ownedAvatarIds'] as List? ?? const [],
    ),
    ownedBannerIds: List<String>.from(
      json['ownedBannerIds'] as List? ?? const [],
    ),
    ownedFinalOverKitIds: normalizeOwnedFinalOverKitIds(
      List<String>.from(json['ownedFinalOverKitIds'] as List? ?? const []),
    ),
    ownedGrandPrixLiveryIds: normalizeOwnedGrandPrixLiveryIds(
      List<String>.from(json['ownedGrandPrixLiveryIds'] as List? ?? const []),
    ),
    dailyDropLastClaimedAtMillis: json['dailyDropLastClaimedAtMillis'] as int?,
  );

  final int coins;
  final List<String> ownedCardIds;
  final List<String> ownedActionCardIds;
  final List<String> ownedCardBackIds;
  final String equippedCardBackId;
  final List<String> ownedAvatarFrameIds;
  final String equippedAvatarFrameId;
  final List<String> ownedAvatarIds;
  final List<String> ownedBannerIds;
  final List<String> ownedFinalOverKitIds;
  final List<String> ownedGrandPrixLiveryIds;
  final int? dailyDropLastClaimedAtMillis;

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'ownedCardIds': ownedCardIds,
    'ownedActionCardIds': ownedActionCardIds,
    'ownedCardBackIds': ownedCardBackIds,
    'equippedCardBackId': equippedCardBackId,
    'ownedAvatarFrameIds': ownedAvatarFrameIds,
    'equippedAvatarFrameId': equippedAvatarFrameId,
    'ownedAvatarIds': ownedAvatarIds,
    'ownedBannerIds': ownedBannerIds,
    'ownedFinalOverKitIds': ownedFinalOverKitIds,
    'ownedGrandPrixLiveryIds': ownedGrandPrixLiveryIds,
    'dailyDropLastClaimedAtMillis': dailyDropLastClaimedAtMillis,
  };
}

class SecureGameStorage {
  SecureGameStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deckKey = 'pd_deck_slots_v1';
  static const _tutorialKey = 'pd_tutorial_seen_v1';
  static const _ownedCardsKey = 'pd_owned_cards_v1';
  static const _historyKey = 'pd_match_history_v1';
  static const _starterPackClaimedKey = 'pd_starter_pack_claimed_v1';
  static const _cricketStarterPackClaimedKey =
      'pd_cricket_starter_pack_claimed_v1';
  static const _basketballStarterPackClaimedKey =
      'pd_basketball_starter_pack_claimed_v1';
  static const _tennisStarterPackClaimedKey =
      'pd_tennis_starter_pack_claimed_v1';
  static const _grandPrixStarterPackClaimedKey =
      'pd_grand_prix_starter_pack_claimed_v1';
  static const _progressionKey = 'pd_progression_v1';
  static const _walletKey = 'pitch_duel_wallet';
  static const _coinLedgerKey = 'pd_oz_coin_ledger_v1';
  static const _xpLedgerKey = 'pd_xp_ledger_v1';
  static const _predictionsKey = 'pd_predictions_v1';
  static const _pickPositionsKey = 'pd_pick_positions_v1';
  static const _selectedAvatarKey = 'pd_selected_avatar_v1';
  static const _selectedProfileBannerKey = 'pd_selected_profile_banner_v1';
  static const _primarySportKey = 'pd_primary_sport_v1';
  static const _selectedTimeZoneKey = 'pd_selected_time_zone_v1';
  static const _followedLeaguesKey = 'pd_followed_leagues_v1';
  static const _favoriteTeamsKey = 'pd_favorite_teams_v1';
  static const _onboardingCompleteKey = 'pd_onboarding_complete_v1';
  static const _demoRewardSettlementSeenKey =
      'pd_demo_reward_settlement_seen_v1';
  static const _celebratedAchievementsKey = 'pd_celebrated_achievements_v1';
  static const _streakKey = 'pd_daily_streak_v1';
  static const _friendsKey = 'pd_friends_v1';
  static const _playerTagKey = 'pd_player_tag_v1';
  static const _referralEntriesKey = 'pd_referral_entries_v1';
  static const _rolloverLastDayKey = 'pd_rollover_last_day_v1';
  String _quizProgressKey(Sport sport) => sport == Sport.football
      ? 'pd_quiz_progress_v1'
      : 'pd_quiz_progress_${sport.name}_v1';
  static const _footballBingoProgressKey = 'pd_football_bingo_progress_v1';
  static const _footballBingoArchiveKey = 'pd_football_bingo_archive_v1';
  String _guessPlayerArchiveKey(Sport sport) =>
      'pd_guess_player_archive_${sport.name}_v1';
  String _guessPlayerArchiveV2Key(Sport sport) =>
      'pd_guess_player_archive_${sport.name}_v2';
  static const _guessPlayerSettlementKey =
      'pd_guess_player_reward_settlements_v1';
  static const _guessDriverArchiveKey = 'pd_guess_driver_archive_v1';
  static const _tennisGuessWinnerArchiveKey =
      'pd_tennis_guess_winner_archive_v1';
  static const _footballChessStatsKey = 'pd_football_chess_stats_v1';
  static const _grandPrixStatsKey = 'pd_grand_prix_stats_v1';
  static const _basketballStatsKey = 'pd_basketball_stats_v1';
  static const _finalOverStatsKey = 'pd_final_over_stats_v1';
  static const _tennisProfileKey = 'pd_tennis_profile_v1';
  static const _tennisResumeKey = 'pd_tennis_resume_v1';
  static const _tennisSettlementKey = 'pd_tennis_settlements_v1';

  final FlutterSecureStorage _storage;

  Future<List<StoredDeckSlot>> loadDecks() async {
    try {
      final raw = await _storage.read(key: _deckKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data.map((item) => StoredDeckSlot.fromJson(item)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDecks(List<StoredDeckSlot> decks) async {
    await _storage.write(
      key: _deckKey,
      value: jsonEncode(decks.map((deck) => deck.toJson()).toList()),
    );
  }

  Future<Set<String>> loadTutorialSeen() async {
    try {
      final raw = await _storage.read(key: _tutorialKey);
      if (raw == null || raw.isEmpty) return {};
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTutorialSeen(Set<String> seen) async {
    await _storage.write(key: _tutorialKey, value: jsonEncode(seen.toList()));
  }

  Future<void> resetTutorial() => _storage.delete(key: _tutorialKey);

  Future<List<String>> loadOwnedCards() async {
    try {
      final raw = await _storage.read(key: _ownedCardsKey);
      if (raw == null || raw.isEmpty) return const [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveOwnedCards(List<String> cardIds) async {
    await _storage.write(key: _ownedCardsKey, value: jsonEncode(cardIds));
  }

  Future<bool> loadStarterPackClaimed() async {
    try {
      final raw = await _storage.read(key: _starterPackClaimedKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveStarterPackClaimed() async {
    await _storage.write(key: _starterPackClaimedKey, value: 'true');
  }

  Future<bool> loadCricketStarterPackClaimed() async {
    try {
      final raw = await _storage.read(key: _cricketStarterPackClaimedKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCricketStarterPackClaimed() async {
    await _storage.write(key: _cricketStarterPackClaimedKey, value: 'true');
  }

  Future<bool> loadBasketballStarterPackClaimed() async {
    try {
      final raw = await _storage.read(key: _basketballStarterPackClaimedKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveBasketballStarterPackClaimed() async {
    await _storage.write(key: _basketballStarterPackClaimedKey, value: 'true');
  }

  Future<bool> loadTennisStarterPackClaimed() async {
    try {
      final raw = await _storage.read(key: _tennisStarterPackClaimedKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveTennisStarterPackClaimed() async {
    await _storage.write(key: _tennisStarterPackClaimedKey, value: 'true');
  }

  Future<bool> loadGrandPrixStarterPackClaimed() async {
    try {
      final raw = await _storage.read(key: _grandPrixStarterPackClaimedKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveGrandPrixStarterPackClaimed() async {
    await _storage.write(key: _grandPrixStarterPackClaimedKey, value: 'true');
  }

  Future<List<MatchHistoryEntry>> loadMatchHistory() async {
    try {
      final raw = await _storage.read(key: _historyKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data
          .map(
            (item) =>
                MatchHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveMatchHistory(List<MatchHistoryEntry> history) async {
    await _storage.write(
      key: _historyKey,
      value: jsonEncode(history.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<WalletSnapshot> loadWallet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_walletKey);
      if (raw == null || raw.isEmpty) return WalletSnapshot.initial();
      return WalletSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return WalletSnapshot.initial();
    }
  }

  Future<void> saveWallet(WalletSnapshot wallet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_walletKey, jsonEncode(wallet.toJson()));
  }

  Future<List<OzCoinLedgerEntry>> loadCoinLedger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_coinLedgerKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data
          .map(
            (item) =>
                OzCoinLedgerEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCoinLedger(List<OzCoinLedgerEntry> ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _coinLedgerKey,
      jsonEncode(ledger.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<List<XpLedgerEntry>> loadXpLedger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_xpLedgerKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data
          .map(
            (item) => XpLedgerEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveXpLedger(List<XpLedgerEntry> ledger) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _xpLedgerKey,
      jsonEncode(ledger.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<FootballBingoProgress?> loadFootballBingoProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_footballBingoProgressKey);
      if (raw == null || raw.isEmpty) return null;
      return FootballBingoProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFootballBingoProgress(FootballBingoProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _footballBingoProgressKey,
      jsonEncode(progress.toJson()),
    );
  }

  Future<FootballBingoArchive?> loadFootballBingoArchive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_footballBingoArchiveKey);
      if (raw == null || raw.isEmpty) return null;
      return FootballBingoArchive.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFootballBingoArchive(FootballBingoArchive archive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _footballBingoArchiveKey,
      jsonEncode(archive.toJson()),
    );
  }

  Future<GuessDriverArchive?> loadGuessDriverArchive() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_guessDriverArchiveKey);
      if (raw == null) return null;
      return GuessDriverArchive.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGuessDriverArchive(GuessDriverArchive archive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guessDriverArchiveKey, jsonEncode(archive.toJson()));
  }

  Future<GuessWinnerArchive?> loadTennisGuessWinnerArchive() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_tennisGuessWinnerArchiveKey);
      if (raw == null) return null;
      return GuessWinnerArchive.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTennisGuessWinnerArchive(GuessWinnerArchive archive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tennisGuessWinnerArchiveKey,
      jsonEncode(archive.toJson()),
    );
  }

  Future<GuessPlayerArchive?> loadGuessPlayerArchive(Sport sport) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw =
          prefs.getString(_guessPlayerArchiveV2Key(sport)) ??
          prefs.getString(_guessPlayerArchiveKey(sport));
      if (raw == null) return null;
      return GuessPlayerArchive.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGuessPlayerArchive(
    Sport sport,
    GuessPlayerArchive archive,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _guessPlayerArchiveV2Key(sport),
      jsonEncode(archive.toJson()),
    );
    if (!saved) {
      throw StateError('Could not persist Guess Player archive.');
    }
  }

  Future<Set<String>> loadGuessPlayerSettlementIds() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_guessPlayerSettlementKey);
      if (raw == null || raw.isEmpty) return <String>{};
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveGuessPlayerSettlementIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _guessPlayerSettlementKey,
      jsonEncode(ids.toList()..sort()),
    );
    if (!saved) {
      throw StateError('Could not persist Guess Player settlement.');
    }
  }

  Future<FootballChessStats> loadFootballChessStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_footballChessStatsKey);
      if (raw == null || raw.isEmpty) return const FootballChessStats();
      return FootballChessStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const FootballChessStats();
    }
  }

  Future<void> saveFootballChessStats(FootballChessStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_footballChessStatsKey, jsonEncode(stats.toJson()));
  }

  Future<GrandPrixStats> loadGrandPrixStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_grandPrixStatsKey);
      if (raw == null || raw.isEmpty) return const GrandPrixStats();
      return GrandPrixStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const GrandPrixStats();
    }
  }

  Future<void> saveGrandPrixStats(GrandPrixStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_grandPrixStatsKey, jsonEncode(stats.toJson()));
  }

  Future<List<UserPrediction>> loadPredictions() async {
    try {
      final raw = await _storage.read(key: _predictionsKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data
          .map(
            (item) => UserPrediction.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePredictions(List<UserPrediction> predictions) async {
    await _storage.write(
      key: _predictionsKey,
      value: jsonEncode(predictions.map((p) => p.toJson()).toList()),
    );
  }

  Future<List<PickPosition>> loadPickPositions() async {
    try {
      final raw = await _storage.read(key: _pickPositionsKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data
          .map((item) => PickPosition.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePickPositions(List<PickPosition> positions) async {
    await _storage.write(
      key: _pickPositionsKey,
      value: jsonEncode(positions.map((p) => p.toJson()).toList()),
    );
  }

  Future<String?> loadRolloverLastDayKey() async {
    try {
      final raw = await _storage.read(key: _rolloverLastDayKey);
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRolloverLastDayKey(String dayKey) async {
    await _storage.write(key: _rolloverLastDayKey, value: dayKey);
  }

  Future<String?> loadSelectedAvatarId() async {
    try {
      final raw = await _storage.read(key: _selectedAvatarKey);
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedAvatarId(String avatarId) async {
    await _storage.write(key: _selectedAvatarKey, value: avatarId);
  }

  Future<String?> loadSelectedProfileBannerId() async {
    try {
      final raw = await _storage.read(key: _selectedProfileBannerKey);
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedProfileBannerId(String bannerId) async {
    await _storage.write(key: _selectedProfileBannerKey, value: bannerId);
  }

  Future<String?> loadPrimarySportName() async {
    try {
      final raw = await _storage.read(key: _primarySportKey);
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePrimarySportName(String sportName) async {
    await _storage.write(key: _primarySportKey, value: sportName);
  }

  Future<String?> loadSelectedTimeZoneId() async {
    try {
      final raw = await _storage.read(key: _selectedTimeZoneKey);
      return raw == null || raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSelectedTimeZoneId(String timeZoneId) async {
    await _storage.write(key: _selectedTimeZoneKey, value: timeZoneId);
  }

  Future<List<String>> loadFollowedLeagueIds() async {
    try {
      final raw = await _storage.read(key: _followedLeaguesKey);
      if (raw == null || raw.isEmpty) return const [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveFollowedLeagueIds(List<String> leagueIds) async {
    await _storage.write(
      key: _followedLeaguesKey,
      value: jsonEncode(leagueIds),
    );
  }

  /// The rivals the player has added as friends, by leaderboard display name.
  Future<List<String>> loadFriends() async {
    try {
      final raw = await _storage.read(key: _friendsKey);
      if (raw == null || raw.isEmpty) return const [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveFriends(List<String> friendNames) async {
    await _storage.write(key: _friendsKey, value: jsonEncode(friendNames));
  }

  /// The player's own shareable tag (e.g. `PL4Y-X7K9`). Generated once on first
  /// view and persisted so it stays stable across sessions.
  Future<String?> loadPlayerTag() async {
    try {
      final raw = await _storage.read(key: _playerTagKey);
      if (raw == null || raw.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlayerTag(String tag) async {
    await _storage.write(key: _playerTagKey, value: tag);
  }

  Future<String> loadOrCreatePlayerTag() async {
    final existing = await loadPlayerTag();
    if (existing != null) return existing;
    final tag = randomPlayerTag();
    await savePlayerTag(tag);
    return tag;
  }

  /// Returns `null` until the frontend referral demo has been seeded.
  Future<List<ReferralEntry>?> loadReferralEntries() async {
    try {
      final raw = await _storage.read(key: _referralEntriesKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw) as List;
      return data
          .map(
            (item) =>
                ReferralEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReferralEntries(List<ReferralEntry> entries) async {
    await _storage.write(
      key: _referralEntriesKey,
      value: jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  /// Favourite team per league as a leagueId → teamId map.
  Future<Map<String, String>> loadFavoriteTeams() async {
    try {
      final raw = await _storage.read(key: _favoriteTeamsKey);
      if (raw == null || raw.isEmpty) return const {};
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveFavoriteTeams(Map<String, String> teams) async {
    await _storage.write(key: _favoriteTeamsKey, value: jsonEncode(teams));
  }

  Future<bool> loadOnboardingComplete() async {
    try {
      final raw = await _storage.read(key: _onboardingCompleteKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveOnboardingComplete(bool complete) async {
    await _storage.write(
      key: _onboardingCompleteKey,
      value: complete ? 'true' : 'false',
    );
  }

  Future<bool> loadDemoRewardSettlementSeen() async {
    try {
      final raw = await _storage.read(key: _demoRewardSettlementSeenKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveDemoRewardSettlementSeen() async {
    await _storage.write(key: _demoRewardSettlementSeenKey, value: 'true');
  }

  Future<void> resetDemoRewardSettlementSeen() async {
    await _storage.delete(key: _demoRewardSettlementSeenKey);
  }

  Future<void> resetProfileSetup() async {
    await Future.wait([
      _storage.delete(key: _selectedAvatarKey),
      _storage.delete(key: _selectedProfileBannerKey),
      _storage.delete(key: _primarySportKey),
      _storage.delete(key: _selectedTimeZoneKey),
      _storage.delete(key: _followedLeaguesKey),
      _storage.delete(key: _favoriteTeamsKey),
      resetDemoRewardSettlementSeen(),
      _storage.write(key: _onboardingCompleteKey, value: 'false'),
    ]);
  }

  /// The set of achievement ids already celebrated. Returns `null` when the key
  /// has never been written — the watcher uses that to seed silently on first
  /// run (so badges earned before this feature shipped never replay).
  Future<Set<String>?> loadCelebratedAchievements() async {
    try {
      final raw = await _storage.read(key: _celebratedAchievementsKey);
      if (raw == null || raw.isEmpty) return null;
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCelebratedAchievements(Set<String> ids) async {
    await _storage.write(
      key: _celebratedAchievementsKey,
      value: jsonEncode(ids.toList()),
    );
  }

  Future<StreakSnapshot?> loadStreak() async {
    try {
      final raw = await _storage.read(key: _streakKey);
      if (raw == null || raw.isEmpty) return null;
      return StreakSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStreak(StreakSnapshot streak) async {
    await _storage.write(key: _streakKey, value: jsonEncode(streak.toJson()));
  }

  Future<PlayerProgression> loadProgression() async {
    try {
      final raw = await _storage.read(key: _progressionKey);
      if (raw == null || raw.isEmpty) return PlayerProgression.initial();
      return PlayerProgression.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return PlayerProgression.initial();
    }
  }

  Future<void> saveProgression(PlayerProgression progression) async {
    await _storage.write(
      key: _progressionKey,
      value: jsonEncode(progression.toJson()),
    );
  }

  /// Quiz per-mode progress (cleared flags + best runs). Drives the
  /// progression-gated unlocks in the quiz lobby.
  Future<QuizProgress> loadQuizProgress(Sport sport) async {
    try {
      final raw = await _storage.read(key: _quizProgressKey(sport));
      if (raw == null || raw.isEmpty) return QuizProgress.initial();
      return QuizProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return QuizProgress.initial();
    }
  }

  Future<void> saveQuizProgress(Sport sport, QuizProgress progress) async {
    await _storage.write(
      key: _quizProgressKey(sport),
      value: jsonEncode(progress.toJson()),
    );
  }

  Future<BasketballStats> loadBasketballStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_basketballStatsKey);
      if (raw == null || raw.isEmpty) return const BasketballStats();
      return BasketballStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const BasketballStats();
    }
  }

  Future<void> saveBasketballStats(BasketballStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_basketballStatsKey, jsonEncode(stats.toJson()));
  }

  Future<FinalOverStats> loadFinalOverStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_finalOverStatsKey);
      if (raw == null || raw.isEmpty) return const FinalOverStats();
      return FinalOverStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const FinalOverStats();
    }
  }

  Future<void> saveFinalOverStats(FinalOverStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_finalOverStatsKey, jsonEncode(stats.toJson()));
  }

  Future<TennisProfile> loadTennisProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tennisProfileKey);
      if (raw == null || raw.isEmpty) return const TennisProfile();
      return TennisProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const TennisProfile();
    }
  }

  Future<void> saveTennisProfile(TennisProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tennisProfileKey, jsonEncode(profile.toJson()));
  }

  Future<TennisMatchSnapshot?> loadTennisMatchSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tennisResumeKey);
      if (raw == null || raw.isEmpty) return null;
      return TennisMatchSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTennisMatchSnapshot(TennisMatchSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tennisResumeKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clearTennisMatchSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tennisResumeKey);
  }

  Future<Set<String>> loadTennisRewardSettlementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_tennisSettlementKey) ?? const <String>[])
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveTennisRewardSettlementIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final bounded = ids.toList(growable: false);
    await prefs.setStringList(
      _tennisSettlementKey,
      bounded.length <= 256 ? bounded : bounded.sublist(bounded.length - 256),
    );
  }
}
