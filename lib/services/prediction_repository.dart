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

/// Hardcoded fixtures + quizzes mirroring the home mockups (IPL & EPL), spanning
/// every card state: upcoming, live, and finished. Single source of truth for
/// fixtures until a backend exists.
class MockPredictionRepository implements PredictionRepository {
  // ── Leagues ────────────────────────────────────────────────────────────────
  static const _ipl = League(
    id: 'ipl',
    name: 'Indian Premier League',
    shortCode: 'IPL',
    accent: Color(0xff5cdfff),
  );
  static const _epl = League(
    id: 'epl',
    name: 'English Premier League',
    shortCode: 'EPL',
    accent: Color(0xffa855f7),
  );

  // ── Teams ────────────────────────────────────────────────────────────────--
  static const _csk = SportTeam(
    id: 'csk',
    name: 'Chennai',
    shortName: 'CSK',
    color: Color(0xffffd700),
  );
  static const _mi = SportTeam(
    id: 'mi',
    name: 'Mumbai',
    shortName: 'MI',
    color: Color(0xff2856a5),
  );
  static const _rcb = SportTeam(
    id: 'rcb',
    name: 'RCB',
    shortName: 'RCB',
    color: Color(0xffe21f26),
  );
  static const _kkr = SportTeam(
    id: 'kkr',
    name: 'KKR',
    shortName: 'KKR',
    color: Color(0xff7b27a8),
  );
  static const _srh = SportTeam(
    id: 'srh',
    name: 'Hyderabad',
    shortName: 'SRH',
    color: Color(0xffff822e),
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
    color: Color(0xff111418),
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

  // Fixtures are built relative to "now" so statuses stay believable on launch.
  late final DateTime _now = DateTime.now();

  late final List<SportMatch> _fixtures = [
    // Upcoming — open for prediction (prize strip).
    SportMatch(
      id: 'ipl_csk_mi',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _csk,
      away: _mi,
      kickoff: _now.add(const Duration(hours: 3)),
      status: MatchStatus.upcoming,
      prizeLabel: 'WIN ₹5000',
    ),
    SportMatch(
      id: 'ipl_rcb_kkr',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _rcb,
      away: _kkr,
      kickoff: _now.add(const Duration(hours: 5)),
      status: MatchStatus.upcoming,
      prizeLabel: 'WIN ₹5000',
    ),
    // Live football — score in progress.
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
    // Finished football — result + earned reward.
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
      resultLine: 'Man Utd won 2–1',
      rewardXp: 100,
    ),
    // Finished cricket — per-side innings + result + earned reward.
    SportMatch(
      id: 'ipl_srh_mi',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _srh,
      away: _mi,
      kickoff: _now.subtract(const Duration(hours: 5)),
      status: MatchStatus.finished,
      homeScore: '202-10 (20ov)',
      awayScore: '221-4 (20ov)',
      resultLine: 'Mumbai won by 19 runs',
      rewardXp: 100,
    ),
  ];

  late final Map<String, PredictionQuiz> _quizzes = {
    'ipl_csk_mi': const PredictionQuiz(
      matchId: 'ipl_csk_mi',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Chennai', 'Mumbai'],
          reward: 50,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Which side bats first?',
          options: ['Chennai', 'Mumbai'],
          reward: 50,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Top run-scorer of the match?',
          options: ['Chennai batter', 'Mumbai batter'],
          reward: 150,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Who will win CHENNAI vs MUMBAI?',
          options: ['Chennai', 'Tie', 'Mumbai'],
          reward: 100,
        ),
      ],
    ),
    'ipl_rcb_kkr': const PredictionQuiz(
      matchId: 'ipl_rcb_kkr',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['RCB', 'KKR'],
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
          text: 'Who will win RCB vs KKR?',
          options: ['RCB', 'Tie', 'KKR'],
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
  Future<List<League>> leagues() async => const [_ipl, _epl];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day}) async =>
      List.unmodifiable(_fixtures);

  @override
  Future<PredictionQuiz?> quizFor(String matchId) async => _quizzes[matchId];
}
