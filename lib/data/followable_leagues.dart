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
  const FollowableLeague({required this.league, required this.teams});

  final League league;
  final List<SportTeam> teams;
}

const List<FollowableLeague> followableLeagues = [
  // ── English Premier League (football) — mirrors repository ids ────────────
  FollowableLeague(
    league: League(
      id: 'epl',
      name: 'English Premier League',
      shortCode: 'EPL',
      accent: Color(0xffa855f7),
    ),
    teams: [
      SportTeam(id: 'liv', name: 'Liverpool', shortName: 'LFC', color: Color(0xffc8102e)),
      SportTeam(id: 'ars', name: 'Arsenal', shortName: 'ARS', color: Color(0xffef0107)),
      SportTeam(id: 'mc', name: 'Man City', shortName: 'MCI', color: Color(0xff6cabdd)),
      SportTeam(id: 'mu', name: 'Man Utd', shortName: 'MU', color: Color(0xffd5122a)),
      SportTeam(id: 'cfc', name: 'Chelsea', shortName: 'CFC', color: Color(0xff1f4fd6)),
      SportTeam(id: 'new', name: 'Newcastle', shortName: 'NEW', color: Color(0xffededE8)),
      SportTeam(id: 'avl', name: 'Aston Villa', shortName: 'AVL', color: Color(0xff7a003c)),
      SportTeam(id: 'whu', name: 'West Ham', shortName: 'WHU', color: Color(0xff7a263a)),
    ],
  ),

  // ── La Liga (football) — seeded ───────────────────────────────────────────
  FollowableLeague(
    league: League(
      id: 'laliga',
      name: 'La Liga',
      shortCode: 'LAL',
      accent: Color(0xffff6a00),
    ),
    teams: [
      SportTeam(id: 'rma', name: 'Real Madrid', shortName: 'RMA', color: Color(0xfffebe10)),
      SportTeam(id: 'fcb', name: 'Barcelona', shortName: 'FCB', color: Color(0xffa50044)),
      SportTeam(id: 'atm', name: 'Atletico', shortName: 'ATM', color: Color(0xffcb3524)),
      SportTeam(id: 'sev', name: 'Sevilla', shortName: 'SEV', color: Color(0xffd9182b)),
      SportTeam(id: 'rso', name: 'Real Sociedad', shortName: 'RSO', color: Color(0xff0067b1)),
      SportTeam(id: 'bet', name: 'Real Betis', shortName: 'BET', color: Color(0xff00954c)),
    ],
  ),

  // ── Serie A (football) — seeded ───────────────────────────────────────────
  FollowableLeague(
    league: League(
      id: 'seriea',
      name: 'Serie A',
      shortCode: 'SEA',
      accent: Color(0xff2bb2ff),
    ),
    teams: [
      SportTeam(id: 'juv', name: 'Juventus', shortName: 'JUV', color: Color(0xffffffff)),
      SportTeam(id: 'int', name: 'Inter', shortName: 'INT', color: Color(0xff0068a8)),
      SportTeam(id: 'mil', name: 'AC Milan', shortName: 'MIL', color: Color(0xfffb090b)),
      SportTeam(id: 'nap', name: 'Napoli', shortName: 'NAP', color: Color(0xff12a0d7)),
      SportTeam(id: 'rom', name: 'Roma', shortName: 'ROM', color: Color(0xff8e1f2f)),
      SportTeam(id: 'laz', name: 'Lazio', shortName: 'LAZ', color: Color(0xff87d8f7)),
    ],
  ),

  // ── Bundesliga (football) — seeded ────────────────────────────────────────
  FollowableLeague(
    league: League(
      id: 'bundesliga',
      name: 'Bundesliga',
      shortCode: 'BUN',
      accent: Color(0xffe2231a),
    ),
    teams: [
      SportTeam(id: 'bay', name: 'Bayern', shortName: 'BAY', color: Color(0xffdc052d)),
      SportTeam(id: 'bvb', name: 'Dortmund', shortName: 'BVB', color: Color(0xfffde100)),
      SportTeam(id: 'rbl', name: 'RB Leipzig', shortName: 'RBL', color: Color(0xffdd0741)),
      SportTeam(id: 'b04', name: 'Leverkusen', shortName: 'B04', color: Color(0xffe32221)),
      SportTeam(id: 'sge', name: 'Frankfurt', shortName: 'SGE', color: Color(0xffe1000f)),
      SportTeam(id: 'wob', name: 'Wolfsburg', shortName: 'WOB', color: Color(0xff65b32e)),
    ],
  ),

  // ── Indian Premier League (cricket) — mirrors repository ids ──────────────
  FollowableLeague(
    league: League(
      id: 'ipl',
      name: 'Indian Premier League',
      shortCode: 'IPL',
      accent: Color(0xff5cdfff),
    ),
    teams: [
      SportTeam(id: 'csk', name: 'Chennai', shortName: 'CSK', color: Color(0xfff9cd05)),
      SportTeam(id: 'mi', name: 'Mumbai', shortName: 'MI', color: Color(0xff2856a5)),
      SportTeam(id: 'rcb', name: 'Bangalore', shortName: 'RCB', color: Color(0xffd81920)),
      SportTeam(id: 'kkr', name: 'KKR', shortName: 'KKR', color: Color(0xfff0c419)),
      SportTeam(id: 'srh', name: 'Hyderabad', shortName: 'SRH', color: Color(0xffff822e)),
      SportTeam(id: 'pjk', name: 'Punjab', shortName: 'PJK', color: Color(0xffdcd9cf)),
    ],
  ),
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
