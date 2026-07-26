import 'dart:math';

import '../models/quiz_trivia.dart';
import '../models/sport_match.dart';

/// Authored, answer-keyed football trivia for the standalone Football Quiz
/// game. Unlike `football_question_bank.dart` (fixture-bound prediction markets
/// that settle later), every question here has a known [TriviaQuestion.correctIndex].
///
/// Four pools — one per [QuizMode]: easy/medium/hard climb in difficulty;
/// `global` is a world/international-football themed capstone. [buildQuizSession]
/// shuffles a pool and takes a subset, so each run stays fresh (replay value).
///
/// Keep answers factually correct — this is the source of truth players score
/// against. When in doubt, prefer evergreen facts over ones that age quickly.
List<TriviaQuestion> buildQuizSession(
  Sport sport,
  QuizMode mode, {
  int count = 8,
  int? seed,
}) {
  final pool = List<TriviaQuestion>.generate(
    kQuizQuestionPoolPerMode,
    (index) => _questionAt(sport, mode, index + 1),
  );
  final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
  pool.shuffle(rng);
  return pool.take(count.clamp(1, pool.length)).toList(growable: false);
}

/// How many questions exist for [mode] — used by the lobby to size sessions.
int quizPoolSize(QuizMode mode) => kQuizQuestionPoolPerMode;

List<TriviaQuestion> buildQuizSet(Sport sport, QuizMode mode, int setNumber) {
  final clampedSet = setNumber.clamp(1, kQuizSetCount);
  final start = (clampedSet - 1) * kQuizQuestionsPerSet + 1;
  return List<TriviaQuestion>.generate(
    kQuizQuestionsPerSet,
    (offset) => _questionAt(sport, mode, start + offset),
    growable: false,
  );
}

TriviaQuestion _questionAt(Sport sport, QuizMode mode, int number) {
  if (sport == Sport.football) {
    final authored = _bank.where((q) => q.mode == mode).toList(growable: false);
    if (number <= authored.length) {
      final q = authored[number - 1];
      return TriviaQuestion(
        id: '${mode.name}_q${number.toString().padLeft(3, '0')}',
        mode: mode,
        prompt: q.prompt,
        options: q.options,
        correctIndex: q.correctIndex,
        backgroundAsset: q.backgroundAsset,
      );
    }
  }
  return _generatedQuestion(sport, mode, number);
}

TriviaQuestion _generatedQuestion(Sport sport, QuizMode mode, int number) {
  final serial = number.toString().padLeft(3, '0');
  final variant = (number - 1) % 10;
  final cycle = ((number - 1) ~/ 10) + 1;
  final id = '${sport.name}_${mode.name}_q$serial';

  final (:prompt, :options, :correctIndex) = switch (sport) {
    Sport.football => switch (mode) {
      QuizMode.easy => _easyScaffold(variant, cycle),
      QuizMode.medium => _mediumScaffold(variant, cycle),
      QuizMode.hard => _hardScaffold(variant, cycle),
      QuizMode.global => _globalScaffold(variant, cycle),
    },
    Sport.cricket => switch (mode) {
      QuizMode.easy => _cricketScaffold('Easy', variant, cycle),
      QuizMode.medium => _cricketScaffold('Medium', variant, cycle),
      QuizMode.hard => _cricketScaffold('Hard', variant, cycle),
      QuizMode.global => _cricketScaffold('Global', variant, cycle),
    },
    Sport.basketball => switch (mode) {
      QuizMode.easy => _basketballScaffold('Easy', variant, cycle),
      QuizMode.medium => _basketballScaffold('Medium', variant, cycle),
      QuizMode.hard => _basketballScaffold('Hard', variant, cycle),
      QuizMode.global => _basketballScaffold('Global', variant, cycle),
    },
    Sport.motorsport => switch (mode) {
      QuizMode.easy => _f1Scaffold('Easy', variant, cycle),
      QuizMode.medium => _f1Scaffold('Medium', variant, cycle),
      QuizMode.hard => _f1Scaffold('Hard', variant, cycle),
      QuizMode.global => _f1Scaffold('Global', variant, cycle),
    },
    Sport.tennis => switch (mode) {
      QuizMode.easy => _tennisScaffold('Easy', variant, cycle),
      QuizMode.medium => _tennisScaffold('Medium', variant, cycle),
      QuizMode.hard => _tennisScaffold('Hard', variant, cycle),
      QuizMode.global => _tennisScaffold('Global', variant, cycle),
    },
  };

  return TriviaQuestion(
    id: id,
    mode: mode,
    prompt: prompt,
    options: options,
    correctIndex: correctIndex,
  );
}

({String prompt, List<String> options, int correctIndex}) _easyScaffold(
  int variant,
  int cycle,
) {
  return switch (variant) {
    0 => (
      prompt: 'Set $cycle: how many players does a football team start with?',
      options: ['9', '10', '11', '12'],
      correctIndex: 2,
    ),
    1 => (
      prompt: 'Set $cycle: which card sends a player off?',
      options: ['Yellow', 'Blue', 'Red', 'White'],
      correctIndex: 2,
    ),
    2 => (
      prompt: 'Set $cycle: what does a goalkeeper protect?',
      options: ['The halfway line', 'The goal', 'The corner flag', 'The bench'],
      correctIndex: 1,
    ),
    3 => (
      prompt: 'Set $cycle: how many points is a league win usually worth?',
      options: ['1', '2', '3', '5'],
      correctIndex: 2,
    ),
    4 => (
      prompt: 'Set $cycle: a foul in the box can lead to what?',
      options: ['Throw-in', 'Penalty', 'Goal kick', 'Drop ball'],
      correctIndex: 1,
    ),
    5 => (
      prompt: 'Set $cycle: football matches are split into how many halves?',
      options: ['1', '2', '3', '4'],
      correctIndex: 1,
    ),
    6 => (
      prompt: 'Set $cycle: what shape is a standard football?',
      options: ['Cube', 'Sphere', 'Pyramid', 'Disc'],
      correctIndex: 1,
    ),
    7 => (
      prompt: 'Set $cycle: what restarts play from the side line?',
      options: ['Corner', 'Throw-in', 'Penalty', 'Kick-off'],
      correctIndex: 1,
    ),
    8 => (
      prompt: 'Set $cycle: which body part is restricted for outfield players?',
      options: ['Head', 'Foot', 'Hand', 'Chest'],
      correctIndex: 2,
    ),
    _ => (
      prompt: 'Set $cycle: what starts each half?',
      options: ['Kick-off', 'Penalty', 'Corner', 'Goal kick'],
      correctIndex: 0,
    ),
  };
}

({String prompt, List<String> options, int correctIndex}) _mediumScaffold(
  int variant,
  int cycle,
) {
  return switch (variant) {
    0 => (
      prompt: 'Set $cycle: which competition is Europe\'s top club tournament?',
      options: ['Champions League', 'FA Cup', 'Copa America', 'AFCON'],
      correctIndex: 0,
    ),
    1 => (
      prompt: 'Set $cycle: El Clasico features Real Madrid and which club?',
      options: ['Valencia', 'Barcelona', 'Sevilla', 'Villarreal'],
      correctIndex: 1,
    ),
    2 => (
      prompt: 'Set $cycle: the Premier League is based in which country?',
      options: ['England', 'Spain', 'Italy', 'Germany'],
      correctIndex: 0,
    ),
    3 => (
      prompt: 'Set $cycle: Camp Nou is associated with which club?',
      options: ['Chelsea', 'Barcelona', 'Inter Milan', 'Benfica'],
      correctIndex: 1,
    ),
    4 => (
      prompt: 'Set $cycle: which country won the 2018 World Cup?',
      options: ['Brazil', 'France', 'Croatia', 'Belgium'],
      correctIndex: 1,
    ),
    5 => (
      prompt: 'Set $cycle: Bayern Munich play in which country?',
      options: ['Germany', 'France', 'Portugal', 'Netherlands'],
      correctIndex: 0,
    ),
    6 => (
      prompt: 'Set $cycle: Serie A is the top league of which country?',
      options: ['Italy', 'England', 'Spain', 'Scotland'],
      correctIndex: 0,
    ),
    7 => (
      prompt:
          'Set $cycle: which trophy is awarded in English knockout football?',
      options: ['FA Cup', 'AFC Cup', 'Gold Cup', 'Leagues Cup'],
      correctIndex: 0,
    ),
    8 => (
      prompt: 'Set $cycle: which club is known for the red liver bird crest?',
      options: ['Liverpool', 'Arsenal', 'Napoli', 'Porto'],
      correctIndex: 0,
    ),
    _ => (
      prompt: 'Set $cycle: UEFA governs football on which continent?',
      options: ['Europe', 'Africa', 'Asia', 'South America'],
      correctIndex: 0,
    ),
  };
}

({String prompt, List<String> options, int correctIndex}) _hardScaffold(
  int variant,
  int cycle,
) {
  return switch (variant) {
    0 => (
      prompt: 'Set $cycle: who scored the Hand of God goal?',
      options: ['Pele', 'Diego Maradona', 'Zinedine Zidane', 'Ronaldo'],
      correctIndex: 1,
    ),
    1 => (
      prompt:
          'Set $cycle: Leicester City won the Premier League in which season?',
      options: ['2013-14', '2014-15', '2015-16', '2016-17'],
      correctIndex: 2,
    ),
    2 => (
      prompt: 'Set $cycle: I Nerazzurri is the nickname of which club?',
      options: ['Inter Milan', 'AC Milan', 'Juventus', 'Roma'],
      correctIndex: 0,
    ),
    3 => (
      prompt: 'Set $cycle: who won the 1966 men\'s World Cup?',
      options: ['Brazil', 'England', 'Argentina', 'Italy'],
      correctIndex: 1,
    ),
    4 => (
      prompt: 'Set $cycle: La Albiceleste refers to which national team?',
      options: ['Argentina', 'Uruguay', 'Chile', 'Paraguay'],
      correctIndex: 0,
    ),
    5 => (
      prompt:
          'Set $cycle: Arsenal\'s unbeaten Premier League side is called what?',
      options: ['Centurions', 'Invincibles', 'Galacticos', 'Busby Babes'],
      correctIndex: 1,
    ),
    6 => (
      prompt:
          'Set $cycle: which club did Sergio Aguero score the 2012 title goal for?',
      options: ['Manchester City', 'Chelsea', 'Arsenal', 'Liverpool'],
      correctIndex: 0,
    ),
    7 => (
      prompt: 'Set $cycle: who managed Inter Milan to the 2009-10 treble?',
      options: [
        'Jose Mourinho',
        'Pep Guardiola',
        'Carlo Ancelotti',
        'Rafa Benitez',
      ],
      correctIndex: 0,
    ),
    8 => (
      prompt: 'Set $cycle: who knocked Brazil out of the 2022 World Cup?',
      options: ['Croatia', 'France', 'Morocco', 'England'],
      correctIndex: 0,
    ),
    _ => (
      prompt: 'Set $cycle: which striker won the 2022 World Cup Golden Boot?',
      options: [
        'Kylian Mbappe',
        'Lionel Messi',
        'Harry Kane',
        'Julian Alvarez',
      ],
      correctIndex: 0,
    ),
  };
}

({String prompt, List<String> options, int correctIndex}) _globalScaffold(
  int variant,
  int cycle,
) {
  return switch (variant) {
    0 => (
      prompt:
          'Set $cycle: the World Cup is normally held every how many years?',
      options: ['2', '3', '4', '5'],
      correctIndex: 2,
    ),
    1 => (
      prompt: 'Set $cycle: AFCON is contested by nations from which continent?',
      options: ['Africa', 'Asia', 'Europe', 'Oceania'],
      correctIndex: 0,
    ),
    2 => (
      prompt: 'Set $cycle: Copa America is associated with which continent?',
      options: ['South America', 'Europe', 'Asia', 'Africa'],
      correctIndex: 0,
    ),
    3 => (
      prompt:
          'Set $cycle: which nation has appeared at every men\'s World Cup?',
      options: ['Brazil', 'Germany', 'Italy', 'France'],
      correctIndex: 0,
    ),
    4 => (
      prompt:
          'Set $cycle: the 2026 World Cup includes USA, Canada and which host?',
      options: ['Mexico', 'Brazil', 'Japan', 'Spain'],
      correctIndex: 0,
    ),
    5 => (
      prompt: 'Set $cycle: Euro tournaments are organized by which body?',
      options: ['UEFA', 'FIFA', 'CONMEBOL', 'CAF'],
      correctIndex: 0,
    ),
    6 => (
      prompt: 'Set $cycle: Brazil play in which confederation?',
      options: ['CONMEBOL', 'UEFA', 'AFC', 'CAF'],
      correctIndex: 0,
    ),
    7 => (
      prompt: 'Set $cycle: Japan belongs to which football confederation?',
      options: ['AFC', 'CAF', 'UEFA', 'CONCACAF'],
      correctIndex: 0,
    ),
    8 => (
      prompt: 'Set $cycle: which country hosted the 2022 World Cup?',
      options: ['Qatar', 'Russia', 'Brazil', 'Germany'],
      correctIndex: 0,
    ),
    _ => (
      prompt: 'Set $cycle: the Women\'s World Cup is run by which global body?',
      options: ['FIFA', 'UEFA', 'AFC', 'CONCACAF'],
      correctIndex: 0,
    ),
  };
}

({String prompt, List<String> options, int correctIndex}) _cricketScaffold(String difficulty, int variant, int cycle) {
  return (
    prompt: 'Set $cycle: which is a standard cricket term? ($difficulty variant $variant)',
    options: ['Bat', 'Racket', 'Club', 'Stick'],
    correctIndex: 0,
  );
}

({String prompt, List<String> options, int correctIndex}) _basketballScaffold(String difficulty, int variant, int cycle) {
  return (
    prompt: 'Set $cycle: how many points for a shot beyond the arc? ($difficulty variant $variant)',
    options: ['1', '2', '3', '4'],
    correctIndex: 2,
  );
}

({String prompt, List<String> options, int correctIndex}) _f1Scaffold(String difficulty, int variant, int cycle) {
  return (
    prompt: 'Set $cycle: what does the checkered flag mean? ($difficulty variant $variant)',
    options: ['Start', 'End of session', 'Hazard', 'Pit stop'],
    correctIndex: 1,
  );
}

({String prompt, List<String> options, int correctIndex}) _tennisScaffold(String difficulty, int variant, int cycle) {
  return (
    prompt: 'Set $cycle: which tournament is played on clay? ($difficulty variant $variant)',
    options: ['Wimbledon', 'US Open', 'French Open', 'Australian Open'],
    correctIndex: 2,
  );
}

const List<TriviaQuestion> _bank = [
  // ───────────────────────── EASY — football basics ─────────────────────────
  TriviaQuestion(
    id: 'e_players',
    mode: QuizMode.easy,
    prompt: 'How many players from each team start on the pitch?',
    options: ['9', '10', '11', '12'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'e_duration',
    mode: QuizMode.easy,
    prompt: 'How long is a standard match, excluding stoppage time?',
    options: ['60 minutes', '80 minutes', '90 minutes', '120 minutes'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'e_halves',
    mode: QuizMode.easy,
    prompt: 'A football match is split into how many halves?',
    options: ['1', '2', '3', '4'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'e_sendoff',
    mode: QuizMode.easy,
    prompt: 'Which card sends a player off the pitch?',
    options: ['Yellow', 'Green', 'Red', 'Blue'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'e_win_points',
    mode: QuizMode.easy,
    prompt: 'How many points does a win earn in most league systems?',
    options: ['1', '2', '3', '4'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'e_penalty',
    mode: QuizMode.easy,
    prompt: 'What is awarded for a foul inside the penalty area?',
    options: ['Corner kick', 'Penalty kick', 'Free kick', 'Throw-in'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'e_keeper_hands',
    mode: QuizMode.easy,
    prompt: 'Who is the only player allowed to handle the ball in open play?',
    options: ['The captain', 'The striker', 'The goalkeeper', 'The referee'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'e_messi_nation',
    mode: QuizMode.easy,
    prompt: 'Which national team does Lionel Messi play for?',
    options: ['Brazil', 'Argentina', 'Spain', 'Portugal'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'e_ronaldo_nation',
    mode: QuizMode.easy,
    prompt: 'Which country does Cristiano Ronaldo represent?',
    options: ['Brazil', 'Italy', 'Portugal', 'Spain'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'e_origin',
    mode: QuizMode.easy,
    prompt: 'Modern football was codified in which country?',
    options: ['Spain', 'England', 'Brazil', 'France'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'e_offside',
    mode: QuizMode.easy,
    prompt: 'Which rule can rule out a goal for being ahead of the defence?',
    options: ['Handball', 'Offside', 'Holding', 'Backpass'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'e_subs',
    mode: QuizMode.easy,
    prompt: 'How many substitutes can most teams now use in a league match?',
    options: ['3', '4', '5', '6'],
    correctIndex: 2,
  ),

  // ──────────────────────── MEDIUM — clubs & cups ───────────────────────────
  TriviaQuestion(
    id: 'm_ucl_most',
    mode: QuizMode.medium,
    prompt:
        'Which club has won the most European Cup / Champions League titles?',
    options: ['AC Milan', 'Bayern Munich', 'Real Madrid', 'Barcelona'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'm_wc_2018',
    mode: QuizMode.medium,
    prompt: 'Who won the 2018 FIFA World Cup?',
    options: ['Croatia', 'France', 'Germany', 'Brazil'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'm_clasico',
    mode: QuizMode.medium,
    prompt: '"El Clásico" is Real Madrid against which club?',
    options: ['Sevilla', 'Valencia', 'Barcelona', 'Atlético Madrid'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'm_ballon',
    mode: QuizMode.medium,
    prompt: 'Who has won the most Ballon d\'Or awards?',
    options: [
      'Cristiano Ronaldo',
      'Lionel Messi',
      'Michel Platini',
      'Johan Cruyff',
    ],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'm_wc_2014_host',
    mode: QuizMode.medium,
    prompt: 'Which country hosted the 2014 World Cup?',
    options: ['South Africa', 'Brazil', 'Russia', 'Germany'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'm_pl_country',
    mode: QuizMode.medium,
    prompt: 'The Premier League is the top division in which country?',
    options: ['Spain', 'Germany', 'England', 'France'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'm_camp_nou',
    mode: QuizMode.medium,
    prompt: 'In which city is the Camp Nou stadium?',
    options: ['Madrid', 'Barcelona', 'Valencia', 'Seville'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'm_wc_top_scorer',
    mode: QuizMode.medium,
    prompt: 'Who is the all-time top scorer in World Cup finals tournaments?',
    options: [
      'Ronaldo Nazário',
      'Miroslav Klose',
      'Just Fontaine',
      'Gerd Müller',
    ],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'm_first_wc',
    mode: QuizMode.medium,
    prompt: 'Which nation won the first FIFA World Cup in 1930?',
    options: ['Brazil', 'Argentina', 'Uruguay', 'Italy'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'm_special_one',
    mode: QuizMode.medium,
    prompt: 'Which manager is nicknamed "The Special One"?',
    options: [
      'Pep Guardiola',
      'José Mourinho',
      'Jürgen Klopp',
      'Carlo Ancelotti',
    ],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'm_morocco_2022',
    mode: QuizMode.medium,
    prompt: 'Which African nation reached the 2022 World Cup semi-finals?',
    options: ['Senegal', 'Ghana', 'Morocco', 'Nigeria'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'm_bayern_2020',
    mode: QuizMode.medium,
    prompt: 'Which German club won the 2020 Champions League?',
    options: ['Borussia Dortmund', 'Bayern Munich', 'RB Leipzig', 'Schalke 04'],
    correctIndex: 1,
  ),

  // ───────────────────────── HARD — deep-cut trivia ─────────────────────────
  TriviaQuestion(
    id: 'h_golden_boot_2022',
    mode: QuizMode.hard,
    prompt: 'Who won the Golden Boot at the 2022 World Cup?',
    options: [
      'Lionel Messi',
      'Kylian Mbappé',
      'Julián Álvarez',
      'Olivier Giroud',
    ],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_aguero_2012',
    mode: QuizMode.hard,
    prompt:
        'Sergio Agüero\'s famous last-minute 2012 title-winning goal was for?',
    options: ['Manchester United', 'Manchester City', 'Arsenal', 'Chelsea'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_ucl_top_scorer',
    mode: QuizMode.hard,
    prompt: 'Who is the all-time top scorer in the Champions League?',
    options: [
      'Lionel Messi',
      'Robert Lewandowski',
      'Cristiano Ronaldo',
      'Karim Benzema',
    ],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'h_brazil_2022',
    mode: QuizMode.hard,
    prompt: 'Which team knocked Brazil out of the 2022 World Cup?',
    options: ['Argentina', 'Netherlands', 'Croatia', 'France'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'h_1966',
    mode: QuizMode.hard,
    prompt: 'Who won the 1966 World Cup?',
    options: ['West Germany', 'England', 'Brazil', 'Italy'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_nerazzurri',
    mode: QuizMode.hard,
    prompt: 'Which club is nicknamed "I Nerazzurri"?',
    options: ['AC Milan', 'Juventus', 'Inter Milan', 'Roma'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'h_leicester',
    mode: QuizMode.hard,
    prompt: 'Who managed Leicester City to the 2015–16 Premier League title?',
    options: [
      'Nigel Pearson',
      'Claudio Ranieri',
      'Brendan Rodgers',
      'Sam Allardyce',
    ],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_hand_of_god',
    mode: QuizMode.hard,
    prompt: 'Who scored the "Hand of God" goal in 1986?',
    options: ['Pelé', 'Diego Maradona', 'Gabriel Batistuta', 'Mario Kempes'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_treble_2010',
    mode: QuizMode.hard,
    prompt: 'Which club won the treble in 2009–10 under José Mourinho?',
    options: ['Barcelona', 'Inter Milan', 'Bayern Munich', 'Manchester United'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_pl_season_record',
    mode: QuizMode.hard,
    prompt:
        'Who holds the record for most goals in a 38-game Premier League season?',
    options: ['Mohamed Salah', 'Erling Haaland', 'Alan Shearer', 'Andy Cole'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_albiceleste',
    mode: QuizMode.hard,
    prompt: 'Which national team is known as "La Albiceleste"?',
    options: ['Uruguay', 'Argentina', 'Chile', 'Colombia'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'h_invincibles',
    mode: QuizMode.hard,
    prompt:
        'Which club went unbeaten in the 2003–04 Premier League ("Invincibles")?',
    options: ['Manchester United', 'Chelsea', 'Arsenal', 'Liverpool'],
    correctIndex: 2,
  ),

  // ───────────────────── GLOBAL — world / international ──────────────────────
  TriviaQuestion(
    id: 'g_wc_2022',
    mode: QuizMode.global,
    prompt: 'Which country won the 2022 FIFA World Cup?',
    options: ['France', 'Argentina', 'Croatia', 'Morocco'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_copa',
    mode: QuizMode.global,
    prompt: 'The Copa América is contested by nations from which continent?',
    options: ['Africa', 'Europe', 'South America', 'Asia'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'g_first_womens_wc',
    mode: QuizMode.global,
    prompt: 'Which country won the first Women\'s World Cup in 1991?',
    options: ['Norway', 'United States', 'Germany', 'China'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_afcon',
    mode: QuizMode.global,
    prompt: 'What is the Africa Cup of Nations commonly abbreviated as?',
    options: ['CONCACAF', 'AFCON', 'AFC', 'COSAFA'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_brazil_every',
    mode: QuizMode.global,
    prompt: 'Which nation has appeared at every men\'s World Cup finals?',
    options: ['Germany', 'Brazil', 'Italy', 'Argentina'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_euro_cycle',
    mode: QuizMode.global,
    prompt: 'The UEFA European Championship is held every how many years?',
    options: ['2', '3', '4', '5'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'g_2002_cohost',
    mode: QuizMode.global,
    prompt: 'Which country co-hosted the 2002 World Cup with Japan?',
    options: ['China', 'South Korea', 'Qatar', 'Thailand'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_qatar_year',
    mode: QuizMode.global,
    prompt: 'In which year did Qatar host the World Cup?',
    options: ['2014', '2018', '2022', '2026'],
    correctIndex: 2,
  ),
  TriviaQuestion(
    id: 'g_euro_2020',
    mode: QuizMode.global,
    prompt: 'Which nation won UEFA Euro 2020 (played in 2021)?',
    options: ['England', 'Italy', 'Spain', 'France'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_2026_hosts',
    mode: QuizMode.global,
    prompt:
        'The 2026 World Cup is co-hosted by the USA, Canada and which nation?',
    options: ['Brazil', 'Mexico', 'Costa Rica', 'Argentina'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_neymar',
    mode: QuizMode.global,
    prompt: 'Which national team does Neymar represent?',
    options: ['Portugal', 'Brazil', 'Argentina', 'Uruguay'],
    correctIndex: 1,
  ),
  TriviaQuestion(
    id: 'g_wc_cycle',
    mode: QuizMode.global,
    prompt: 'How often is the FIFA World Cup held?',
    options: [
      'Every 2 years',
      'Every 3 years',
      'Every 4 years',
      'Every 5 years',
    ],
    correctIndex: 2,
  ),
];
