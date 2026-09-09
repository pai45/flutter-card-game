import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/sport_match.dart';
import 'followable_leagues.dart';

/// A league the player can spin to on the leaderboard's PLAYERS board.
///
/// Deliberately separate from [followableLeagues]: the leaderboard needs 3-4
/// leagues per sport for the dial to be worth spinning, but adding those to the
/// followable catalogue would also make them followable in onboarding and the
/// profile "EDIT CLUBS" sheet. So the leagues that already exist there are
/// *reused* (same id/name/short code/accent/teams, so a league reads identically
/// wherever it appears) and the rest are declared here as leaderboard-only.
///
/// [clubs] are the short codes a rival can be affiliated to on this board. For
/// the individual sports (tennis, motorsport) they are nations/teams rather than
/// clubs — the board just needs a stable badge per rival.
class LeaderboardLeague {
  const LeaderboardLeague({
    required this.id,
    required this.sport,
    required this.name,
    required this.shortCode,
    required this.accent,
    required this.clubs,
  });

  final String id;
  final Sport sport;
  final String name;
  final String shortCode;
  final Color accent;
  final List<String> clubs;
}

/// The leagues for [sport], in dial order. Never empty; the first entry is the
/// default selection.
List<LeaderboardLeague> leaderboardLeaguesFor(Sport sport) =>
    _cache[sport] ??= _buildFor(sport);

/// The leaderboard league with [id], or null when unknown.
LeaderboardLeague? leaderboardLeagueById(String id) {
  for (final sport in Sport.values) {
    for (final league in leaderboardLeaguesFor(sport)) {
      if (league.id == id) return league;
    }
  }
  return null;
}

final Map<Sport, List<LeaderboardLeague>> _cache = {};

/// Dial order per sport, by short code. Codes resolve against the followable
/// catalogue first, then [_extraLeagues]; anything unresolvable is skipped.
List<String> _dialOrder(Sport sport) => switch (sport) {
  Sport.football => const ['EPL', 'LAL', 'SEA', 'BUN'],
  Sport.cricket => const ['IPL', 'T20I', 'BBL'],
  Sport.basketball => const ['NBA', 'EUL', 'WNBA'],
  Sport.motorsport => const ['F1', 'F2', 'NASCAR', 'INDY'],
  Sport.tennis => const ['ATP', 'WTA'],
};

List<LeaderboardLeague> _buildFor(Sport sport) {
  final byCode = <String, LeaderboardLeague>{
    for (final entry in followableLeaguesForSport(sport))
      entry.league.shortCode: LeaderboardLeague(
        id: entry.league.id,
        sport: sport,
        name: entry.league.name,
        shortCode: entry.league.shortCode,
        accent: entry.league.accent,
        clubs: [for (final team in entry.teams) team.shortName],
      ),
    for (final league in _extraLeagues)
      if (league.sport == sport) league.shortCode: league,
  };
  final ordered = [
    for (final code in _dialOrder(sport))
      if (byCode[code] case final league? when league.clubs.isNotEmpty) league,
  ];
  // Insurance only — every sport resolves at least one entry above.
  return ordered.isEmpty ? [_globalFallback(sport)] : ordered;
}

LeaderboardLeague _globalFallback(Sport sport) => LeaderboardLeague(
  id: 'global-${sport.name}',
  sport: sport,
  name: 'Global',
  shortCode: 'GLOBAL',
  accent: Cyber.cyan,
  clubs: const ['GLB'],
);

/// Leagues the followable catalogue doesn't carry. Accents come from `Cyber.*`
/// and stay distinct within a sport so the dial reads at a glance.
const List<LeaderboardLeague> _extraLeagues = [
  // ── Cricket ────────────────────────────────────────────────────────────────
  LeaderboardLeague(
    id: 'ipl',
    sport: Sport.cricket,
    name: 'Indian Premier League',
    shortCode: 'IPL',
    accent: Cyber.amber,
    clubs: ['MI', 'CSK', 'RCB', 'KKR', 'GT', 'SRH'],
  ),
  LeaderboardLeague(
    id: 'bbl',
    sport: Sport.cricket,
    name: 'Big Bash League',
    shortCode: 'BBL',
    accent: Cyber.lime,
    clubs: ['PSS', 'SYS', 'MLR', 'PRS', 'BRH', 'HBH'],
  ),
  // ── Basketball ─────────────────────────────────────────────────────────────
  LeaderboardLeague(
    id: 'euroleague',
    sport: Sport.basketball,
    name: 'EuroLeague',
    shortCode: 'EUL',
    accent: Cyber.amber,
    clubs: ['RMA', 'FCB', 'PAO', 'OLY', 'FEN', 'EFS'],
  ),
  LeaderboardLeague(
    id: 'wnba',
    sport: Sport.basketball,
    name: "Women's National Basketball Association",
    shortCode: 'WNBA',
    accent: Cyber.magenta,
    clubs: ['LVA', 'NYL', 'CON', 'SEA', 'PHO', 'MIN'],
  ),
  // ── Motorsport ─────────────────────────────────────────────────────────────
  LeaderboardLeague(
    id: 'formula2',
    sport: Sport.motorsport,
    name: 'Formula 2',
    shortCode: 'F2',
    accent: Cyber.cyan,
    clubs: ['PRE', 'ART', 'DAM', 'MPM', 'HIT', 'INV'],
  ),
  LeaderboardLeague(
    id: 'nascar',
    sport: Sport.motorsport,
    name: 'NASCAR Cup Series',
    shortCode: 'NASCAR',
    accent: Cyber.amber,
    clubs: ['HMS', 'JGR', 'PEN', 'RCR', 'TRK', 'SHR'],
  ),
  LeaderboardLeague(
    id: 'indycar',
    sport: Sport.motorsport,
    name: 'IndyCar Series',
    shortCode: 'INDY',
    accent: Cyber.lime,
    clubs: ['PEN', 'GAN', 'AND', 'ARW', 'MSR', 'RLL'],
  ),
  // ── Tennis ─────────────────────────────────────────────────────────────────
  LeaderboardLeague(
    id: 'wta',
    sport: Sport.tennis,
    name: 'WTA Tour',
    shortCode: 'WTA',
    accent: Cyber.magenta,
    clubs: ['POL', 'USA', 'BLR', 'KAZ', 'CZE', 'TUN'],
  ),
];
