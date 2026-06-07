import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';

/// Data seam for the prediction hub. The UI/cubit only ever talk to this
/// interface, so swapping [MockPredictionRepository] for an HTTP/Firebase
/// implementation when the app goes live needs no UI changes.
abstract class PredictionRepository {
  Future<List<League>> leagues();

  /// Fixtures for [day] (defaults to "today" in mock terms — returns all).
  Future<List<SportMatch>> fixtures({DateTime? day});

  /// The quiz for a fixture, or null if none is configured.
  Future<PredictionQuiz?> quizFor(String matchId);

  /// The rank-sorted standings table for [leagueId], or empty if none.
  Future<List<TeamStanding>> standings(String leagueId);
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
    shortName: 'MCI',
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

  // Extra teams that only populate the standings tables (no fixtures yet).
  static const _ars = SportTeam(
    id: 'ars',
    name: 'Arsenal',
    shortName: 'ARS',
    color: Color(0xffef0107),
  );
  static const _avl = SportTeam(
    id: 'avl',
    name: 'Aston Villa',
    shortName: 'AVL',
    color: Color(0xff7a003c),
  );
  static const _bha = SportTeam(
    id: 'bha',
    name: 'Brighton',
    shortName: 'BHA',
    color: Color(0xff0057b8),
  );
  static const _eve = SportTeam(
    id: 'eve',
    name: 'Everton',
    shortName: 'EVE',
    color: Color(0xff003399),
  );
  static const _bur = SportTeam(
    id: 'bur',
    name: 'Burnley',
    shortName: 'BUR',
    color: Color(0xff6c1d45),
  );
  static const _csk = SportTeam(
    id: 'csk',
    name: 'Chennai',
    shortName: 'CSK',
    color: Color(0xfff9cd05),
  );
  static const _rcb = SportTeam(
    id: 'rcb',
    name: 'Bangalore',
    shortName: 'RCB',
    color: Color(0xffd81920),
  );

  // Fixtures are built relative to "now" so statuses stay believable on launch.
  late final DateTime _now = DateTime.now();
  late final DateTime _today = DateTime(_now.year, _now.month, _now.day);

  DateTime _at(int dayOffset, int hour, [int minute = 0]) =>
      _today.add(Duration(days: dayOffset, hours: hour, minutes: minute));

  late final List<SportMatch> _fixtures = [
    // EPL — upcoming, open for prediction (prize strip).
    SportMatch(
      id: 'epl_liv_mc',
      leagueId: 'epl',
      sport: Sport.football,
      home: _liv,
      away: _mc,
      kickoff: _at(0, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
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
      kickoff: _at(-1, 19, 30),
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
      kickoff: _at(-2, 15),
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
      kickoff: _at(0, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
    ),
    // IPL — finished cricket, settled prediction history demo (PJK vs RCB).
    SportMatch(
      id: 'ipl_pjk_rcb',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _pjk,
      away: _rcb,
      kickoff: _at(-3, 15),
      status: MatchStatus.finished,
      homeScore: '221-4',
      awayScore: '198-8 (20 ov)',
      resultLine: 'Punjab won by 23 runs',
      rewardXp: 20,
    ),
    SportMatch(
      id: 'epl_ars_new',
      leagueId: 'epl',
      sport: Sport.football,
      home: _ars,
      away: _new,
      kickoff: _at(1, 20),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 3000 coins',
    ),
    SportMatch(
      id: 'ipl_csk_mi',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _csk,
      away: _mi,
      kickoff: _at(1, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 4000 coins',
    ),
    SportMatch(
      id: 'epl_avl_bha',
      leagueId: 'epl',
      sport: Sport.football,
      home: _avl,
      away: _bha,
      kickoff: _at(2, 19, 45),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 2500 coins',
    ),
    SportMatch(
      id: 'ipl_rcb_srh',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _rcb,
      away: _srh,
      kickoff: _at(2, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 3500 coins',
    ),
    SportMatch(
      id: 'epl_mc_mu',
      leagueId: 'epl',
      sport: Sport.football,
      home: _mc,
      away: _mu,
      kickoff: _at(3, 21),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 5000 coins',
    ),
    SportMatch(
      id: 'ipl_kkr_csk',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _kkr,
      away: _csk,
      kickoff: _at(3, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 4000 coins',
    ),
    SportMatch(
      id: 'epl_whu_eve',
      leagueId: 'epl',
      sport: Sport.football,
      home: _whu,
      away: _eve,
      kickoff: _at(4, 18, 30),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 2000 coins',
    ),
    SportMatch(
      id: 'ipl_mi_pjk',
      leagueId: 'ipl',
      sport: Sport.cricket,
      home: _mi,
      away: _pjk,
      kickoff: _at(4, 15),
      status: MatchStatus.upcoming,
      prizeLabel: 'Win 3500 coins',
    ),
  ];

  late final Map<String, PredictionQuiz> _quizzes = {
    'epl_liv_mc': const PredictionQuiz(
      matchId: 'epl_liv_mc',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
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
    'epl_cfc_new': const PredictionQuiz(
      matchId: 'epl_cfc_new',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 100,
          settledHomeScore: 2,
          settledAwayScore: 1,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
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
    // Settled quiz so history / finished demos can show mixed ✓/✕ rows.
    'epl_mu_whu': const PredictionQuiz(
      matchId: 'epl_mu_whu',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 10,
          settledHomeScore: 2,
          settledAwayScore: 1,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Both teams to score?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Total goals over/under 2.5?',
          options: ['Over 2.5', 'Under 2.5'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Which side scores first?',
          options: ['Man Utd', 'West Ham', 'No goal'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q5',
          text: 'Will a red card be shown?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 1,
        ),
      ],
    ),
    'ipl_pjk_rcb': const PredictionQuiz(
      matchId: 'ipl_pjk_rcb',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins the toss?',
          options: ['Punjab', 'Bangalore'],
          reward: 5,
          settledOptionIndex: 0,
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Total sixes over/under 12.5?',
          options: ['Over 12.5', 'Under 12.5'],
          reward: 5,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q3',
          text: 'Top scorer from Punjab?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q4',
          text: 'Will rain affect play?',
          options: ['Yes', 'No'],
          reward: 5,
          settledOptionIndex: 1,
        ),
        QuizQuestion(
          id: 'q5',
          text: 'Who wins PUNJAB vs RCB?',
          options: ['Punjab', 'Tie', 'Bangalore'],
          reward: 5,
          settledOptionIndex: 0,
        ),
      ],
    ),
    'epl_ars_new': _footballQuiz('epl_ars_new', 'Arsenal', 'Newcastle'),
    'ipl_csk_mi': _cricketQuiz('ipl_csk_mi', 'Chennai', 'Mumbai'),
    'epl_avl_bha': _footballQuiz('epl_avl_bha', 'Aston Villa', 'Brighton'),
    'ipl_rcb_srh': _cricketQuiz('ipl_rcb_srh', 'Bangalore', 'Hyderabad'),
    'epl_mc_mu': _footballQuiz('epl_mc_mu', 'Man City', 'Man Utd'),
    'ipl_kkr_csk': _cricketQuiz('ipl_kkr_csk', 'KKR', 'Chennai'),
    'epl_whu_eve': _footballQuiz('epl_whu_eve', 'West Ham', 'Everton'),
    'ipl_mi_pjk': _cricketQuiz('ipl_mi_pjk', 'Mumbai', 'Punjab'),
  };

  static PredictionQuiz _footballQuiz(
    String matchId,
    String home,
    String away,
  ) => PredictionQuiz(
    matchId: matchId,
    questions: [
      const QuizQuestion(
        id: 'q1',
        text: 'Predict the full-time score',
        type: QuizQuestionType.exactScore,
        reward: 100,
      ),
      const QuizQuestion(
        id: 'q2',
        text: 'Both teams to score?',
        options: ['Yes', 'No'],
        reward: 50,
      ),
      QuizQuestion(
        id: 'q3',
        text: 'Which side scores first?',
        options: [home, away, 'No goal'],
        reward: 75,
      ),
      const QuizQuestion(
        id: 'q4',
        text: 'Total goals over/under 2.5?',
        options: ['Over 2.5', 'Under 2.5'],
        reward: 75,
      ),
    ],
  );

  static PredictionQuiz _cricketQuiz(
    String matchId,
    String home,
    String away,
  ) => PredictionQuiz(
    matchId: matchId,
    questions: [
      QuizQuestion(
        id: 'q1',
        text: 'Who wins the toss?',
        options: [home, away],
        reward: 50,
      ),
      const QuizQuestion(
        id: 'q2',
        text: 'Total sixes over/under 12.5?',
        options: ['Over 12.5', 'Under 12.5'],
        reward: 100,
      ),
      QuizQuestion(
        id: 'q3',
        text: 'Who will win $home vs $away?',
        options: [home, 'Tie', away],
        reward: 100,
      ),
      const QuizQuestion(
        id: 'q4',
        text: 'Will either opener score 50+?',
        options: ['Yes', 'No'],
        reward: 75,
      ),
    ],
  );

  // ── Standings (rank-sorted; seeded to look like a real season) ───────────────
  // Football: diffLabel is goal difference, points = W*3 + D*1.
  // Cricket: diffLabel is net run rate, points = W*2, no drawn column.
  static const _standings = <String, List<TeamStanding>>{
    'epl': [
      TeamStanding(
        team: _liv,
        rank: 1,
        played: 28,
        won: 20,
        drawn: 5,
        lost: 3,
        points: 65,
        diffLabel: '+41',
        form: 'WWDWW',
      ),
      TeamStanding(
        team: _ars,
        rank: 2,
        played: 28,
        won: 19,
        drawn: 6,
        lost: 3,
        points: 63,
        diffLabel: '+38',
        form: 'WDWWL',
      ),
      TeamStanding(
        team: _mc,
        rank: 3,
        played: 28,
        won: 18,
        drawn: 6,
        lost: 4,
        points: 60,
        diffLabel: '+35',
        form: 'WWLDW',
      ),
      TeamStanding(
        team: _avl,
        rank: 4,
        played: 28,
        won: 15,
        drawn: 7,
        lost: 6,
        points: 52,
        diffLabel: '+15',
        form: 'DWWLW',
      ),
      TeamStanding(
        team: _mu,
        rank: 5,
        played: 28,
        won: 14,
        drawn: 6,
        lost: 8,
        points: 48,
        diffLabel: '+9',
        form: 'WLWDL',
      ),
      TeamStanding(
        team: _bha,
        rank: 6,
        played: 28,
        won: 12,
        drawn: 9,
        lost: 7,
        points: 45,
        diffLabel: '+6',
        form: 'DDWLW',
      ),
      TeamStanding(
        team: _new,
        rank: 7,
        played: 28,
        won: 12,
        drawn: 6,
        lost: 10,
        points: 42,
        diffLabel: '+4',
        form: 'LWWDL',
      ),
      TeamStanding(
        team: _cfc,
        rank: 8,
        played: 28,
        won: 11,
        drawn: 8,
        lost: 9,
        points: 41,
        diffLabel: '+2',
        form: 'WDLWD',
      ),
      TeamStanding(
        team: _whu,
        rank: 9,
        played: 28,
        won: 9,
        drawn: 7,
        lost: 12,
        points: 34,
        diffLabel: '-8',
        form: 'LLDWL',
      ),
      TeamStanding(
        team: _eve,
        rank: 10,
        played: 28,
        won: 7,
        drawn: 9,
        lost: 12,
        points: 30,
        diffLabel: '-11',
        form: 'DLLDW',
      ),
      TeamStanding(
        team: _bur,
        rank: 11,
        played: 28,
        won: 4,
        drawn: 6,
        lost: 18,
        points: 18,
        diffLabel: '-29',
        form: 'LLDLL',
      ),
    ],
    'ipl': [
      TeamStanding(
        team: _mi,
        rank: 1,
        played: 8,
        won: 6,
        lost: 2,
        points: 12,
        diffLabel: '+0.95',
        form: 'WWLWW',
      ),
      TeamStanding(
        team: _kkr,
        rank: 2,
        played: 8,
        won: 5,
        lost: 3,
        points: 10,
        diffLabel: '+0.62',
        form: 'WLWWL',
      ),
      TeamStanding(
        team: _csk,
        rank: 3,
        played: 8,
        won: 5,
        lost: 3,
        points: 10,
        diffLabel: '+0.41',
        form: 'WWLWL',
      ),
      TeamStanding(
        team: _srh,
        rank: 4,
        played: 8,
        won: 4,
        lost: 4,
        points: 8,
        diffLabel: '+0.12',
        form: 'LWLWW',
      ),
      TeamStanding(
        team: _pjk,
        rank: 5,
        played: 8,
        won: 3,
        lost: 5,
        points: 6,
        diffLabel: '-0.34',
        form: 'LLWLW',
      ),
      TeamStanding(
        team: _rcb,
        rank: 6,
        played: 8,
        won: 2,
        lost: 6,
        points: 4,
        diffLabel: '-0.88',
        form: 'LLWLL',
      ),
    ],
  };

  @override
  Future<List<League>> leagues() async => const [_epl, _ipl];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day}) async =>
      List.unmodifiable(_fixtures);

  @override
  Future<PredictionQuiz?> quizFor(String matchId) async => _quizzes[matchId];

  @override
  Future<List<TeamStanding>> standings(String leagueId) async =>
      _standings[leagueId] ?? const [];
}
