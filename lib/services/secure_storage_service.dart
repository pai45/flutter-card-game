import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deck.dart';
import '../models/match.dart';
import '../models/progression.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.coins,
    required this.ownedCardIds,
    required this.ownedActionCardIds,
    required this.ownedCardBackIds,
    required this.equippedCardBackId,
    required this.dailyDropLastClaimedAtMillis,
  });

  factory WalletSnapshot.initial() => const WalletSnapshot(
    coins: 0,
    ownedCardIds: [],
    ownedActionCardIds: [],
    ownedCardBackIds: ['default'],
    equippedCardBackId: 'default',
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
    dailyDropLastClaimedAtMillis: json['dailyDropLastClaimedAtMillis'] as int?,
  );

  final int coins;
  final List<String> ownedCardIds;
  final List<String> ownedActionCardIds;
  final List<String> ownedCardBackIds;
  final String equippedCardBackId;
  final int? dailyDropLastClaimedAtMillis;

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'ownedCardIds': ownedCardIds,
    'ownedActionCardIds': ownedActionCardIds,
    'ownedCardBackIds': ownedCardBackIds,
    'equippedCardBackId': equippedCardBackId,
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
