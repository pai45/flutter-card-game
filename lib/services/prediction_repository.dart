import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';

/// Data seam for the prediction hub. The UI/cubit only ever talk to this
/// interface, so swapping [MockPredictionRepository] for an HTTP/Firebase
/// implementation when the app goes live needs no UI changes.
abstract class PredictionRepository {
  Future<List<League>> leagues();

  /// Fixtures for [day] (defaults to "today" in mock terms — returns all).
  Future<List<SportMatch>> fixtures({DateTime? day});

  /// The quiz for a fixture, or null if none is configured.
  Future<PredictionQuiz?> quizFor(String matchId);
}

/// Hardcoded fixtures + quizzes mirroring the home mockup, spanning every card
/// state: upcoming-open, upcoming-predicted, live, and finished (football +
/// cricket). Single source of truth for fixtures until a backend exists.
class MockPredictionRepository implements PredictionRepository {
  // ── Leagues (EPL first to match the reference order) ─────────────────────────
  static const _epl = League(
    id: 'epl',
    name: 'English Premier League',
    shortCode: 'EPL',
    accent: Color(0xffa855f7),
  );
  static const _ipl = League(
    id: 'ipl',
    name: 'Indian Premier League',
    shortCode: 'IPL',
    accent: Color(0xff5cdfff),
  );

  // ── Teams ──────────────────────────────────────────────────────────────────
  static const _liv = SportTeam(
    id: 'liv',
    name: 'Liverpool',
    shortName: 'LFC',
    color: Color(0xffc8102e),
  );
  static const _mc = SportTeam(
    id: 'mc',
    name: 'Man City',
    shortName: 'MNC',
    color: Color(0xff6cabdd),
  );
  static const _cfc = SportTeam(
    id: 'cfc',
    name: 'Chelsea',
    shortName: 'CFC',
    color: Color(0xff1f4fd6),
  );
  static const _new = SportTeam(
    id: 'new',
    name: 'Newcastle',
    shortName: 'NEW',
    color: Color(0xffededE8),
  );
  static const _mu = SportTeam(
    id: 'mu',
    name: 'Man Utd',
    shortName: 'MU',
    color: Color(0xffd5122a),
  );
  static const _whu = SportTeam(
    id: 'whu',
    name: 'West Ham',
    shortName: 'WHU',
    color: Color(0xff7a263a),
  );
  static const _srh = SportTeam(
    id: 'srh',
    name: 'Hyderabad',
    shortName: 'SRH',
    color: Color(0xffff822e),
  );
  static const _mi = SportTeam(
    id: 'mi',
    name: 'Mumbai',
    shortName: 'MI',
    color: Color(0xff2856a5),
  );
  static const _pjk = SportTeam(
    id: 'pjk',
    name: 'Punjab',
    shortName: 'PJK',
    color: Color(0xffdcd9cf),
  );
  static const _kkr = SportTeam(
    id: 'kkr',
    name: 'KKR',
    shortName: 'KKR',
    color: Color(0xfff0c419),
  );

  // Fixtures are built relative to "now" so statuses stay believable on launch.
  late final DateTime _now = DateTime.now();
  late final DateTime _today15 = DateTime(_now.year, _now.month, _now.day, 15);

  late final List<SportMatch> _fixtures = [
    // EPL — upcoming, open for prediction (prize strip).
    SportMatch(
      id: 'epl_liv_mc',
      leagueId: 'epl',
      sport: Sport.football,
      home: _liv,
      away: _mc,
      kickoff: _today15,
      status: MatchStatus.upcoming,
      prizeLabel: 'Win ₹5000',
    ),
    // EPL — live football, score in progress.
    SportMatch(
      id: 'epl_cfc_new',
      leagueId: 'epl',
      sport: Sport.football,
      home: _cfc,
      away: _new,
      kickoff: _now.subtract(const Duration(minutes: 67)),
      status: MatchStatus.live,
      liveMinute: 67,
      homeScore: '2',
      awayScore: '1',
    ),
    // EPL — finished football, earned reward (no result line on the card).
    SportMatch(
      id: 'epl_mu_whu',
      leagueId: 'epl',
      sport: Sport.football,
      home: _mu,
      away: _whu,
      kickoff: _now.subtract(const Duration(hours: 3)),
      status: MatchStatus.finished,
      homeScore: '2',
      awayScore: '1',
      rewardXp: 100,
    ),
    // IPL — finished cricket, per-side innings + result + earned reward.
    SportMatch(
      id: 'ipl_srh_mi',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _srh,
      away: _mi,
      kickoff: _now.subtract(const Duration(hours: 5)),
      status: MatchStatus.finished,
      homeScore: '202-10 (20 ov)',
      awayScore: '221-4 (20 ov)',
      resultLine: 'Mumbai won by 19 runs',
      rewardXp: 100,
    ),
    // IPL — upcoming, already predicted (see PredictionCubit demo seed).
    SportMatch(
      id: 'ipl_pjk_kkr',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _pjk,
      away: _kkr,
      kickoff: _today15,
      status: MatchStatus.upcoming,
      prizeLabel: 'Win ₹5000',
    ),
  ];

  late final Map<String, PredictionQuiz> _quizzes = {
    'epl_liv_mc': const PredictionQuiz(
      matchId: 'epl_liv_mc',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who will win MAN CITY vs LIVERPOOL?',
          options: ['Man City', 'Tie', 'Liverpool'],
          reward: 100,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 50,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Total goals over/under 2.5?',
          options: ['Over 2.5', 'Under 2.5'],
          reward: 75,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Which side scores first?',
          options: ['Man City', 'Liverpool', 'No goal'],
          reward: 75,
        ),
        QuizQuestion(
          id: 'q5',
          text: 'Will a red card be shown?',
          options: ['Yes', 'No'],
          reward: 50,
        ),
      ],
    ),
    'ipl_pjk_kkr': const PredictionQuiz(
      matchId: 'ipl_pjk_kkr',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Punjab', 'KKR'],
          reward: 50,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sixes over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 100,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Who will win PUNJAB vs KKR?',
          options: ['Punjab', 'Tie', 'KKR'],
          reward: 100,
        ),
      ],
    ),
    // Settled quiz so PICK/finished demos can show a result + reward.
    'epl_mu_whu': const PredictionQuiz(
      matchId: 'epl_mu_whu',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who will win MAN UTD vs WEST HAM?',
          options: ['Man Utd', 'Tie', 'West Ham'],
          reward: 100,
          settledOptionIndex: 0,
        ),
      ],
    ),
  };

  @override
  Future<List<League>> leagues() async => const [_epl, _ipl];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day}) async =>
      List.unmodifiable(_fixtures);

  @override
  Future<PredictionQuiz?> quizFor(String matchId) async => _quizzes[matchId];
}
