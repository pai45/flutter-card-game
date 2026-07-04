import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck.dart';
import '../models/football_bingo.dart';
import '../models/football_chess.dart';
import '../models/match.dart';
import '../models/oz_coin_ledger.dart';
import '../models/picks.dart';
import '../models/prediction.dart';
import '../models/progression.dart';
import '../models/quiz_trivia.dart';
import '../models/referral.dart';
import '../models/streak.dart';
import '../models/xp_ledger.dart';
import '../models/guess_player.dart';
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
    required this.dailyDropLastClaimedAtMillis,
  });

  factory WalletSnapshot.initial() => const WalletSnapshot(
    coins: 0,
    ownedCardIds: [],
    ownedActionCardIds: [],
    ownedCardBackIds: ['default'],
    equippedCardBackId: 'default',
    ownedAvatarFrameIds: [],
    equippedAvatarFrameId: '',
    ownedAvatarIds: [],
    ownedBannerIds: [],
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
  static const _progressionKey = 'pd_progression_v1';
  static const _walletKey = 'pitch_duel_wallet';
  static const _coinLedgerKey = 'pd_oz_coin_ledger_v1';
  static const _xpLedgerKey = 'pd_xp_ledger_v1';
  static const _predictionsKey = 'pd_predictions_v1';
  static const _pickPositionsKey = 'pd_pick_positions_v1';
  static const _selectedAvatarKey = 'pd_selected_avatar_v1';
  static const _selectedProfileBannerKey = 'pd_selected_profile_banner_v1';
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
  static const _quizProgressKey = 'pd_quiz_progress_v1';
  static const _footballBingoProgressKey = 'pd_football_bingo_progress_v1';
  static const _footballBingoArchiveKey = 'pd_football_bingo_archive_v1';
  static const _guessPlayerArchiveKey = 'pd_guess_player_archive_v1';
  static const _footballChessStatsKey = 'pd_football_chess_stats_v1';

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

  Future<GuessPlayerArchive?> loadGuessPlayerArchive() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_guessPlayerArchiveKey);
      if (raw == null) return null;
      return GuessPlayerArchive.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGuessPlayerArchive(GuessPlayerArchive archive) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guessPlayerArchiveKey, jsonEncode(archive.toJson()));
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

  /// Football Quiz per-mode progress (cleared flags + best runs). Drives the
  /// progression-gated unlocks in the quiz lobby.
  Future<QuizProgress> loadQuizProgress() async {
    try {
      final raw = await _storage.read(key: _quizProgressKey);
      if (raw == null || raw.isEmpty) return QuizProgress.initial();
      return QuizProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return QuizProgress.initial();
    }
  }

  Future<void> saveQuizProgress(QuizProgress progress) async {
    await _storage.write(
      key: _quizProgressKey,
      value: jsonEncode(progress.toJson()),
    );
  }
}
