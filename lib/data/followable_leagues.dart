import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/sport_match.dart';

/// A league the player can follow during profile setup, paired with the teams
/// they can pick a favourite from.
///
/// Reuses the existing [League] + [SportTeam] models. This catalogue is kept
/// deliberately separate from `MockPredictionRepository` so seeding extra
/// leagues here never spawns empty sections on the prediction home (which only
/// renders leagues that have fixtures). League/team ids for EPL + IPL mirror the
/// repository so a favourite lines up with prediction data later.
class FollowableLeague {
  const FollowableLeague({
    required this.sport,
    required this.league,
    required this.teams,
  });

  final Sport sport;
  final League league;
  final List<SportTeam> teams;
}

const List<FollowableLeague> followableLeagues = [
  // ── English Premier League (football) — mirrors repository ids ────────────
  FollowableLeague(
    sport: Sport.football,
    league: League(
      id: 'epl',
      name: 'English Premier League',
      shortCode: 'EPL',
      accent: Color(0xffa855f7),
    ),
    teams: [
      SportTeam(
        id: 'liv',
        name: 'Liverpool',
        shortName: 'LFC',
        color: Color(0xffc8102e),
      ),
      SportTeam(
        id: 'ars',
        name: 'Arsenal',
        shortName: 'ARS',
        color: Color(0xffef0107),
      ),
      SportTeam(
        id: 'mc',
        name: 'Man City',
        shortName: 'MCI',
        color: Color(0xff6cabdd),
      ),
      SportTeam(
        id: 'mu',
        name: 'Man Utd',
        shortName: 'MU',
        color: Color(0xffd5122a),
      ),
      SportTeam(
        id: 'cfc',
        name: 'Chelsea',
        shortName: 'CFC',
        color: Color(0xff1f4fd6),
      ),
      SportTeam(
        id: 'new',
        name: 'Newcastle',
        shortName: 'NEW',
        color: Color(0xffededE8),
      ),
      SportTeam(
        id: 'avl',
        name: 'Aston Villa',
        shortName: 'AVL',
        color: Color(0xff7a003c),
      ),
      SportTeam(
        id: 'whu',
        name: 'West Ham',
        shortName: 'WHU',
        color: Color(0xff7a263a),
      ),
    ],
  ),

  // ── La Liga (football) — seeded ───────────────────────────────────────────
  FollowableLeague(
    sport: Sport.football,
    league: League(
      id: 'laliga',
      name: 'La Liga',
      shortCode: 'LAL',
      accent: Color(0xffff6a00),
    ),
    teams: [
      SportTeam(
        id: 'rma',
        name: 'Real Madrid',
        shortName: 'RMA',
        color: Color(0xfffebe10),
      ),
      SportTeam(
        id: 'fcb',
        name: 'Barcelona',
        shortName: 'FCB',
        color: Color(0xffa50044),
      ),
      SportTeam(
        id: 'atm',
        name: 'Atletico',
        shortName: 'ATM',
        color: Color(0xffcb3524),
      ),
      SportTeam(
        id: 'sev',
        name: 'Sevilla',
        shortName: 'SEV',
        color: Color(0xffd9182b),
      ),
      SportTeam(
        id: 'rso',
        name: 'Real Sociedad',
        shortName: 'RSO',
        color: Color(0xff0067b1),
      ),
      SportTeam(
        id: 'bet',
        name: 'Real Betis',
        shortName: 'BET',
        color: Color(0xff00954c),
      ),
    ],
  ),

  // ── Serie A (football) — seeded ───────────────────────────────────────────
  FollowableLeague(
    sport: Sport.football,
    league: League(
      id: 'seriea',
      name: 'Serie A',
      shortCode: 'SEA',
      accent: Color(0xff2bb2ff),
    ),
    teams: [
      SportTeam(
        id: 'juv',
        name: 'Juventus',
        shortName: 'JUV',
        color: Color(0xffffffff),
      ),
      SportTeam(
        id: 'int',
        name: 'Inter',
        shortName: 'INT',
        color: Color(0xff0068a8),
      ),
      SportTeam(
        id: 'mil',
        name: 'AC Milan',
        shortName: 'MIL',
        color: Color(0xfffb090b),
      ),
      SportTeam(
        id: 'nap',
        name: 'Napoli',
        shortName: 'NAP',
        color: Color(0xff12a0d7),
      ),
      SportTeam(
        id: 'rom',
        name: 'Roma',
        shortName: 'ROM',
        color: Color(0xff8e1f2f),
      ),
      SportTeam(
        id: 'laz',
        name: 'Lazio',
        shortName: 'LAZ',
        color: Color(0xff87d8f7),
      ),
    ],
  ),

  // ── Bundesliga (football) — seeded ────────────────────────────────────────
  FollowableLeague(
    sport: Sport.football,
    league: League(
      id: 'bundesliga',
      name: 'Bundesliga',
      shortCode: 'BUN',
      accent: Color(0xffe2231a),
    ),
    teams: [
      SportTeam(
        id: 'bay',
        name: 'Bayern',
        shortName: 'BAY',
        color: Color(0xffdc052d),
      ),
      SportTeam(
        id: 'bvb',
        name: 'Dortmund',
        shortName: 'BVB',
        color: Color(0xfffde100),
      ),
      SportTeam(
        id: 'rbl',
        name: 'RB Leipzig',
        shortName: 'RBL',
        color: Color(0xffdd0741),
      ),
      SportTeam(
        id: 'b04',
        name: 'Leverkusen',
        shortName: 'B04',
        color: Color(0xffe32221),
      ),
      SportTeam(
        id: 'sge',
        name: 'Frankfurt',
        shortName: 'SGE',
        color: Color(0xffe1000f),
      ),
      SportTeam(
        id: 'wob',
        name: 'Wolfsburg',
        shortName: 'WOB',
        color: Color(0xff65b32e),
      ),
    ],
  ),

  // ── Formula 1 ─────────────────────────────────────────────────────────────
  FollowableLeague(
    sport: Sport.cricket,
    league: League(
      id: '23810',
      name: 'International T20',
      shortCode: 'T20I',
      accent: Color(0xfff59e0b),
    ),
    teams: [
      SportTeam(
        id: 'ind',
        name: 'India',
        shortName: 'IND',
        color: Color(0xff1d4ed8),
      ),
      SportTeam(
        id: 'eng',
        name: 'England',
        shortName: 'ENG',
        color: Color(0xffffffff),
      ),
      SportTeam(
        id: 'wi',
        name: 'West Indies',
        shortName: 'WI',
        color: Color(0xff7a0016),
      ),
      SportTeam(
        id: 'sl',
        name: 'Sri Lanka',
        shortName: 'SL',
        color: Color(0xff002b54),
      ),
    ],
  ),

  FollowableLeague(
    sport: Sport.f1,
    league: League(
      id: 'formula1',
      name: 'Formula 1',
      shortCode: 'F1',
      accent: Color(0xffff4fd8),
    ),
    teams: [
      SportTeam(
        id: 'rbr',
        name: 'Red Bull Racing',
        shortName: 'RBR',
        color: Color(0xff263bff),
      ),
      SportTeam(
        id: 'fer',
        name: 'Ferrari',
        shortName: 'FER',
        color: Color(0xffdc0000),
      ),
      SportTeam(
        id: 'mcl',
        name: 'McLaren',
        shortName: 'MCL',
        color: Color(0xffff8700),
      ),
      SportTeam(
        id: 'mer',
        name: 'Mercedes',
        shortName: 'MER',
        color: Color(0xff00d2be),
      ),
      SportTeam(
        id: 'ast',
        name: 'Aston Martin',
        shortName: 'AST',
        color: Color(0xff006f62),
      ),
      SportTeam(
        id: 'wil',
        name: 'Williams',
        shortName: 'WIL',
        color: Color(0xff00a3e0),
      ),
    ],
  ),

  FollowableLeague(
    sport: Sport.basketball,
    league: League(
      id: 'nba',
      name: 'National Basketball Association',
      shortCode: 'NBA',
      accent: Color(0xffffd34d),
    ),
    teams: [
      SportTeam(
        id: 'lal',
        name: 'LA Lakers',
        shortName: 'LAL',
        color: Color(0xff552583),
      ),
      SportTeam(
        id: 'bos',
        name: 'Boston',
        shortName: 'BOS',
        color: Color(0xff007a33),
      ),
      SportTeam(
        id: 'gsw',
        name: 'Golden State',
        shortName: 'GSW',
        color: Color(0xff1d428a),
      ),
      SportTeam(
        id: 'mia',
        name: 'Miami',
        shortName: 'MIA',
        color: Color(0xff98002e),
      ),
      SportTeam(
        id: 'nyk',
        name: 'New York',
        shortName: 'NYK',
        color: Color(0xff006bb6),
      ),
      SportTeam(
        id: 'dal',
        name: 'Dallas',
        shortName: 'DAL',
        color: Color(0xff00538c),
      ),
    ],
  ),
];

List<FollowableLeague> followableLeaguesForSport(Sport sport) => [
  for (final entry in followableLeagues)
    if (entry.sport == sport) entry,
];

/// The followable league with [id], or null when unknown.
FollowableLeague? followableLeagueById(String id) {
  for (final entry in followableLeagues) {
    if (entry.league.id == id) return entry;
  }
  return null;
}

/// The team with [teamId] inside league [leagueId], or null when unknown.
SportTeam? followableTeam(String leagueId, String teamId) {
  final league = followableLeagueById(leagueId);
  if (league == null) return null;
  for (final team in league.teams) {
    if (team.id == teamId) return team;
  }
  return null;
}
