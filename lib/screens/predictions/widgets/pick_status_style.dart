import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/picks.dart';

/// Single source for pick market/position status colors and labels so the hub
/// cards, detail screen and portfolio strip always speak the same language.

String pickMarketTypeLabel(PickMarketType type) => switch (type) {
  PickMarketType.match => 'MATCH',
  PickMarketType.event => 'EVENT',
  PickMarketType.future => 'FUTURE',
};

Color pickMarketTypeColor(PickMarketType type) => switch (type) {
  PickMarketType.match => Cyber.cyan,
  PickMarketType.event => Cyber.gold,
  PickMarketType.future => Cyber.violet,
};

String pickMarketStatusLabel(PickMarketStatus status) => switch (status) {
  PickMarketStatus.upcoming => 'OPEN',
  PickMarketStatus.live => 'LIVE',
  PickMarketStatus.closed => 'CLOSED',
  PickMarketStatus.unresolved => 'UNRESOLVED',
  PickMarketStatus.settled => 'SETTLED',
  PickMarketStatus.voided => 'VOID',
};

Color pickMarketStatusColor(PickMarketStatus status) => switch (status) {
  PickMarketStatus.upcoming => Cyber.gold,
  PickMarketStatus.live => Cyber.red,
  PickMarketStatus.closed => Cyber.muted,
  PickMarketStatus.unresolved => Cyber.amber,
  PickMarketStatus.settled => Cyber.success,
  PickMarketStatus.voided => Cyber.muted,
};

String pickPositionLabel(PickPositionStatus status) => switch (status) {
  PickPositionStatus.pending => 'PENDING',
  PickPositionStatus.live => 'LIVE',
  PickPositionStatus.unresolved => 'UNRESOLVED',
  PickPositionStatus.settleable => 'CLAIM',
  PickPositionStatus.won => 'WON',
  PickPositionStatus.lost => 'LOST',
  PickPositionStatus.voided => 'REFUNDED',
};

Color pickPositionColor(PickPositionStatus status) => switch (status) {
  PickPositionStatus.pending => Cyber.cyan,
  PickPositionStatus.live => Cyber.red,
  PickPositionStatus.unresolved => Cyber.amber,
  PickPositionStatus.settleable => Cyber.gold,
  PickPositionStatus.won => Cyber.success,
  PickPositionStatus.lost => Cyber.red,
  PickPositionStatus.voided => Cyber.muted,
};

/// Short team/outcome code shown on the filled CTA badges, matching the
/// home-page team-logo style (e.g. Punjab → PJB, Bangalore → BLR). Known
/// teams use their conventional codes; anything else falls back to initials
/// (multi-word) or the first three letters (single word).
String pickOutcomeCode(String label) {
  final trimmed = label.trim();
  final lower = trimmed.toLowerCase();
  const explicit = {
    'punjab': 'PJB',
    'bangalore': 'BLR',
    'liverpool': 'LIV',
    'man city': 'MCI',
    'manchester city': 'MCI',
    'man utd': 'MUN',
    'manchester united': 'MUN',
    'mumbai': 'MUM',
    'chennai': 'CHE',
    'aston villa': 'AVL',
    'brighton or draw': 'BHA',
    'brighton': 'BHA',
    'newcastle': 'NEW',
    'chelsea': 'CHE',
    'arsenal': 'ARS',
    'argentina': 'ARG',
    'portugal': 'POR',
    'draw': 'DRW',
    'field': 'FLD',
    'yes': 'YES',
    'no': 'NO',
  };
  if (explicit.containsKey(lower)) return explicit[lower]!;
  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length >= 2) {
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }
  final word = words.isEmpty ? trimmed : words.first;
  if (word.length <= 3) return word.toUpperCase();
  return word.substring(0, 3).toUpperCase();
}

/// Compact countdown to a market close, shown on pending pick tags:
/// `SOON` / `{m}M` / `{h}H` / `{d}D`.
String pickClosesLabel(DateTime closesAt) {
  final diff = closesAt.difference(DateTime.now());
  if (diff.isNegative) return 'SOON';
  if (diff.inMinutes < 60) return '${diff.inMinutes}M';
  if (diff.inHours < 24) return '${diff.inHours}H';
  return '${diff.inDays}D';
}

/// A deterministic per-match trading volume (Oz) so every fixture card reads
/// like a live market even when no real Pick market is linked to it. Seeded
/// from the match id and quantised to a tidy value in the ~1.5K–95K Oz band.
int seededMatchVolumeOz(String matchId) {
  // FNV-1a style hash → stable across sessions for a given id.
  var hash = 0x811c9dc5;
  for (final code in matchId.codeUnits) {
    hash = (hash ^ code) * 0x01000193 & 0xffffffff;
  }
  final span = 1500 + hash % 93500; // 1_500 .. 94_999
  return (span ~/ 100) * 100; // round to the nearest 100 Oz
}

String formatOzCompact(int value) {
  if (value >= 1000) {
    final k = value / 1000;
    return k == k.roundToDouble()
        ? '${k.toInt()}K'
        : '${k.toStringAsFixed(1)}K';
  }
  return '$value';
}

String formatOzGrouped(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
