import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck.dart';
import '../models/match.dart';
import '../models/oz_coin_ledger.dart';
import '../models/picks.dart';
import '../models/prediction.dart';
import '../models/progression.dart';
import '../models/streak.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.coins,
    required this.ownedCardIds,
    required this.ownedActionCardIds,
    required this.ownedCardBackIds,
    required this.equippedCardBackId,
    required this.ownedAvatarBorderIds,
    required this.equippedAvatarBorderId,
    required this.dailyDropLastClaimedAtMillis,
  });

  factory WalletSnapshot.initial() => const WalletSnapshot(
    coins: 0,
    ownedCardIds: [],
    ownedActionCardIds: [],
    ownedCardBackIds: ['default'],
    equippedCardBackId: 'default',
    ownedAvatarBorderIds: [],
    equippedAvatarBorderId: '',
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
    ownedAvatarBorderIds: List<String>.from(
      json['ownedAvatarBorderIds'] as List? ?? const [],
    ),
    equippedAvatarBorderId: json['equippedAvatarBorderId'] as String? ?? '',
    dailyDropLastClaimedAtMillis: json['dailyDropLastClaimedAtMillis'] as int?,
  );

  final int coins;
  final List<String> ownedCardIds;
  final List<String> ownedActionCardIds;
  final List<String> ownedCardBackIds;
  final String equippedCardBackId;
  final List<String> ownedAvatarBorderIds;
  final String equippedAvatarBorderId;
  final int? dailyDropLastClaimedAtMillis;

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'ownedCardIds': ownedCardIds,
    'ownedActionCardIds': ownedActionCardIds,
    'ownedCardBackIds': ownedCardBackIds,
    'equippedCardBackId': equippedCardBackId,
    'ownedAvatarBorderIds': ownedAvatarBorderIds,
    'equippedAvatarBorderId': equippedAvatarBorderId,
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
  static const _predictionsKey = 'pd_predictions_v1';
  static const _pickPositionsKey = 'pd_pick_positions_v1';
  static const _selectedAvatarKey = 'pd_selected_avatar_v1';
  static const _selectedProfileBannerKey = 'pd_selected_profile_banner_v1';
  static const _followedLeaguesKey = 'pd_followed_leagues_v1';
  static const _favoriteTeamsKey = 'pd_favorite_teams_v1';
  static const _onboardingCompleteKey = 'pd_onboarding_complete_v1';
  static const _celebratedAchievementsKey = 'pd_celebrated_achievements_v1';
  static const _streakKey = 'pd_daily_streak_v1';

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

  Future<void> resetProfileSetup() async {
    await Future.wait([
      _storage.delete(key: _selectedAvatarKey),
      _storage.delete(key: _selectedProfileBannerKey),
      _storage.delete(key: _followedLeaguesKey),
      _storage.delete(key: _favoriteTeamsKey),
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
}
