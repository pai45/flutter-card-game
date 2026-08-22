// Generates the authored Tennis Quiz assets and their development-only audit
// ledger. Run from the repository root with the bundled Dart SDK:
//
//   .\flutter\bin\cache\dart-sdk\bin\dart.exe tool\generate_tennis_quiz.dart
//
// Pass --report to print outstanding shortfalls instead of throwing, which is
// the loop you author against.
//
// Runtime assets keep the compact p/o/a schema used by every Knowledge Arena
// sport. Audit metadata is deliberately kept out of the app bundle.
//
// Like the motorsport generator (and unlike cricket and basketball), this bank
// does NOT pad short pools by re-wording a seed fact into several prompts.
// Every one of the 2,000 questions is its own distinct, recorded tennis fact.
// There is no variant path to fall back into: a short pool is a hard failure.
//
// Two axes set difficulty:
//   mode = breadth  (easy recognition -> medium structure -> hard deep cuts ->
//                    global world-breadth)
//   band = obscurity (band 1 household names of ANY era -> band 5 deep cuts)
//
// Chronology is NOT the band axis here. Borg, McEnroe, Navratilova and Court are
// household names, so a 1980 Wimbledon final belongs in band 1, not band 5.
// Era only trends older as a tiebreak.
import 'dart:convert';
import 'dart:io';

const _modes = ['easy', 'medium', 'hard', 'global'];
const _scopes = [
  'atp',
  'wta',
  'majors_events',
  'team_events',
  'doubles',
  'rules_terms',
  'world_other',
];

/// Facts are frozen here. The tour record is authored through the end of the
/// 2025 season; no 2026 results appear, because the 2026 majors fell outside
/// what could be verified against a primary source at this date.
const _cutoff = '2026-08-21';

const _sourceRegistry = <String, Map<String, String>>{
  'atp-rankings': {
    'kind': 'primary',
    'title': 'ATP Tour official singles rankings archive',
    'url': 'https://www.atptour.com/en/rankings/singles',
  },
  'atp-players': {
    'kind': 'primary',
    'title': 'ATP Tour official player profiles',
    'url': 'https://www.atptour.com/en/players',
  },
  'atp-tournaments': {
    'kind': 'primary',
    'title': 'ATP Tour official tournament archive',
    'url': 'https://www.atptour.com/en/tournaments',
  },
  'atp-finals': {
    'kind': 'primary',
    'title': 'Nitto ATP Finals official history',
    'url': 'https://www.atptour.com/en/tournaments/nitto-atp-finals/605/overview',
  },
  'wta-rankings': {
    'kind': 'primary',
    'title': 'WTA official singles rankings archive',
    'url': 'https://www.wtatennis.com/rankings/singles',
  },
  'wta-players': {
    'kind': 'primary',
    'title': 'WTA official player profiles',
    'url': 'https://www.wtatennis.com/players',
  },
  'wta-tournaments': {
    'kind': 'primary',
    'title': 'WTA official tournament archive',
    'url': 'https://www.wtatennis.com/tournaments',
  },
  'ausopen-history': {
    'kind': 'primary',
    'title': 'Australian Open official history and roll of honour',
    'url': 'https://ausopen.com/history',
  },
  'rolandgarros-history': {
    'kind': 'primary',
    'title': 'Roland-Garros official palmares',
    'url': 'https://www.rolandgarros.com/en-us/palmares',
  },
  'wimbledon-history': {
    'kind': 'primary',
    'title': 'Wimbledon official draws archive and roll of honour',
    'url': 'https://www.wimbledon.com/en_GB/draws_archive/',
  },
  'usopen-history': {
    'kind': 'primary',
    'title': 'US Open official draws and champions archive',
    'url': 'https://www.usopen.org/en_US/scores/draws/',
  },
  'daviscup-history': {
    'kind': 'primary',
    'title': 'Davis Cup official history and champions archive',
    'url': 'https://www.daviscup.com/en/history.aspx',
  },
  'bjkcup-history': {
    'kind': 'primary',
    'title': 'Billie Jean King Cup official history archive',
    'url': 'https://www.billiejeankingcup.com/en/history.aspx',
  },
  'itf-rules': {
    'kind': 'primary',
    'title': 'ITF Rules of Tennis and regulations',
    'url': 'https://www.itftennis.com/en/about-us/governance/rules-and-regulations/',
  },
  'itf-world-tour': {
    'kind': 'primary',
    'title': 'ITF World Tennis Tour calendar and structure',
    'url': 'https://www.itftennis.com/en/tournament-calendar/',
  },
  'itf-wheelchair': {
    'kind': 'primary',
    'title': 'ITF wheelchair tennis rankings and results',
    'url': 'https://www.itftennis.com/en/tournament-calendar/wheelchair-tennis/',
  },
  'olympics-tennis': {
    'kind': 'primary',
    'title': 'Olympics official tennis results archive',
    'url': 'https://olympics.com/en/sports/tennis/',
  },
  'lavercup-results': {
    'kind': 'primary',
    'title': 'Laver Cup official results archive',
    'url': 'https://lavercup.com/results/',
  },
  'tennis-hall-of-fame': {
    'kind': 'primary',
    'title': 'International Tennis Hall of Fame inductee archive',
    'url': 'https://www.tennisfame.com/hall-of-famers/',
  },
};

final class _Fact {
  const _Fact({
    required this.mode,
    required this.band,
    required this.scope,
    required this.relation,
    required this.subject,
    required this.answer,
    required this.optionPool,
    required this.factKey,
    required this.competition,
    required this.season,
    required this.sources,
  });

  final String mode;
  final int band;
  final String scope;
  final String relation;
  final String subject;
  final String answer;
  final List<String> optionPool;
  final String factKey;
  final String competition;
  final String season;
  final List<String> sources;
}

final _facts = <String, List<_Fact>>{};
final _cursors = <String, int>{};

String _poolKey(String mode, int band, String scope) => '$mode/$band/$scope';

/// Questions of each scope inside every 100-question band. Mode totals are 5x
/// these, so `atp` easy is 240 of the mode's 500 questions.
///
/// The men's tour leads the bank at roughly 43% overall (and comfortably over
/// half once the men's share of majors, doubles and team events is counted),
/// which is the men-leaning mix this bank was scoped for. The women's tour holds
/// a fixed fifth of every band so no mode can be cleared without it.
///
/// ATP steps back sharply in GLOBAL (50 -> 26 a band) while team events and the
/// wider tennis world surge, so the world capstone reads as a different category
/// rather than "hard mode again".
Map<String, int> _scopeCounts(String mode) => switch (mode) {
  'easy' => {
    'atp': 48,
    'wta': 20,
    'majors_events': 12,
    'team_events': 6,
    'doubles': 5,
    'rules_terms': 7,
    'world_other': 2,
  },
  'medium' => {
    'atp': 49,
    'wta': 22,
    'majors_events': 11,
    'team_events': 7,
    'doubles': 6,
    'rules_terms': 3,
    'world_other': 2,
  },
  'hard' => {
    'atp': 50,
    'wta': 22,
    'majors_events': 10,
    'team_events': 7,
    'doubles': 7,
    'rules_terms': 1,
    'world_other': 3,
  },
  'global' => {
    'atp': 26,
    'wta': 21,
    'majors_events': 10,
    'team_events': 18,
    'doubles': 11,
    'rules_terms': 2,
    'world_other': 12,
  },
  _ => throw ArgumentError.value(mode),
};

void main(List<String> args) {
  final reportOnly = args.contains('--report');
  _addAtpFacts();
  _addWtaFacts();
  _addMajorsFacts();
  _addTeamEventFacts();
  _addDoublesFacts();
  _addRulesTermsFacts();
  _addWorldOtherFacts();
  _assertPoolsFilled(reportOnly: reportOnly);

  final auditQuestions = <String, Object?>{};
  final seenPrompts = <String, String>{};
  final seenFactKeys = <String>{};

  for (final mode in _modes) {
    final bands = <String, Object?>{};
    var questionNumber = 0;
    for (var band = 1; band <= 5; band++) {
      final remaining = Map<String, int>.from(_scopeCounts(mode));
      final entries = <Map<String, Object?>>[];
      while (entries.length < 100) {
        for (final scope in _scopes) {
          if ((remaining[scope] ?? 0) == 0) continue;
          final fact = _take(mode, band, scope);
          final prompt = _prompt(fact);
          final normalized = _normalize(prompt);
          final clash = seenPrompts[normalized];
          if (clash != null) {
            throw StateError('Duplicate prompt "$prompt" (also $clash)');
          }
          seenPrompts[normalized] = '$mode/$band/${fact.factKey}';
          if (!seenFactKeys.add(fact.factKey)) {
            throw StateError('Duplicate fact key: ${fact.factKey}');
          }

          questionNumber++;
          final id =
              'tennis_${mode}_q${questionNumber.toString().padLeft(3, '0')}';
          final correctIndex = entries.length % 4;
          final distractors = _distractors(fact);
          final options = List<String>.filled(4, '');
          options[correctIndex] = fact.answer;
          var distractorIndex = 0;
          for (var optionIndex = 0; optionIndex < 4; optionIndex++) {
            if (optionIndex == correctIndex) continue;
            options[optionIndex] = distractors[distractorIndex++];
          }

          _validateQuestion(prompt, options);
          entries.add({'p': prompt, 'o': options, 'a': correctIndex});
          auditQuestions[id] = {
            'answer': fact.answer,
            'factKey': fact.factKey,
            'scope': fact.scope,
            'competition': fact.competition,
            'season': fact.season,
            'cutoff': _cutoff,
            'difficulty': {
              'mode': mode,
              'band': band,
              'set': ((questionNumber - 1) ~/ 10) + 1,
            },
            'sources': fact.sources,
          };
          remaining[scope] = remaining[scope]! - 1;
        }
      }
      bands['$band'] = entries;
    }
    _writeJson('assets/quiz/tennis_$mode.json', {
      'sport': 'tennis',
      'mode': mode,
      'version': 1,
      'bands': bands,
    });
  }

  _writeJson('tool/quiz_audit/tennis.json', {
    'sport': 'tennis',
    'version': 1,
    'factualCutoff': _cutoff,
    'sources': _sourceRegistry,
    'questions': auditQuestions,
  });
  stdout.writeln(
    'Generated ${auditQuestions.length} tennis questions and audit entries.',
  );
  _reportSurplus();
}

/// Hard-fails when any mode/band/scope bucket is short of authored facts.
///
/// This is the guard that keeps the bank at 2,000 *distinct* facts: there is no
/// padding step, so a shortfall can only be fixed by authoring more real facts.
void _assertPoolsFilled({bool reportOnly = false}) {
  final shortfalls = <String>[];
  for (final mode in _modes) {
    for (var band = 1; band <= 5; band++) {
      for (final entry in _scopeCounts(mode).entries) {
        final key = _poolKey(mode, band, entry.key);
        final have = _facts[key]?.length ?? 0;
        if (have < entry.value) {
          shortfalls.add('  $key needs ${entry.value}, has $have');
        }
      }
    }
  }
  if (shortfalls.isEmpty) return;
  var missing = 0;
  for (final line in shortfalls) {
    final match = RegExp(r'needs (\d+), has (\d+)').firstMatch(line);
    if (match != null) {
      missing += int.parse(match.group(1)!) - int.parse(match.group(2)!);
    }
  }
  final message =
      'Not enough authored facts:\n${shortfalls.join('\n')}\n'
      '${shortfalls.length} bucket(s) short, $missing fact(s) missing.';
  if (reportOnly) {
    stdout.writeln(message);
    exit(2);
  }
  throw StateError(message);
}

/// Prints buckets holding more facts than the ladder consumes, so surplus
/// authoring is visible rather than silently dropped.
void _reportSurplus() {
  final surplus = <String>[];
  var wasted = 0;
  for (final mode in _modes) {
    for (var band = 1; band <= 5; band++) {
      for (final entry in _scopeCounts(mode).entries) {
        final key = _poolKey(mode, band, entry.key);
        final have = _facts[key]?.length ?? 0;
        if (have > entry.value) {
          surplus.add('  $key: ${have - entry.value} unused');
          wasted += have - entry.value;
        }
      }
    }
  }
  if (surplus.isEmpty) {
    stdout.writeln('Every authored fact is used.');
    return;
  }
  stdout.writeln('$wasted authored fact(s) unused:');
  for (final line in surplus) {
    stdout.writeln(line);
  }
}

_Fact _take(String mode, int band, String scope) {
  final key = _poolKey(mode, band, scope);
  final pool = _facts[key]!;
  final cursor = _cursors[key] ?? 0;
  if (cursor >= pool.length) throw StateError('Exhausted $key');
  _cursors[key] = cursor + 1;
  return pool[cursor];
}

/// Registers one table of `subject|answer` rows (optionally `|season`) into a
/// single mode/band/scope bucket. Distractors are drawn from the other answers
/// in the same table, which is what keeps every option plausible — so every
/// table must be homogeneous (all player names, or all countries, or all years).
void _addRows({
  required String mode,
  required int band,
  required String scope,
  required String relation,
  required String competition,
  required List<String> sources,
  required String data,
  List<String> extraOptions = const [],
}) {
  final rows = _rows(data);
  final optionPool = <String>{
    ...rows.map((row) => row[1]),
    ...extraOptions,
  }.toList();
  if (optionPool.length < 4) {
    throw StateError('$mode/$band/$scope/$relation needs four distinct answers');
  }
  for (final row in rows) {
    final subject = row[0];
    final answer = row[1];
    final season = row.length > 2 && row[2].isNotEmpty ? row[2] : _cutoff;
    _facts.putIfAbsent(_poolKey(mode, band, scope), () => []).add(
      _Fact(
        mode: mode,
        band: band,
        scope: scope,
        relation: relation,
        subject: subject,
        answer: answer,
        optionPool: optionPool,
        factKey:
            '${_slug(scope)}-${_slug(relation)}-${_slug(subject)}-${_slug(answer)}',
        competition: competition,
        season: season,
        sources: sources,
      ),
    );
  }
}

/// One phrasing per relation. Because every fact is distinct there is no need
/// for the eight-way rewording the cricket and basketball generators use to pad
/// their pools — the subject alone makes each prompt unique.
///
/// Every singles/doubles relation names its discipline. "Who won the 2019
/// Wimbledon title?" would be ambiguous between the men's and women's draws,
/// and would collide as a duplicate prompt.
String _prompt(_Fact fact) {
  final subject = fact.subject;
  return switch (fact.relation) {
    'definition' => 'In tennis, what does “$subject” mean?',
    'scoring_rule' => 'In tennis, $subject?',
    'slam_champion_men' => 'Who won the $subject men’s singles title?',
    'slam_champion_women' => 'Who won the $subject women’s singles title?',
    'slam_runner_up_men' => 'Who lost the $subject men’s singles final?',
    'slam_runner_up_women' =>
      'Who lost the $subject women’s singles final?',
    'player_nationality' => 'Which country did $subject represent?',
    'player_slam_count' =>
      'How many Grand Slam singles titles did $subject win?',
    'year_end_no1_men' =>
      'Who finished $subject as the ATP year-end world No. 1?',
    'year_end_no1_women' =>
      'Who finished $subject as the WTA year-end world No. 1?',
    'event_winner_men' => 'Who won the $subject men’s singles?',
    'event_winner_women' => 'Who won the $subject women’s singles?',
    'tour_finals_winner' => 'Who won the $subject?',
    'masters_winner' => 'Who won the $subject?',
    'event_surface' => 'Which surface is the $subject played on?',
    'event_city' => 'In which city is the $subject played?',
    'event_country' => 'Which country hosts the $subject?',
    'event_venue' => 'Which venue hosts the $subject?',
    'second_court' => 'Which is the second-largest show court at $subject?',
    'introduced_year' => 'In which year was $subject introduced?',
    'show_court' => 'What is the main show court at $subject called?',
    'trophy_name' => 'What is the $subject singles trophy called?',
    'first_year' => 'In which year was $subject first held?',
    'team_event_winner' => 'Which nation won the $subject?',
    'olympic_gold_men' =>
      'Who won the $subject men’s singles gold medal?',
    'olympic_gold_women' =>
      'Who won the $subject women’s singles gold medal?',
    'doubles_champion_men' => 'Who won the $subject men’s doubles title?',
    'doubles_champion_women' =>
      'Who won the $subject women’s doubles title?',
    'doubles_champion_mixed' => 'Who won the $subject mixed doubles title?',
    'doubles_partner' =>
      'Who was $subject’s most successful doubles partner?',
    'coach_of' => 'Who coached $subject?',
    'play_style' => 'Which playing style is $subject known for?',
    'record_holder' => 'Who holds the record for $subject?',
    'record_value' => 'What is the record for $subject?',
    'hall_of_fame_year' =>
      'In which year was $subject inducted into the Hall of Fame?',
    'retirement_year' =>
      'In which year did $subject play their last tour match?',
    'tour_tier' => 'Which tour tier does the $subject belong to?',
    'wheelchair_champion' =>
      'Who won the $subject wheelchair singles title?',
    'junior_champion_boys' => 'Who won the $subject boys’ singles title?',
    'junior_champion_girls' => 'Who won the $subject girls’ singles title?',
    'home_nation' => 'Which nation does the $subject represent tennis for?',
    _ => throw StateError('Unknown relation ${fact.relation}'),
  };
}

List<String> _distractors(_Fact fact) {
  final candidates = fact.optionPool
      .where((value) => value != fact.answer)
      .toList();
  if (candidates.length < 3) {
    throw StateError('Not enough distractors for ${fact.factKey}');
  }
  final start = _stableHash(fact.factKey) % candidates.length;
  return [
    for (var i = 0; i < 3; i++) candidates[(start + i) % candidates.length],
  ];
}

void _validateQuestion(String prompt, List<String> options) {
  if (prompt.length > 110) {
    throw StateError('Prompt too long (${prompt.length}): $prompt');
  }
  for (final option in options) {
    if (option.length > 34) {
      throw StateError('Option too long (${option.length}) for $prompt');
    }
    if (option.trim().isEmpty) {
      throw StateError('Empty option for $prompt');
    }
    if (option == prompt) {
      throw StateError('Option repeats the prompt: $prompt');
    }
  }
  if (options.toSet().length != 4) {
    throw StateError('Duplicate options for $prompt: $options');
  }
  // Time-relative wording rots; every prompt must be anchored to a season or
  // event instead.
  final lower = prompt.toLowerCase();
  for (final banned in const [
    'current',
    'currently',
    'this season',
    'last season',
    'so far',
    'to date',
    'reigning',
  ]) {
    if (lower.contains(banned)) {
      throw StateError('Prompt uses time-relative wording "$banned": $prompt');
    }
  }
}

void _writeJson(String relativePath, Object value) {
  final file = File(relativePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}

List<List<String>> _rows(String data) => data
    .trim()
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .map((line) => line.split('|').map((cell) => cell.trim()).toList())
    .toList();

int _stableHash(String value) {
  var hash = 2166136261;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash;
}

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// ─────────────────────────────────────────────────────────────────────────────
// ATP — MEN'S SINGLES TOUR — 865 facts (easy 240, medium 245, hard 250,
// global 130). The largest scope, as scoped.
//
// Band 1 is household names of ANY era; bands 2-5 step down in recognition,
// with era used only as a tiebreak.
// ─────────────────────────────────────────────────────────────────────────────

void _addAtpFacts() {
  _addAtpEasyBand1();
  _addAtpEasyBand2();
  _addAtpEasyBand3();
  _addAtpEasyBand4();
  _addAtpEasyBand5();
  _addAtpMedium();
  _addAtpHard();
  _addAtpGlobal();
}

void _addAtpEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Roger Federer|Switzerland
Rafael Nadal|Spain
Novak Djokovic|Serbia
Andy Murray|United Kingdom
Pete Sampras|United States
Andre Agassi|United States
Björn Borg|Sweden
John McEnroe|United States
Jimmy Connors|United States
Ivan Lendl|Czechoslovakia
Boris Becker|Germany
Stefan Edberg|Sweden
Carlos Alcaraz|Spain
Jannik Sinner|Italy
Daniil Medvedev|Russia
Alexander Zverev|Germany
Stan Wawrinka|Switzerland
Juan Martín del Potro|Argentina
Rod Laver|Australia
Guillermo Vilas|Argentina
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'atp',
    relation: 'player_slam_count',
    competition: 'Grand Slam singles',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
Novak Djokovic|24
Rafael Nadal|22
Roger Federer|20
Pete Sampras|14
Björn Borg|11
Andre Agassi|8
John McEnroe|7
Boris Becker|6
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
2008 Wimbledon|Rafael Nadal|2008
2019 Wimbledon|Novak Djokovic|2019
2017 Australian Open|Roger Federer|2017
2023 US Open|Novak Djokovic|2023
2022 Wimbledon|Novak Djokovic|2022
2024 Australian Open|Jannik Sinner|2024
2022 US Open|Carlos Alcaraz|2022
2023 Wimbledon|Carlos Alcaraz|2023
2013 Wimbledon|Andy Murray|2013
2009 US Open|Juan Martín del Potro|2009
1980 Wimbledon|Björn Borg|1980
1984 US Open|John McEnroe|1984
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'atp',
    relation: 'play_style',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
Rafael Nadal|heavy topspin left-hander
Roger Federer|attacking all-court one-hander
Novak Djokovic|elastic baseline counter-punching
John McEnroe|serve-and-volley touch play
Pete Sampras|big serve and volley
Ivan Lendl|power baseline forehand
Björn Borg|relentless topspin baseline
Andre Agassi|early-ball return aggression
''',
  );
}

void _addAtpEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
2010 Wimbledon|Rafael Nadal|2010
2011 Wimbledon|Novak Djokovic|2011
2012 Wimbledon|Roger Federer|2012
2014 Wimbledon|Novak Djokovic|2014
2015 Wimbledon|Novak Djokovic|2015
2016 Wimbledon|Andy Murray|2016
2017 Wimbledon|Roger Federer|2017
2018 Wimbledon|Novak Djokovic|2018
2021 Wimbledon|Novak Djokovic|2021
2024 Wimbledon|Carlos Alcaraz|2024
2025 Wimbledon|Jannik Sinner|2025
2010 US Open|Rafael Nadal|2010
2011 US Open|Novak Djokovic|2011
2012 US Open|Andy Murray|2012
2013 US Open|Rafael Nadal|2013
2014 US Open|Marin Čilić|2014
2015 US Open|Novak Djokovic|2015
2016 US Open|Stan Wawrinka|2016
2017 US Open|Rafael Nadal|2017
2018 US Open|Novak Djokovic|2018
2019 US Open|Rafael Nadal|2019
2020 US Open|Dominic Thiem|2020
2021 US Open|Daniil Medvedev|2021
2024 US Open|Jannik Sinner|2024
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Dominic Thiem|Austria
Marin Čilić|Croatia
Casper Ruud|Norway
Stefanos Tsitsipas|Greece
Grigor Dimitrov|Bulgaria
Milos Raonic|Canada
Kei Nishikori|Japan
Gaël Monfils|France
Tomáš Berdych|Czech Republic
David Ferrer|Spain
Andy Roddick|United States
Lleyton Hewitt|Australia
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'atp',
    relation: 'year_end_no1_men',
    competition: 'ATP year-end rankings',
    sources: const ['atp-rankings', 'atp-players'],
    data: '''
2010|Rafael Nadal|2010
2011|Novak Djokovic|2011
2012|Novak Djokovic|2012
2013|Rafael Nadal|2013
2014|Novak Djokovic|2014
2015|Novak Djokovic|2015
2016|Andy Murray|2016
2017|Rafael Nadal|2017
2018|Novak Djokovic|2018
2019|Rafael Nadal|2019
2020|Novak Djokovic|2020
2021|Novak Djokovic|2021
''',
    extraOptions: const ['Roger Federer', 'Stan Wawrinka', 'Marin Čilić'],
  );
}

void _addAtpEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
2000 Wimbledon|Pete Sampras|2000
2001 Wimbledon|Goran Ivanišević|2001
2002 Wimbledon|Lleyton Hewitt|2002
2003 Wimbledon|Roger Federer|2003
2004 Wimbledon|Roger Federer|2004
2005 Wimbledon|Roger Federer|2005
2006 Wimbledon|Roger Federer|2006
2007 Wimbledon|Roger Federer|2007
2009 Wimbledon|Roger Federer|2009
2003 French Open|Juan Carlos Ferrero|2003
2004 French Open|Gastón Gaudio|2004
2005 French Open|Rafael Nadal|2005
2006 French Open|Rafael Nadal|2006
2007 French Open|Rafael Nadal|2007
2008 French Open|Rafael Nadal|2008
2009 French Open|Roger Federer|2009
2000 US Open|Marat Safin|2000
2001 US Open|Lleyton Hewitt|2001
2002 US Open|Pete Sampras|2002
2003 US Open|Andy Roddick|2003
2004 US Open|Roger Federer|2004
2005 US Open|Roger Federer|2005
2006 US Open|Roger Federer|2006
2007 US Open|Roger Federer|2007
''',
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
Marat Safin|Russia
Goran Ivanišević|Croatia
Yevgeny Kafelnikov|Russia
Carlos Moyá|Spain
Juan Carlos Ferrero|Spain
Gustavo Kuerten|Brazil
Patrick Rafter|Australia
Michael Chang|United States
Jim Courier|United States
Thomas Muster|Austria
Richard Krajicek|Netherlands
Nikolay Davydenko|Russia
''',
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'atp',
    relation: 'tour_finals_winner',
    competition: 'ATP Finals',
    sources: const ['atp-finals', 'atp-tournaments'],
    data: '''
2000 ATP Finals|Gustavo Kuerten|2000
2001 ATP Finals|Lleyton Hewitt|2001
2002 ATP Finals|Lleyton Hewitt|2002
2003 ATP Finals|Roger Federer|2003
2004 ATP Finals|Roger Federer|2004
2005 ATP Finals|David Nalbandian|2005
2006 ATP Finals|Roger Federer|2006
2007 ATP Finals|Roger Federer|2007
2008 ATP Finals|Novak Djokovic|2008
2009 ATP Finals|Nikolay Davydenko|2009
2010 ATP Finals|Roger Federer|2010
2011 ATP Finals|Roger Federer|2011
''',
  );
}

void _addAtpEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
1981 Wimbledon|John McEnroe|1981
1982 Wimbledon|Jimmy Connors|1982
1983 Wimbledon|John McEnroe|1983
1985 Wimbledon|Boris Becker|1985
1986 Wimbledon|Boris Becker|1986
1987 Wimbledon|Pat Cash|1987
1988 Wimbledon|Stefan Edberg|1988
1990 Wimbledon|Stefan Edberg|1990
1991 Wimbledon|Michael Stich|1991
1992 Wimbledon|Andre Agassi|1992
1993 Wimbledon|Pete Sampras|1993
1996 Wimbledon|Richard Krajicek|1996
1998 Wimbledon|Pete Sampras|1998
1981 French Open|Björn Borg|1981
1983 French Open|Yannick Noah|1983
1984 French Open|Ivan Lendl|1984
1989 French Open|Michael Chang|1989
1990 French Open|Andrés Gómez|1990
1991 French Open|Jim Courier|1991
1995 French Open|Thomas Muster|1995
1997 French Open|Gustavo Kuerten|1997
1999 French Open|Andre Agassi|1999
1990 US Open|Pete Sampras|1990
1991 US Open|Stefan Edberg|1991
''',
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
Mats Wilander|Sweden
Yannick Noah|France
Pat Cash|Australia
Michael Stich|Germany
Sergi Bruguera|Spain
Petr Korda|Czech Republic
Marcelo Ríos|Chile
Cédric Pioline|France
Todd Martin|United States
Wayne Ferreira|South Africa
Andrés Gómez|Ecuador
Miloslav Mečíř|Czechoslovakia
''',
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'atp',
    relation: 'year_end_no1_men',
    competition: 'ATP year-end rankings',
    sources: const ['atp-rankings', 'tennis-hall-of-fame'],
    data: '''
1980|Björn Borg|1980
1982|John McEnroe|1982
1983|John McEnroe|1983
1985|Ivan Lendl|1985
1986|Ivan Lendl|1986
1987|Ivan Lendl|1987
1988|Mats Wilander|1988
1989|Ivan Lendl|1989
1990|Stefan Edberg|1990
1991|Stefan Edberg|1991
1992|Jim Courier|1992
1993|Pete Sampras|1993
''',
  );
}

void _addAtpEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
1969 Wimbledon|Rod Laver|1969
1970 Wimbledon|John Newcombe|1970
1971 Wimbledon|John Newcombe|1971
1972 Wimbledon|Stan Smith|1972
1974 Wimbledon|Jimmy Connors|1974
1975 Wimbledon|Arthur Ashe|1975
1976 Wimbledon|Björn Borg|1976
1977 Wimbledon|Björn Borg|1977
1978 Wimbledon|Björn Borg|1978
1979 Wimbledon|Björn Borg|1979
1968 US Open|Arthur Ashe|1968
1970 US Open|Ken Rosewall|1970
1971 US Open|Stan Smith|1971
1973 US Open|John Newcombe|1973
1974 US Open|Jimmy Connors|1974
1976 US Open|Jimmy Connors|1976
1977 US Open|Guillermo Vilas|1977
1978 US Open|Jimmy Connors|1978
1979 US Open|John McEnroe|1979
1968 French Open|Ken Rosewall|1968
1969 French Open|Rod Laver|1969
1972 French Open|Andrés Gimeno|1972
1974 French Open|Björn Borg|1974
1975 French Open|Björn Borg|1975
''',
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
John Newcombe|Australia
Ken Rosewall|Australia
Arthur Ashe|United States
Stan Smith|United States
Manuel Orantes|Spain
Ilie Năstase|Romania
Jan Kodeš|Czechoslovakia
Adriano Panatta|Italy
Vitas Gerulaitis|United States
Roscoe Tanner|United States
Brian Gottfried|United States
Tony Roche|Australia
''',
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'atp',
    relation: 'player_slam_count',
    competition: 'Grand Slam singles',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Roy Emerson|12
Rod Laver|11
Ken Rosewall|8
Ivan Lendl|8
John Newcombe|7
Mats Wilander|7
Stefan Edberg|6
Jim Courier|4
Gustavo Kuerten|3
Andy Murray|3
Stan Wawrinka|3
Arthur Ashe|3
''',
  );
}

void _addAtpMedium() {
  _addAtpMediumBand1();
  _addAtpMediumBand2();
  _addAtpMediumBand3();
  _addAtpMediumBand4();
  _addAtpMediumBand5();
}
void _addAtpHard() {
  _addAtpHardBand1();
  _addAtpHardBand2();
  _addAtpHardBand3();
  _addAtpHardBand4();
  _addAtpHardBand5();
}
void _addAtpGlobal() {
  _addAtpGlobalBand1();
  _addAtpGlobalBand2();
  _addAtpGlobalBand3();
  _addAtpGlobalBand4();
  _addAtpGlobalBand5();
}
void _addWtaFacts() {
  _addWtaEasyBand1();
  _addWtaEasyBand2();
  _addWtaEasyBand3();
  _addWtaEasyBand4();
  _addWtaEasyBand5();
  _addWtaMediumBand1();
  _addWtaMediumBand2();
  _addWtaMediumBand3();
  _addWtaMediumBand4();
  _addWtaMediumBand5();
  _addWtaHardBand1();
  _addWtaHardBand2();
  _addWtaHardBand3();
  _addWtaHardBand4();
  _addWtaHardBand5();
  _addWtaGlobalBand1();
  _addWtaGlobalBand2();
  _addWtaGlobalBand3();
  _addWtaGlobalBand4();
  _addWtaGlobalBand5();
}
void _addMajorsFacts() {
  _addMajorsEasyBand1();
  _addMajorsEasyBand2();
  _addMajorsEasyBand3();
  _addMajorsEasyBand4();
  _addMajorsEasyBand5();
  _addMajorsMediumBand1();
  _addMajorsMediumBand2();
  _addMajorsMediumBand3();
  _addMajorsMediumBand4();
  _addMajorsMediumBand5();
  _addMajorsHardBand1();
  _addMajorsHardBand2();
  _addMajorsHardBand3();
  _addMajorsHardBand4();
  _addMajorsHardBand5();
  _addMajorsGlobalBand1();
  _addMajorsGlobalBand2();
  _addMajorsGlobalBand3();
  _addMajorsGlobalBand4();
  _addMajorsGlobalBand5();
}
void _addTeamEventFacts() {
  _addTeamEasyBand1();
  _addTeamEasyBand2();
  _addTeamEasyBand3();
  _addTeamEasyBand4();
  _addTeamEasyBand5();
  _addTeamMediumBand1();
  _addTeamMediumBand2();
  _addTeamMediumBand3();
  _addTeamMediumBand4();
  _addTeamMediumBand5();
  _addTeamHardBand1();
  _addTeamHardBand2();
  _addTeamHardBand3();
  _addTeamHardBand4();
  _addTeamHardBand5();
  _addTeamGlobalBand1();
  _addTeamGlobalBand2();
  _addTeamGlobalBand3();
  _addTeamGlobalBand4();
  _addTeamGlobalBand5();
}
void _addDoublesFacts() {
  _addDoublesEasyBand1();
  _addDoublesEasyBand2();
  _addDoublesEasyBand3();
  _addDoublesEasyBand4();
  _addDoublesEasyBand5();
  _addDoublesMediumBand1();
  _addDoublesMediumBand2();
  _addDoublesMediumBand3();
  _addDoublesMediumBand4();
  _addDoublesMediumBand5();
  _addDoublesHardBand1();
  _addDoublesHardBand2();
  _addDoublesHardBand3();
  _addDoublesHardBand4();
  _addDoublesHardBand5();
  _addDoublesGlobalBand1();
  _addDoublesGlobalBand2();
  _addDoublesGlobalBand3();
  _addDoublesGlobalBand4();
  _addDoublesGlobalBand5();
}
void _addRulesTermsFacts() {
  _addRulesEasyBand1();
  _addRulesEasyBand2();
  _addRulesEasyBand3();
  _addRulesEasyBand4();
  _addRulesEasyBand5();
  _addRulesMediumBand1();
  _addRulesMediumBand2();
  _addRulesMediumBand3();
  _addRulesMediumBand4();
  _addRulesMediumBand5();
  _addRulesHardBand1();
  _addRulesHardBand2();
  _addRulesHardBand3();
  _addRulesHardBand4();
  _addRulesHardBand5();
  _addRulesGlobalBand1();
  _addRulesGlobalBand2();
  _addRulesGlobalBand3();
  _addRulesGlobalBand4();
  _addRulesGlobalBand5();
}
void _addWorldOtherFacts() {
  _addWorldEasyBand1();
  _addWorldEasyBand2();
  _addWorldEasyBand3();
  _addWorldEasyBand4();
  _addWorldEasyBand5();
  _addWorldMediumBand1();
  _addWorldMediumBand2();
  _addWorldMediumBand3();
  _addWorldMediumBand4();
  _addWorldMediumBand5();
  _addWorldHardBand1();
  _addWorldHardBand2();
  _addWorldHardBand3();
  _addWorldHardBand4();
  _addWorldHardBand5();
  _addWorldGlobalBand1();
  _addWorldGlobalBand2();
  _addWorldGlobalBand3();
  _addWorldGlobalBand4();
  _addWorldGlobalBand5();
}

void _addAtpMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
2008 Wimbledon|Roger Federer|2008
2019 Wimbledon|Roger Federer|2019
2023 Wimbledon|Novak Djokovic|2023
2024 Wimbledon|Novak Djokovic|2024
2025 Wimbledon|Carlos Alcaraz|2025
2012 Wimbledon|Andy Murray|2012
2013 Wimbledon|Novak Djokovic|2013
2014 Wimbledon|Roger Federer|2014
2015 Wimbledon|Roger Federer|2015
2016 Wimbledon|Milos Raonic|2016
2009 US Open|Roger Federer|2009
2015 US Open|Roger Federer|2015
2021 US Open|Novak Djokovic|2021
2022 US Open|Casper Ruud|2022
2023 US Open|Daniil Medvedev|2023
2024 US Open|Taylor Fritz|2024
''',
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2019 Indian Wells Masters|Dominic Thiem|2019
2018 Indian Wells Masters|Juan Martín del Potro|2018
2023 Indian Wells Masters|Carlos Alcaraz|2023
2024 Indian Wells Masters|Carlos Alcaraz|2024
2022 Indian Wells Masters|Taylor Fritz|2022
2021 Indian Wells Masters|Cameron Norrie|2021
2023 Miami Open|Daniil Medvedev|2023
2022 Miami Open|Carlos Alcaraz|2022
2024 Miami Open|Jannik Sinner|2024
2021 Miami Open|Hubert Hurkacz|2021
2019 Miami Open|Roger Federer|2019
2018 Miami Open|John Isner|2018
2024 Monte-Carlo Masters|Stefanos Tsitsipas|2024
2021 Monte-Carlo Masters|Stefanos Tsitsipas|2021
2018 Monte-Carlo Masters|Rafael Nadal|2018
2023 Madrid Open|Carlos Alcaraz|2023
2022 Madrid Open|Carlos Alcaraz|2022
2024 Madrid Open|Andrey Rublev|2024
''',
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'atp',
    relation: 'coach_of',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-tournaments'],
    data: '''
Andy Murray|Ivan Lendl
Novak Djokovic|Boris Becker
Roger Federer|Stefan Edberg
Rafael Nadal|Carlos Moyá
Carlos Alcaraz|Juan Carlos Ferrero
Alexander Zverev|Ivan Lendl
Daniil Medvedev|Gilles Cervara
Stefanos Tsitsipas|Apostolos Tsitsipas
''',
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'atp',
    relation: 'tour_finals_winner',
    competition: 'ATP Finals',
    sources: const ['atp-finals', 'atp-rankings'],
    data: '''
2012 ATP Finals|Novak Djokovic|2012
2013 ATP Finals|Novak Djokovic|2013
2014 ATP Finals|Novak Djokovic|2014
2015 ATP Finals|Novak Djokovic|2015
2016 ATP Finals|Andy Murray|2016
2017 ATP Finals|Grigor Dimitrov|2017
2018 ATP Finals|Alexander Zverev|2018
''',
  );
}

void _addAtpMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
2010 Wimbledon|Tomáš Berdych|2010
2011 Wimbledon|Rafael Nadal|2011
2017 Wimbledon|Marin Čilić|2017
2018 Wimbledon|Kevin Anderson|2018
2021 Wimbledon|Matteo Berrettini|2021
2022 Wimbledon|Nick Kyrgios|2022
2010 US Open|Novak Djokovic|2010
2011 US Open|Rafael Nadal|2011
2012 US Open|Novak Djokovic|2012
2013 US Open|Novak Djokovic|2013
2014 US Open|Kei Nishikori|2014
2016 US Open|Novak Djokovic|2016
2017 US Open|Kevin Anderson|2017
2018 US Open|Juan Martín del Potro|2018
2019 US Open|Daniil Medvedev|2019
2020 US Open|Alexander Zverev|2020
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2019 Rome Masters|Rafael Nadal|2019
2021 Rome Masters|Rafael Nadal|2021
2022 Rome Masters|Novak Djokovic|2022
2023 Rome Masters|Daniil Medvedev|2023
2024 Rome Masters|Alexander Zverev|2024
2018 Canadian Open|Rafael Nadal|2018
2019 Canadian Open|Rafael Nadal|2019
2021 Canadian Open|Daniil Medvedev|2021
2022 Canadian Open|Pablo Carreño Busta|2022
2023 Canadian Open|Jannik Sinner|2023
2018 Cincinnati Masters|Novak Djokovic|2018
2019 Cincinnati Masters|Daniil Medvedev|2019
2021 Cincinnati Masters|Alexander Zverev|2021
2022 Cincinnati Masters|Borna Ćorić|2022
2023 Cincinnati Masters|Novak Djokovic|2023
2024 Cincinnati Masters|Jannik Sinner|2024
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'atp',
    relation: 'year_end_no1_men',
    competition: 'ATP year-end rankings',
    sources: const ['atp-rankings', 'atp-players'],
    data: '''
1994|Pete Sampras|1994
1995|Pete Sampras|1995
1996|Pete Sampras|1996
1997|Pete Sampras|1997
1998|Pete Sampras|1998
1999|Andre Agassi|1999
2000|Gustavo Kuerten|2000
2001|Lleyton Hewitt|2001
2002|Lleyton Hewitt|2002
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'atp',
    relation: 'tour_finals_winner',
    competition: 'ATP Finals',
    sources: const ['atp-finals', 'atp-rankings'],
    data: '''
2019 ATP Finals|Stefanos Tsitsipas|2019
2020 ATP Finals|Daniil Medvedev|2020
2021 ATP Finals|Alexander Zverev|2021
2022 ATP Finals|Novak Djokovic|2022
2023 ATP Finals|Novak Djokovic|2023
2024 ATP Finals|Jannik Sinner|2024
1998 ATP Finals|Àlex Corretja|1998
1999 ATP Finals|Pete Sampras|1999
''',
  );
}

void _addAtpMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Australian Open',
    sources: const ['ausopen-history', 'atp-tournaments'],
    data: '''
2000 Australian Open|Andre Agassi|2000
2001 Australian Open|Andre Agassi|2001
2002 Australian Open|Thomas Johansson|2002
2003 Australian Open|Andre Agassi|2003
2004 Australian Open|Roger Federer|2004
2005 Australian Open|Marat Safin|2005
2006 Australian Open|Roger Federer|2006
2007 Australian Open|Roger Federer|2007
2008 Australian Open|Novak Djokovic|2008
2009 Australian Open|Rafael Nadal|2009
2010 Australian Open|Roger Federer|2010
2011 Australian Open|Novak Djokovic|2011
2012 Australian Open|Novak Djokovic|2012
2013 Australian Open|Novak Djokovic|2013
2014 Australian Open|Stan Wawrinka|2014
2015 Australian Open|Novak Djokovic|2015
2016 Australian Open|Novak Djokovic|2016
2018 Australian Open|Roger Federer|2018
2019 Australian Open|Novak Djokovic|2019
2020 Australian Open|Novak Djokovic|2020
''',
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2017 Shanghai Masters|Roger Federer|2017
2018 Shanghai Masters|Novak Djokovic|2018
2019 Shanghai Masters|Daniil Medvedev|2019
2023 Shanghai Masters|Hubert Hurkacz|2023
2024 Shanghai Masters|Jannik Sinner|2024
2014 Paris Masters|Novak Djokovic|2014
2015 Paris Masters|Novak Djokovic|2015
2016 Paris Masters|Andy Murray|2016
2017 Paris Masters|Jack Sock|2017
2018 Paris Masters|Karen Khachanov|2018
2019 Paris Masters|Novak Djokovic|2019
2020 Paris Masters|Daniil Medvedev|2020
2021 Paris Masters|Novak Djokovic|2021
2022 Paris Masters|Holger Rune|2022
2023 Paris Masters|Novak Djokovic|2023
2024 Paris Masters|Alexander Zverev|2024
''',
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
2000 Wimbledon|Patrick Rafter|2000
2001 Wimbledon|Patrick Rafter|2001
2002 Wimbledon|David Nalbandian|2002
2003 Wimbledon|Mark Philippoussis|2003
2004 Wimbledon|Andy Roddick|2004
2005 Wimbledon|Andy Roddick|2005
2006 Wimbledon|Rafael Nadal|2006
2007 Wimbledon|Rafael Nadal|2007
2009 Wimbledon|Andy Roddick|2009
2006 French Open|Roger Federer|2006
2007 French Open|Roger Federer|2007
2008 French Open|Roger Federer|2008
2011 French Open|Roger Federer|2011
''',
  );
}

void _addAtpMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['ausopen-history', 'rolandgarros-history'],
    data: '''
1983 Australian Open|Mats Wilander|1983
1984 Australian Open|Mats Wilander|1984
1985 Australian Open|Stefan Edberg|1985
1987 Australian Open|Stefan Edberg|1987
1988 Australian Open|Mats Wilander|1988
1989 Australian Open|Ivan Lendl|1989
1990 Australian Open|Ivan Lendl|1990
1991 Australian Open|Boris Becker|1991
1992 Australian Open|Jim Courier|1992
1993 Australian Open|Jim Courier|1993
1994 Australian Open|Pete Sampras|1994
1995 Australian Open|Andre Agassi|1995
1996 Australian Open|Boris Becker|1996
1997 Australian Open|Pete Sampras|1997
1998 Australian Open|Petr Korda|1998
1999 Australian Open|Yevgeny Kafelnikov|1999
1985 French Open|Mats Wilander|1985
1986 French Open|Ivan Lendl|1986
1987 French Open|Ivan Lendl|1987
1988 French Open|Mats Wilander|1988
''',
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
1980 Wimbledon|John McEnroe|1980
1981 Wimbledon|Björn Borg|1981
1984 Wimbledon|Jimmy Connors|1984
1985 Wimbledon|Kevin Curren|1985
1988 Wimbledon|Boris Becker|1988
1989 Wimbledon|Stefan Edberg|1989
1990 Wimbledon|Boris Becker|1990
1992 Wimbledon|Goran Ivanišević|1992
1994 Wimbledon|Goran Ivanišević|1994
1995 Wimbledon|Boris Becker|1995
1998 Wimbledon|Goran Ivanišević|1998
1999 Wimbledon|Andre Agassi|1999
1989 French Open|Stefan Edberg|1989
1991 French Open|Andre Agassi|1991
''',
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'atp',
    relation: 'year_end_no1_men',
    competition: 'ATP year-end rankings',
    sources: const ['atp-rankings', 'tennis-hall-of-fame'],
    data: '''
1973|Ilie Năstase|1973
1974|Jimmy Connors|1974
1975|Jimmy Connors|1975
1976|Jimmy Connors|1976
1977|Jimmy Connors|1977
1978|Jimmy Connors|1978
1979|Björn Borg|1979
''',
    extraOptions: const ['John McEnroe', 'Guillermo Vilas', 'Ken Rosewall'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'atp',
    relation: 'tour_finals_winner',
    competition: 'ATP Finals',
    sources: const ['atp-finals', 'tennis-hall-of-fame'],
    data: '''
1990 ATP Finals|Andre Agassi|1990
1991 ATP Finals|Pete Sampras|1991
1992 ATP Finals|Boris Becker|1992
1993 ATP Finals|Michael Stich|1993
1994 ATP Finals|Pete Sampras|1994
1995 ATP Finals|Boris Becker|1995
1996 ATP Finals|Pete Sampras|1996
1997 ATP Finals|Pete Sampras|1997
''',
  );
}

void _addAtpMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['ausopen-history', 'rolandgarros-history'],
    data: '''
1968 Australian Open|Bill Bowrey|1968
1969 Australian Open|Rod Laver|1969
1970 Australian Open|Arthur Ashe|1970
1971 Australian Open|Ken Rosewall|1971
1972 Australian Open|Ken Rosewall|1972
1973 Australian Open|John Newcombe|1973
1975 Australian Open|John Newcombe|1975
1976 Australian Open|Mark Edmondson|1976
1978 Australian Open|Guillermo Vilas|1978
1979 Australian Open|Guillermo Vilas|1979
1980 Australian Open|Brian Teacher|1980
1981 Australian Open|Johan Kriek|1981
1982 Australian Open|Johan Kriek|1982
1970 French Open|Jan Kodeš|1970
1971 French Open|Jan Kodeš|1971
1973 French Open|Ilie Năstase|1973
1976 French Open|Adriano Panatta|1976
1977 French Open|Guillermo Vilas|1977
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
1970 Wimbledon|Ken Rosewall|1970
1972 Wimbledon|Ilie Năstase|1972
1974 Wimbledon|Ken Rosewall|1974
1975 Wimbledon|Jimmy Connors|1975
1976 Wimbledon|Ilie Năstase|1976
1977 Wimbledon|Jimmy Connors|1977
1978 Wimbledon|Jimmy Connors|1978
1979 Wimbledon|Roscoe Tanner|1979
1975 US Open|Jimmy Connors|1975
1976 US Open|Björn Borg|1976
1978 US Open|Björn Borg|1978
1980 US Open|Björn Borg|1980
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'atp',
    relation: 'tour_finals_winner',
    competition: 'ATP Finals',
    sources: const ['atp-finals', 'tennis-hall-of-fame'],
    data: '''
1970 ATP Finals|Stan Smith|1970
1971 ATP Finals|Ilie Năstase|1971
1972 ATP Finals|Ilie Năstase|1972
1973 ATP Finals|Ilie Năstase|1973
1974 ATP Finals|Guillermo Vilas|1974
1975 ATP Finals|Ilie Năstase|1975
1976 ATP Finals|Manuel Orantes|1976
1977 ATP Finals|Jimmy Connors|1977
1978 ATP Finals|John McEnroe|1978
1979 ATP Finals|Björn Borg|1979
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Mark Edmondson|Australia
Johan Kriek|South Africa
Brian Teacher|United States
Bill Bowrey|Australia
Harold Solomon|United States
Eddie Dibbs|United States
Raúl Ramírez|Mexico
Corrado Barazzutti|Italy
Wojciech Fibak|Poland
''',
  );
}

void _addAtpHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Roland-Garros',
    sources: const ['rolandgarros-history', 'atp-tournaments'],
    data: '''
2010 French Open|Rafael Nadal|2010
2011 French Open|Rafael Nadal|2011
2012 French Open|Rafael Nadal|2012
2013 French Open|Rafael Nadal|2013
2014 French Open|Rafael Nadal|2014
2015 French Open|Stan Wawrinka|2015
2016 French Open|Novak Djokovic|2016
2017 French Open|Rafael Nadal|2017
2018 French Open|Rafael Nadal|2018
2019 French Open|Rafael Nadal|2019
2020 French Open|Rafael Nadal|2020
2021 French Open|Novak Djokovic|2021
2022 French Open|Rafael Nadal|2022
2023 French Open|Novak Djokovic|2023
2024 French Open|Carlos Alcaraz|2024
2025 French Open|Carlos Alcaraz|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'atp',
    relation: 'record_holder',
    competition: 'ATP Tour records',
    sources: const ['atp-rankings', 'atp-players'],
    data: '''
most Grand Slam men's singles titles|Novak Djokovic
most French Open men's singles titles|Rafael Nadal
most Wimbledon men's singles titles|Roger Federer
most weeks at ATP world No. 1|Novak Djokovic
most ATP Masters 1000 titles|Novak Djokovic
most ATP Finals titles|Roger Federer
most Australian Open men's singles titles|Novak Djokovic
most career ATP singles titles|Jimmy Connors
most ATP Tour match wins|Jimmy Connors
most consecutive weeks at world No. 1|Roger Federer
''',
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2010 Indian Wells Masters|Ivan Ljubičić|2010
2011 Indian Wells Masters|Novak Djokovic|2011
2012 Indian Wells Masters|Roger Federer|2012
2013 Indian Wells Masters|Rafael Nadal|2013
2014 Indian Wells Masters|Novak Djokovic|2014
2015 Indian Wells Masters|Novak Djokovic|2015
2016 Indian Wells Masters|Novak Djokovic|2016
2017 Indian Wells Masters|Roger Federer|2017
2009 Miami Open|Andy Murray|2009
2010 Miami Open|Andy Roddick|2010
2011 Miami Open|Novak Djokovic|2011
2012 Miami Open|Novak Djokovic|2012
2013 Miami Open|Andy Murray|2013
2014 Miami Open|Novak Djokovic|2014
2015 Miami Open|Novak Djokovic|2015
2016 Miami Open|Novak Djokovic|2016
''',
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'atp',
    relation: 'retirement_year',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
Roger Federer|2022
Andy Murray|2024
Rafael Nadal|2024
Pete Sampras|2002
Andre Agassi|2006
Jimmy Connors|1996
Ivan Lendl|1994
John McEnroe|1992
''',
  );
}

void _addAtpHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Grand Slam singles',
    sources: const ['rolandgarros-history', 'usopen-history'],
    data: '''
1992 French Open|Jim Courier|1992
1993 French Open|Sergi Bruguera|1993
1994 French Open|Sergi Bruguera|1994
1996 French Open|Yevgeny Kafelnikov|1996
1998 French Open|Carlos Moyá|1998
2000 French Open|Gustavo Kuerten|2000
2001 French Open|Gustavo Kuerten|2001
2002 French Open|Albert Costa|2002
1989 US Open|Boris Becker|1989
1992 US Open|Stefan Edberg|1992
1993 US Open|Pete Sampras|1993
1994 US Open|Andre Agassi|1994
''',
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2009 Madrid Open|Roger Federer|2009
2010 Madrid Open|Rafael Nadal|2010
2011 Madrid Open|Novak Djokovic|2011
2012 Madrid Open|Roger Federer|2012
2013 Madrid Open|Rafael Nadal|2013
2014 Madrid Open|Rafael Nadal|2014
2015 Madrid Open|Andy Murray|2015
2016 Madrid Open|Novak Djokovic|2016
2017 Madrid Open|Rafael Nadal|2017
2018 Madrid Open|Alexander Zverev|2018
2019 Madrid Open|Novak Djokovic|2019
2021 Madrid Open|Alexander Zverev|2021
2025 Madrid Open|Casper Ruud|2025
2025 Rome Masters|Carlos Alcaraz|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'atp',
    relation: 'hall_of_fame_year',
    competition: 'International Tennis Hall of Fame',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Pete Sampras|2007
Andre Agassi|2011
Björn Borg|1987
John McEnroe|1999
Jimmy Connors|1998
Ivan Lendl|2001
Boris Becker|2003
Stefan Edberg|2004
Mats Wilander|2002
Jim Courier|2005
Michael Chang|2008
Gustavo Kuerten|2012
''',
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Ivan Ljubičić|Croatia
Albert Costa|Spain
David Nalbandian|Argentina
Nicolás Massú|Chile
Fernando González|Chile
Tommy Haas|Germany
Mikhail Youzhny|Russia
Jo-Wilfried Tsonga|France
Robin Söderling|Sweden
Janko Tipsarević|Serbia
Feliciano López|Spain
Radek Štěpánek|Czech Republic
''',
  );
}

void _addAtpHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2005 Monte-Carlo Masters|Rafael Nadal|2005
2006 Monte-Carlo Masters|Rafael Nadal|2006
2007 Monte-Carlo Masters|Rafael Nadal|2007
2008 Monte-Carlo Masters|Rafael Nadal|2008
2009 Monte-Carlo Masters|Rafael Nadal|2009
2010 Monte-Carlo Masters|Rafael Nadal|2010
2011 Monte-Carlo Masters|Rafael Nadal|2011
2012 Monte-Carlo Masters|Rafael Nadal|2012
2013 Monte-Carlo Masters|Novak Djokovic|2013
2015 Monte-Carlo Masters|Novak Djokovic|2015
2016 Monte-Carlo Masters|Rafael Nadal|2016
2017 Monte-Carlo Masters|Rafael Nadal|2017
2019 Monte-Carlo Masters|Fabio Fognini|2019
2022 Monte-Carlo Masters|Stefanos Tsitsipas|2022
2023 Monte-Carlo Masters|Andrey Rublev|2023
2025 Monte-Carlo Masters|Carlos Alcaraz|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Australian Open',
    sources: const ['ausopen-history', 'atp-tournaments'],
    data: '''
2010 Australian Open|Andy Murray|2010
2011 Australian Open|Andy Murray|2011
2012 Australian Open|Rafael Nadal|2012
2013 Australian Open|Andy Murray|2013
2014 Australian Open|Rafael Nadal|2014
2015 Australian Open|Andy Murray|2015
2016 Australian Open|Andy Murray|2016
2017 Australian Open|Rafael Nadal|2017
2019 Australian Open|Rafael Nadal|2019
2020 Australian Open|Dominic Thiem|2020
2021 Australian Open|Daniil Medvedev|2021
2022 Australian Open|Daniil Medvedev|2022
2023 Australian Open|Stefanos Tsitsipas|2023
2024 Australian Open|Daniil Medvedev|2024
''',
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'atp',
    relation: 'record_value',
    competition: 'ATP Tour records',
    sources: const ['atp-rankings', 'atp-players'],
    data: '''
most Grand Slam men's singles titles|24
most French Open men's singles titles|14
most Wimbledon men's singles titles|8
most weeks at ATP world No. 1|428
most consecutive weeks at world No. 1|237
most career ATP singles titles|109
most ATP Masters 1000 titles|40
most ATP Finals titles|6
''',
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'US Open',
    sources: const ['usopen-history', 'atp-tournaments'],
    data: '''
1980 US Open|John McEnroe|1980
1981 US Open|John McEnroe|1981
1982 US Open|Jimmy Connors|1982
1983 US Open|Jimmy Connors|1983
1985 US Open|Ivan Lendl|1985
1986 US Open|Ivan Lendl|1986
1987 US Open|Ivan Lendl|1987
1988 US Open|Mats Wilander|1988
1995 US Open|Pete Sampras|1995
1996 US Open|Pete Sampras|1996
1997 US Open|Patrick Rafter|1997
1998 US Open|Patrick Rafter|1998
''',
  );
}

void _addAtpHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'Roland-Garros',
    sources: const ['rolandgarros-history', 'atp-tournaments'],
    data: '''
2005 French Open|Mariano Puerta|2005
2010 French Open|Robin Söderling|2010
2012 French Open|Novak Djokovic|2012
2013 French Open|David Ferrer|2013
2014 French Open|Novak Djokovic|2014
2015 French Open|Novak Djokovic|2015
2017 French Open|Stan Wawrinka|2017
2018 French Open|Dominic Thiem|2018
2019 French Open|Dominic Thiem|2019
2020 French Open|Novak Djokovic|2020
2022 French Open|Casper Ruud|2022
2023 French Open|Casper Ruud|2023
2024 French Open|Alexander Zverev|2024
2025 French Open|Jannik Sinner|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2004 Canadian Open|Roger Federer|2004
2006 Canadian Open|Roger Federer|2006
2010 Canadian Open|Andy Murray|2010
2011 Canadian Open|Novak Djokovic|2011
2012 Canadian Open|Novak Djokovic|2012
2013 Canadian Open|Rafael Nadal|2013
2014 Canadian Open|Jo-Wilfried Tsonga|2014
2015 Canadian Open|Andy Murray|2015
2016 Canadian Open|Novak Djokovic|2016
2017 Canadian Open|Alexander Zverev|2017
2024 Canadian Open|Alexei Popyrin|2024
2025 Canadian Open|Ben Shelton|2025
2012 Cincinnati Masters|Roger Federer|2012
2014 Cincinnati Masters|Roger Federer|2014
''',
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Alexei Popyrin|Australia
Ben Shelton|United States
Holger Rune|Denmark
Karen Khachanov|Russia
Andrey Rublev|Russia
Hubert Hurkacz|Poland
Félix Auger-Aliassime|Canada
Denis Shapovalov|Canada
Lorenzo Musetti|Italy
Matteo Berrettini|Italy
Frances Tiafoe|United States
Taylor Fritz|United States
''',
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'atp',
    relation: 'hall_of_fame_year',
    competition: 'International Tennis Hall of Fame',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Rod Laver|1981
Ken Rosewall|1980
John Newcombe|1986
Arthur Ashe|1985
Ilie Năstase|1991
Stan Smith|1987
Guillermo Vilas|1991
Manuel Orantes|2012
Andrés Gimeno|2009
Jan Kodeš|1990
''',
  );
}

void _addAtpHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'atp',
    relation: 'slam_champion_men',
    competition: 'Wimbledon',
    sources: const ['wimbledon-history', 'tennis-hall-of-fame'],
    data: '''
1936 Wimbledon|Fred Perry|1936
1938 Wimbledon|Don Budge|1938
1947 Wimbledon|Jack Kramer|1947
1949 Wimbledon|Ted Schroeder|1949
1953 Wimbledon|Vic Seixas|1953
1956 Wimbledon|Lew Hoad|1956
1957 Wimbledon|Lew Hoad|1957
1961 Wimbledon|Rod Laver|1961
1962 Wimbledon|Rod Laver|1962
1963 Wimbledon|Chuck McKinley|1963
1964 Wimbledon|Roy Emerson|1964
1965 Wimbledon|Roy Emerson|1965
1966 Wimbledon|Manuel Santana|1966
1967 Wimbledon|John Newcombe|1967
''',
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'atp',
    relation: 'slam_runner_up_men',
    competition: 'US Open',
    sources: const ['usopen-history', 'atp-tournaments'],
    data: '''
1996 US Open|Michael Chang|1996
1997 US Open|Greg Rusedski|1997
1999 US Open|Todd Martin|1999
2000 US Open|Pete Sampras|2000
2001 US Open|Pete Sampras|2001
2002 US Open|Andre Agassi|2002
2003 US Open|Juan Carlos Ferrero|2003
2004 US Open|Lleyton Hewitt|2004
2005 US Open|Andre Agassi|2005
2006 US Open|Andy Roddick|2006
2007 US Open|Novak Djokovic|2007
2008 US Open|Andy Murray|2008
''',
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Manuel Santana|Spain
Lew Hoad|Australia
Roy Emerson|Australia
Vic Seixas|United States
Fred Perry|United Kingdom
Don Budge|United States
Jaroslav Drobný|Czechoslovakia
Neale Fraser|Australia
Ashley Cooper|Australia
Alex Olmedo|Peru
Nicola Pietrangeli|Italy
Jan-Erik Lundqvist|Sweden
''',
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'atp',
    relation: 'player_slam_count',
    competition: 'Grand Slam singles',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Fred Perry|8
Don Budge|6
Lew Hoad|4
Manuel Santana|4
Jan Kodeš|3
Ilie Năstase|2
Johan Kriek|2
Guillermo Vilas|4
Jimmy Connors|8
Michael Chang|1
Vic Seixas|2
Adriano Panatta|1
''',
  );
}

void _addAtpGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'atp',
    relation: 'event_country',
    competition: 'ATP Tour',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Dubai Tennis Championships|United Arab Emirates
Qatar Open|Qatar
Rio Open|Brazil
Mexican Open|Mexico
Japan Open|Japan
China Open|China
Swiss Indoors|Switzerland
Erste Bank Open|Austria
Stockholm Open|Sweden
Moselle Open|France
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Nicolás Jarry|Chile
Sebastián Báez|Argentina
Tallon Griekspoor|Netherlands
Tomáš Macháč|Czech Republic
Alejandro Tabilo|Chile
Zhang Zhizhen|China
Yoshihito Nishioka|Japan
Aslan Karatsev|Russia
Alexander Bublik|Kazakhstan
Jaume Munar|Spain
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2009 Shanghai Masters|Nikolay Davydenko|2009
2010 Shanghai Masters|Andy Murray|2010
2011 Shanghai Masters|Andy Murray|2011
2012 Shanghai Masters|Novak Djokovic|2012
2013 Shanghai Masters|Novak Djokovic|2013
2014 Shanghai Masters|Roger Federer|2014
''',
  );
}

void _addAtpGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'atp',
    relation: 'event_country',
    competition: 'ATP Tour',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Hamburg European Open|Germany
Croatia Open Umag|Croatia
Generali Open Kitzbühel|Austria
Winston-Salem Open|United States
Astana Open|Kazakhstan
Adelaide International|Australia
Auckland Open|New Zealand
Chengdu Open|China
Seoul Open|South Korea
Tel Aviv Open|Israel
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Botic van de Zandschulp|Netherlands
Roberto Bautista Agut|Spain
Pablo Carreño Busta|Spain
Diego Schwartzman|Argentina
Federico Coria|Argentina
Dušan Lajović|Serbia
Laslo Djere|Serbia
Emil Ruusuvuori|Finland
Otto Virtanen|Finland
Dominic Stricker|Switzerland
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2002 Canadian Open|Guillermo Cañas|2002
2003 Canadian Open|Andy Roddick|2003
2005 Canadian Open|Rafael Nadal|2005
2007 Canadian Open|Novak Djokovic|2007
2008 Canadian Open|Rafael Nadal|2008
2009 Canadian Open|Andy Murray|2009
''',
  );
}

void _addAtpGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'atp',
    relation: 'event_country',
    competition: 'ATP Tour',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Estoril Open|Portugal
Serbia Open|Serbia
Sofia Open|Bulgaria
Marrakech Open|Morocco
Los Cabos Open|Mexico
Córdoba Open|Argentina
Santiago Open|Chile
Bucharest Open|Romania
Antalya Open|Turkey
Almaty Open|Kazakhstan
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Borna Ćorić|Croatia
Filip Krajinović|Serbia
Miomir Kecmanović|Serbia
Jiří Lehečka|Czech Republic
Jakub Menšík|Czech Republic
Sebastian Korda|United States
Christopher Eubanks|United States
Arthur Fils|France
Ugo Humbert|France
Luciano Darderi|Italy
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
2005 Rome Masters|Rafael Nadal|2005
2006 Rome Masters|Rafael Nadal|2006
2007 Rome Masters|Rafael Nadal|2007
2008 Rome Masters|Novak Djokovic|2008
2009 Rome Masters|Rafael Nadal|2009
2010 Rome Masters|Rafael Nadal|2010
''',
    extraOptions: const ['Roger Federer', 'Andy Murray', 'David Ferrer'],
  );
}

void _addAtpGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'atp',
    relation: 'event_country',
    competition: 'ATP Tour',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Swedish Open|Sweden
Gstaad Open|Switzerland
Sardegna Open|Italy
Rosmalen Open|Netherlands
Eastbourne International|United Kingdom
Mallorca Championships|Spain
Newport Hall of Fame Open|United States
Kremlin Cup|Russia
Atlanta Open|United States
St. Petersburg Open|Russia
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Radu Albot|Moldova
Egor Gerasimov|Belarus
Ilya Ivashka|Belarus
Marcos Giron|United States
Rinky Hijikata|Australia
Jordan Thompson|Australia
Thanasi Kokkinakis|Australia
Nuno Borges|Portugal
João Sousa|Portugal
Elias Ymer|Sweden
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
1999 Rome Masters|Gustavo Kuerten|1999
2000 Rome Masters|Magnus Norman|2000
2001 Rome Masters|Juan Carlos Ferrero|2001
2002 Rome Masters|Andre Agassi|2002
2003 Rome Masters|Félix Mantilla|2003
2004 Rome Masters|Carlos Moyá|2004
''',
  );
}

void _addAtpGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'atp',
    relation: 'event_country',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
Monte-Carlo Masters|Monaco
Indian Wells Masters|United States
Miami Open|United States
Madrid Open|Spain
Shanghai Masters|China
Paris Masters|France
Canadian Open|Canada
Cincinnati Masters|United States
Rome Masters|Italy
Halle Open|Germany
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'atp',
    relation: 'player_nationality',
    competition: 'ATP Tour',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Yannick Hanfmann|Germany
Daniel Altmaier|Germany
Pedro Cachín|Argentina
Francisco Cerúndolo|Argentina
Tomás Martín Etcheverry|Argentina
Zizou Bergs|Belgium
David Goffin|Belgium
Roberto Carballés Baena|Spain
Pedro Martínez|Spain
Mackenzie McDonald|United States
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'atp',
    relation: 'masters_winner',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
1996 Cincinnati Masters|Andre Agassi|1996
1998 Cincinnati Masters|Patrick Rafter|1998
1999 Cincinnati Masters|Pete Sampras|1999
2000 Cincinnati Masters|Thomas Enqvist|2000
2001 Cincinnati Masters|Gustavo Kuerten|2001
2002 Cincinnati Masters|Carlos Moyá|2002
''',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WTA — WOMEN'S SINGLES TOUR — 425 facts (easy 100, medium 110, hard 110,
// global 105). A fixed fifth of every band, so no mode clears without it.
// ─────────────────────────────────────────────────────────────────────────────

void _addWtaEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Serena Williams|United States
Venus Williams|United States
Steffi Graf|Germany
Martina Navratilova|Czechoslovakia
Chris Evert|United States
Monica Seles|Yugoslavia
Maria Sharapova|Russia
Iga Świątek|Poland
Aryna Sabalenka|Belarus
Naomi Osaka|Japan
Margaret Court|Australia
Billie Jean King|United States
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'wta',
    relation: 'player_slam_count',
    competition: 'Grand Slam singles',
    sources: const ['wta-players', 'tennis-hall-of-fame'],
    data: '''
Margaret Court|24
Serena Williams|23
Steffi Graf|22
Helen Wills|19
Chris Evert|18
Martina Navratilova|18
Billie Jean King|12
Monica Seles|9
''',
  );
}

void _addWtaEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'ausopen-history'],
    data: '''
2018 Wimbledon|Angelique Kerber|2018
2019 Wimbledon|Simona Halep|2019
2021 Wimbledon|Ashleigh Barty|2021
2022 Wimbledon|Elena Rybakina|2022
2023 Wimbledon|Markéta Vondroušová|2023
2024 Wimbledon|Barbora Krejčíková|2024
2025 Wimbledon|Iga Świątek|2025
2019 Australian Open|Naomi Osaka|2019
2020 Australian Open|Sofia Kenin|2020
2022 Australian Open|Ashleigh Barty|2022
2023 Australian Open|Aryna Sabalenka|2023
2024 Australian Open|Aryna Sabalenka|2024
2018 US Open|Naomi Osaka|2018
2020 US Open|Naomi Osaka|2020
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Simona Halep|Romania
Ashleigh Barty|Australia
Angelique Kerber|Germany
Elena Rybakina|Kazakhstan
Coco Gauff|United States
Jeļena Ostapenko|Latvia
''',
  );
}

void _addWtaEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Wimbledon',
    sources: const ['wimbledon-history', 'wta-tournaments'],
    data: '''
2002 Wimbledon|Serena Williams|2002
2003 Wimbledon|Serena Williams|2003
2004 Wimbledon|Maria Sharapova|2004
2005 Wimbledon|Venus Williams|2005
2007 Wimbledon|Venus Williams|2007
2008 Wimbledon|Venus Williams|2008
2009 Wimbledon|Serena Williams|2009
2010 Wimbledon|Serena Williams|2010
2011 Wimbledon|Petra Kvitová|2011
2012 Wimbledon|Serena Williams|2012
2013 Wimbledon|Marion Bartoli|2013
2014 Wimbledon|Petra Kvitová|2014
2015 Wimbledon|Serena Williams|2015
2016 Wimbledon|Serena Williams|2016
''',
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Petra Kvitová|Czech Republic
Victoria Azarenka|Belarus
Caroline Wozniacki|Denmark
Ana Ivanović|Serbia
Jelena Janković|Serbia
Svetlana Kuznetsova|Russia
''',
  );
}

void _addWtaEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Wimbledon',
    sources: const ['wimbledon-history', 'tennis-hall-of-fame'],
    data: '''
1986 Wimbledon|Martina Navratilova|1986
1987 Wimbledon|Martina Navratilova|1987
1988 Wimbledon|Steffi Graf|1988
1989 Wimbledon|Steffi Graf|1989
1990 Wimbledon|Martina Navratilova|1990
1991 Wimbledon|Steffi Graf|1991
1992 Wimbledon|Steffi Graf|1992
1993 Wimbledon|Steffi Graf|1993
1994 Wimbledon|Conchita Martínez|1994
1995 Wimbledon|Steffi Graf|1995
1996 Wimbledon|Steffi Graf|1996
1997 Wimbledon|Martina Hingis|1997
1998 Wimbledon|Jana Novotná|1998
1999 Wimbledon|Lindsay Davenport|1999
''',
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'tennis-hall-of-fame'],
    data: '''
Martina Hingis|Switzerland
Jana Novotná|Czech Republic
Lindsay Davenport|United States
Conchita Martínez|Spain
Arantxa Sánchez Vicario|Spain
Gabriela Sabatini|Argentina
''',
  );
}

void _addWtaEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Wimbledon',
    sources: const ['wimbledon-history', 'tennis-hall-of-fame'],
    data: '''
1968 Wimbledon|Billie Jean King|1968
1969 Wimbledon|Ann Jones|1969
1970 Wimbledon|Margaret Court|1970
1971 Wimbledon|Evonne Goolagong|1971
1972 Wimbledon|Billie Jean King|1972
1973 Wimbledon|Billie Jean King|1973
1974 Wimbledon|Chris Evert|1974
1975 Wimbledon|Billie Jean King|1975
1976 Wimbledon|Chris Evert|1976
1977 Wimbledon|Virginia Wade|1977
1978 Wimbledon|Martina Navratilova|1978
1979 Wimbledon|Martina Navratilova|1979
1980 Wimbledon|Evonne Goolagong|1980
1981 Wimbledon|Chris Evert|1981
''',
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['tennis-hall-of-fame', 'wta-players'],
    data: '''
Evonne Goolagong|Australia
Virginia Wade|United Kingdom
Ann Jones|United Kingdom
Hana Mandlíková|Czechoslovakia
Tracy Austin|United States
Pam Shriver|United States
''',
  );
}

void _addWtaMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'wta',
    relation: 'slam_runner_up_women',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
2022 Wimbledon|Ons Jabeur|2022
2023 Wimbledon|Ons Jabeur|2023
2024 Wimbledon|Jasmine Paolini|2024
2025 Wimbledon|Amanda Anisimova|2025
2018 US Open|Serena Williams|2018
2019 US Open|Serena Williams|2019
2023 US Open|Aryna Sabalenka|2023
2024 US Open|Jessica Pegula|2024
2023 Australian Open|Elena Rybakina|2023
2024 Australian Open|Zheng Qinwen|2024
''',
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'wta',
    relation: 'year_end_no1_women',
    competition: 'WTA year-end rankings',
    sources: const ['wta-rankings', 'wta-players'],
    data: '''
2010|Caroline Wozniacki|2010
2011|Caroline Wozniacki|2011
2012|Victoria Azarenka|2012
2013|Serena Williams|2013
2014|Serena Williams|2014
2015|Serena Williams|2015
2017|Simona Halep|2017
2018|Simona Halep|2018
2019|Ashleigh Barty|2019
2020|Ashleigh Barty|2020
2021|Ashleigh Barty|2021
2022|Iga Świątek|2022
''',
  );
}

void _addWtaMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Grand Slam singles',
    sources: const ['usopen-history', 'rolandgarros-history'],
    data: '''
2021 US Open|Emma Raducanu|2021
2022 US Open|Iga Świątek|2022
2023 US Open|Coco Gauff|2023
2024 US Open|Aryna Sabalenka|2024
2025 US Open|Aryna Sabalenka|2025
2020 French Open|Iga Świątek|2020
2021 French Open|Barbora Krejčíková|2021
2022 French Open|Iga Świątek|2022
2023 French Open|Iga Świątek|2023
2024 French Open|Iga Świątek|2024
2025 French Open|Coco Gauff|2025
2025 Australian Open|Madison Keys|2025
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'wta',
    relation: 'event_winner_women',
    competition: 'WTA 1000',
    sources: const ['wta-tournaments', 'wta-rankings'],
    data: '''
2022 Indian Wells|Iga Świątek|2022
2023 Indian Wells|Elena Rybakina|2023
2024 Indian Wells|Iga Świątek|2024
2022 Miami|Iga Świątek|2022
2023 Miami|Petra Kvitová|2023
2024 Miami|Danielle Collins|2024
2023 Madrid|Aryna Sabalenka|2023
2024 Madrid|Iga Świątek|2024
2023 Rome|Elena Rybakina|2023
2024 Rome|Iga Świątek|2024
''',
  );
}

void _addWtaMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Australian Open',
    sources: const ['ausopen-history', 'wta-tournaments'],
    data: '''
2004 Australian Open|Justine Henin|2004
2005 Australian Open|Serena Williams|2005
2006 Australian Open|Amélie Mauresmo|2006
2007 Australian Open|Serena Williams|2007
2008 Australian Open|Maria Sharapova|2008
2009 Australian Open|Serena Williams|2009
2010 Australian Open|Serena Williams|2010
2012 Australian Open|Victoria Azarenka|2012
2013 Australian Open|Victoria Azarenka|2013
2015 Australian Open|Serena Williams|2015
2016 Australian Open|Angelique Kerber|2016
2017 Australian Open|Serena Williams|2017
''',
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'wta',
    relation: 'year_end_no1_women',
    competition: 'WTA year-end rankings',
    sources: const ['wta-rankings', 'wta-players'],
    data: '''
2000|Martina Hingis|2000
2001|Lindsay Davenport|2001
2002|Serena Williams|2002
2003|Justine Henin|2003
2004|Lindsay Davenport|2004
2005|Lindsay Davenport|2005
2006|Justine Henin|2006
2007|Justine Henin|2007
2008|Jelena Janković|2008
2009|Serena Williams|2009
''',
  );
}

void _addWtaMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Roland-Garros',
    sources: const ['rolandgarros-history', 'tennis-hall-of-fame'],
    data: '''
1987 French Open|Steffi Graf|1987
1988 French Open|Steffi Graf|1988
1989 French Open|Arantxa Sánchez Vicario|1989
1990 French Open|Monica Seles|1990
1991 French Open|Monica Seles|1991
1992 French Open|Monica Seles|1992
1993 French Open|Steffi Graf|1993
1994 French Open|Arantxa Sánchez Vicario|1994
1995 French Open|Steffi Graf|1995
1996 French Open|Steffi Graf|1996
1997 French Open|Iva Majoli|1997
1998 French Open|Arantxa Sánchez Vicario|1998
''',
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'wta',
    relation: 'year_end_no1_women',
    competition: 'WTA year-end rankings',
    sources: const ['wta-rankings', 'tennis-hall-of-fame'],
    data: '''
1987|Steffi Graf|1987
1988|Steffi Graf|1988
1989|Steffi Graf|1989
1990|Steffi Graf|1990
1991|Monica Seles|1991
1992|Monica Seles|1992
1993|Steffi Graf|1993
1995|Steffi Graf|1995
1997|Martina Hingis|1997
1998|Lindsay Davenport|1998
''',
  );
}

void _addWtaMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'US Open',
    sources: const ['usopen-history', 'tennis-hall-of-fame'],
    data: '''
1970 US Open|Margaret Court|1970
1971 US Open|Billie Jean King|1971
1972 US Open|Billie Jean King|1972
1973 US Open|Margaret Court|1973
1974 US Open|Billie Jean King|1974
1975 US Open|Chris Evert|1975
1976 US Open|Chris Evert|1976
1977 US Open|Chris Evert|1977
1978 US Open|Chris Evert|1978
1979 US Open|Tracy Austin|1979
1980 US Open|Chris Evert|1980
1981 US Open|Tracy Austin|1981
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'wta',
    relation: 'year_end_no1_women',
    competition: 'WTA year-end rankings',
    sources: const ['wta-rankings', 'tennis-hall-of-fame'],
    data: '''
1975|Chris Evert|1975
1976|Chris Evert|1976
1977|Chris Evert|1977
1978|Martina Navratilova|1978
1979|Martina Navratilova|1979
1980|Chris Evert|1980
1982|Martina Navratilova|1982
1983|Martina Navratilova|1983
1984|Martina Navratilova|1984
1985|Martina Navratilova|1985
''',
    extraOptions: const ['Steffi Graf', 'Tracy Austin', 'Evonne Goolagong'],
  );
}

void _addWtaHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'wta',
    relation: 'slam_runner_up_women',
    competition: 'Grand Slam singles',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
2015 Wimbledon|Garbiñe Muguruza|2015
2016 Wimbledon|Angelique Kerber|2016
2017 Wimbledon|Venus Williams|2017
2018 Wimbledon|Serena Williams|2018
2019 Wimbledon|Serena Williams|2019
2021 Wimbledon|Karolína Plíšková|2021
2016 US Open|Karolína Plíšková|2016
2017 US Open|Madison Keys|2017
2020 US Open|Victoria Azarenka|2020
2021 US Open|Leylah Fernandez|2021
2022 US Open|Ons Jabeur|2022
2025 US Open|Amanda Anisimova|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'wta',
    relation: 'record_holder',
    competition: 'WTA Tour records',
    sources: const ['wta-rankings', 'wta-players'],
    data: '''
most Grand Slam women's singles titles|Margaret Court
most Open Era women's singles slams|Serena Williams
most Wimbledon women's singles titles|Martina Navratilova
most weeks at WTA world No. 1|Steffi Graf
most French Open women's singles titles|Chris Evert
most Australian Open women's singles titles|Margaret Court
most career WTA singles titles|Martina Navratilova
most WTA Finals titles|Martina Navratilova
most consecutive weeks at WTA No. 1|Steffi Graf
most WTA Tour singles match wins|Martina Navratilova
''',
  );
}

void _addWtaHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'wta',
    relation: 'slam_runner_up_women',
    competition: 'Grand Slam singles',
    sources: const ['ausopen-history', 'rolandgarros-history'],
    data: '''
2017 Australian Open|Venus Williams|2017
2018 Australian Open|Simona Halep|2018
2019 Australian Open|Petra Kvitová|2019
2020 Australian Open|Garbiñe Muguruza|2020
2022 Australian Open|Danielle Collins|2022
2025 Australian Open|Aryna Sabalenka|2025
2020 French Open|Sofia Kenin|2020
2021 French Open|Anastasia Pavlyuchenkova|2021
2022 French Open|Coco Gauff|2022
2023 French Open|Karolína Muchová|2023
2024 French Open|Jasmine Paolini|2024
2025 French Open|Aryna Sabalenka|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'wta',
    relation: 'event_winner_women',
    competition: 'WTA Finals',
    sources: const ['wta-tournaments', 'wta-rankings'],
    data: '''
2014 WTA Finals|Serena Williams|2014
2015 WTA Finals|Agnieszka Radwańska|2015
2016 WTA Finals|Dominika Cibulková|2016
2017 WTA Finals|Caroline Wozniacki|2017
2018 WTA Finals|Elina Svitolina|2018
2019 WTA Finals|Ashleigh Barty|2019
2021 WTA Finals|Garbiñe Muguruza|2021
2022 WTA Finals|Caroline Garcia|2022
2023 WTA Finals|Iga Świątek|2023
2024 WTA Finals|Coco Gauff|2024
''',
  );
}

void _addWtaHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Roland-Garros',
    sources: const ['rolandgarros-history', 'wta-tournaments'],
    data: '''
2000 French Open|Mary Pierce|2000
2001 French Open|Jennifer Capriati|2001
2002 French Open|Serena Williams|2002
2003 French Open|Justine Henin|2003
2004 French Open|Anastasia Myskina|2004
2005 French Open|Justine Henin|2005
2006 French Open|Justine Henin|2006
2007 French Open|Justine Henin|2007
2008 French Open|Ana Ivanović|2008
2009 French Open|Svetlana Kuznetsova|2009
2010 French Open|Francesca Schiavone|2010
2011 French Open|Li Na|2011
''',
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'wta',
    relation: 'event_winner_women',
    competition: 'WTA Finals',
    sources: const ['wta-tournaments', 'wta-rankings'],
    data: '''
2004 WTA Finals|Maria Sharapova|2004
2005 WTA Finals|Amélie Mauresmo|2005
2006 WTA Finals|Justine Henin|2006
2007 WTA Finals|Justine Henin|2007
2008 WTA Finals|Venus Williams|2008
2009 WTA Finals|Serena Williams|2009
2010 WTA Finals|Kim Clijsters|2010
2011 WTA Finals|Petra Kvitová|2011
2012 WTA Finals|Serena Williams|2012
2013 WTA Finals|Serena Williams|2013
''',
  );
}

void _addWtaHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Grand Slam singles',
    sources: const ['ausopen-history', 'usopen-history'],
    data: '''
1990 Australian Open|Steffi Graf|1990
1991 Australian Open|Monica Seles|1991
1992 Australian Open|Monica Seles|1992
1993 Australian Open|Monica Seles|1993
1994 Australian Open|Steffi Graf|1994
1995 Australian Open|Mary Pierce|1995
1996 Australian Open|Monica Seles|1996
1997 Australian Open|Martina Hingis|1997
1998 Australian Open|Martina Hingis|1998
1999 Australian Open|Martina Hingis|1999
1998 US Open|Lindsay Davenport|1998
1999 US Open|Serena Williams|1999
''',
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'wta',
    relation: 'hall_of_fame_year',
    competition: 'International Tennis Hall of Fame',
    sources: const ['tennis-hall-of-fame', 'wta-players'],
    data: '''
Steffi Graf|2004
Martina Navratilova|2000
Chris Evert|1995
Billie Jean King|1987
Margaret Court|1979
Monica Seles|2009
Martina Hingis|2013
Arantxa Sánchez Vicario|2007
Gabriela Sabatini|2006
Lindsay Davenport|2014
''',
  );
}

void _addWtaHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Wimbledon',
    sources: const ['wimbledon-history', 'tennis-hall-of-fame'],
    data: '''
1953 Wimbledon|Maureen Connolly|1953
1957 Wimbledon|Althea Gibson|1957
1958 Wimbledon|Althea Gibson|1958
1959 Wimbledon|Maria Bueno|1959
1960 Wimbledon|Maria Bueno|1960
1961 Wimbledon|Angela Mortimer|1961
1962 Wimbledon|Karen Susman|1962
1963 Wimbledon|Margaret Court|1963
1964 Wimbledon|Maria Bueno|1964
1965 Wimbledon|Margaret Court|1965
1966 Wimbledon|Billie Jean King|1966
1967 Wimbledon|Billie Jean King|1967
''',
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['tennis-hall-of-fame', 'wta-players'],
    data: '''
Maria Bueno|Brazil
Althea Gibson|United States
Angela Mortimer|United Kingdom
Lesley Turner|Australia
Virginia Ruzici|Romania
Sue Barker|United Kingdom
Mima Jaušovec|Yugoslavia
Kerry Melville|Australia
Françoise Dürr|France
Maureen Connolly|United States
''',
  );
}

void _addWtaGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Zheng Qinwen|China
Ons Jabeur|Tunisia
Karolína Muchová|Czech Republic
Jasmine Paolini|Italy
Mirra Andreeva|Russia
Emma Navarro|United States
Paula Badosa|Spain
Beatriz Haddad Maia|Brazil
Leylah Fernandez|Canada
Bianca Andreescu|Canada
Elina Svitolina|Ukraine
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'wta',
    relation: 'event_winner_women',
    competition: 'WTA 1000',
    sources: const ['wta-tournaments', 'wta-rankings'],
    data: '''
2018 Indian Wells|Naomi Osaka|2018
2019 Indian Wells|Bianca Andreescu|2019
2021 Indian Wells|Paula Badosa|2021
2019 Miami|Ashleigh Barty|2019
2021 Miami|Ashleigh Barty|2021
2019 Madrid|Kiki Bertens|2019
2021 Madrid|Aryna Sabalenka|2021
2019 Rome|Karolína Plíšková|2019
2021 Rome|Iga Świątek|2021
2022 Rome|Iga Świątek|2022
''',
  );
}

void _addWtaGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Donna Vekić|Croatia
Anett Kontaveit|Estonia
Kaia Kanepi|Estonia
Yulia Putintseva|Kazakhstan
Sorana Cîrstea|Romania
Anhelina Kalinina|Ukraine
Dayana Yastremska|Ukraine
Magda Linette|Poland
Magdalena Fręch|Poland
Diana Shnaider|Russia
Viktorija Golubic|Switzerland
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'wta',
    relation: 'event_winner_women',
    competition: 'WTA 1000',
    sources: const ['wta-tournaments', 'wta-rankings'],
    data: '''
2016 Indian Wells|Victoria Azarenka|2016
2017 Indian Wells|Elena Vesnina|2017
2016 Miami|Victoria Azarenka|2016
2017 Miami|Johanna Konta|2017
2016 Madrid|Simona Halep|2016
2017 Madrid|Simona Halep|2017
2018 Madrid|Petra Kvitová|2018
2016 Rome|Serena Williams|2016
2017 Rome|Elina Svitolina|2017
2018 Rome|Elina Svitolina|2018
''',
  );
}

void _addWtaGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Zhang Shuai|China
Wang Xinyu|China
Nao Hibino|Japan
Moyuka Uchijima|Japan
Lucia Bronzetti|Italy
Elisabetta Cocciaretto|Italy
Rebeka Masarova|Spain
Cristina Bucșa|Spain
Camila Osorio|Colombia
Nadia Podoroska|Argentina
Renata Zarazúa|Mexico
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'US Open',
    sources: const ['usopen-history', 'wta-tournaments'],
    data: '''
2000 US Open|Venus Williams|2000
2001 US Open|Venus Williams|2001
2002 US Open|Serena Williams|2002
2003 US Open|Justine Henin|2003
2004 US Open|Svetlana Kuznetsova|2004
2005 US Open|Kim Clijsters|2005
2006 US Open|Maria Sharapova|2006
2007 US Open|Justine Henin|2007
2009 US Open|Kim Clijsters|2009
2010 US Open|Kim Clijsters|2010
''',
  );
}

void _addWtaGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Tamara Korpatsch|Germany
Laura Siegemund|Germany
Greet Minnen|Belgium
Elise Mertens|Belgium
Clara Tauson|Denmark
Rebecca Peterson|Sweden
Kaja Juvan|Slovenia
Tamara Zidanšek|Slovenia
Ann Li|United States
Katie Boulter|United Kingdom
Harriet Dart|United Kingdom
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Australian Open',
    sources: const ['ausopen-history', 'tennis-hall-of-fame'],
    data: '''
1976 Australian Open|Evonne Goolagong|1976
1978 Australian Open|Chris O'Neil|1978
1979 Australian Open|Barbara Jordan|1979
1980 Australian Open|Hana Mandlíková|1980
1981 Australian Open|Martina Navratilova|1981
1982 Australian Open|Chris Evert|1982
1983 Australian Open|Martina Navratilova|1983
1984 Australian Open|Chris Evert|1984
1985 Australian Open|Martina Navratilova|1985
1987 Australian Open|Hana Mandlíková|1987
''',
  );
}

void _addWtaGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'wta',
    relation: 'player_nationality',
    competition: 'WTA Tour',
    sources: const ['tennis-hall-of-fame', 'wta-players'],
    data: '''
Betty Stöve|Netherlands
Wendy Turnbull|Australia
Dianne Fromholtz|Australia
Regina Maršíková|Czechoslovakia
Helena Suková|Czechoslovakia
Claudia Kohde-Kilsch|Germany
Bettina Bunge|Germany
Manuela Maleeva|Bulgaria
Katerina Maleeva|Bulgaria
Zina Garrison|United States
Andrea Jaeger|United States
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'wta',
    relation: 'slam_champion_women',
    competition: 'Roland-Garros',
    sources: const ['rolandgarros-history', 'tennis-hall-of-fame'],
    data: '''
1968 French Open|Nancy Richey|1968
1969 French Open|Margaret Court|1969
1970 French Open|Margaret Court|1970
1971 French Open|Evonne Goolagong|1971
1972 French Open|Billie Jean King|1972
1973 French Open|Margaret Court|1973
1974 French Open|Chris Evert|1974
1975 French Open|Chris Evert|1975
1978 French Open|Virginia Ruzici|1978
1979 French Open|Chris Evert|1979
''',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MAJORS & FLAGSHIP EVENTS — 215 facts (easy 60, medium 55, hard 50,
// global 50). The four Grand Slams as institutions, plus the Masters 1000 /
// WTA 1000 / Tour Finals tier: surfaces, venues, show courts, trophies,
// founding years, formats and tournament records.
// ─────────────────────────────────────────────────────────────────────────────

void _addMajorsEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'majors_events',
    relation: 'event_surface',
    competition: 'Grand Slam tournaments',
    sources: const ['itf-rules', 'wimbledon-history'],
    data: '''
Australian Open|hard court
French Open|clay court
Wimbledon|grass court
US Open|hard court
''',
    extraOptions: const ['carpet court', 'indoor wood court'],
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'majors_events',
    relation: 'event_city',
    competition: 'Grand Slam tournaments',
    sources: const ['ausopen-history', 'rolandgarros-history'],
    data: '''
Australian Open|Melbourne
French Open|Paris
Wimbledon|London
US Open|New York City
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'majors_events',
    relation: 'event_country',
    competition: 'Grand Slam tournaments',
    sources: const ['ausopen-history', 'usopen-history'],
    data: '''
Australian Open|Australia
French Open|France
Wimbledon|United Kingdom
US Open|United States
''',
  );
}

void _addMajorsEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'majors_events',
    relation: 'event_venue',
    competition: 'Grand Slam tournaments',
    sources: const ['ausopen-history', 'wimbledon-history'],
    data: '''
Australian Open|Melbourne Park
French Open|Stade Roland-Garros
Wimbledon|the All England Club
US Open|Flushing Meadows
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'majors_events',
    relation: 'show_court',
    competition: 'Grand Slam tournaments',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
Wimbledon|Centre Court
the Australian Open|Rod Laver Arena
Roland-Garros|Court Philippe-Chatrier
the US Open|Arthur Ashe Stadium
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'majors_events',
    relation: 'first_year',
    competition: 'Grand Slam tournaments',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
the Wimbledon Championships|1877
the US Open|1881
the French Championships|1891
the Australian Championships|1905
''',
  );
}

void _addMajorsEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'majors_events',
    relation: 'trophy_name',
    competition: 'Grand Slam tournaments',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
Wimbledon men's|the Gentlemen's Singles Trophy
Wimbledon women's|the Venus Rosewater Dish
Roland-Garros men's|the Coupe des Mousquetaires
Roland-Garros women's|the Coupe Suzanne Lenglen
the Australian Open men's|the Norman Brookes Challenge Cup
the Australian Open women's|the Daphne Akhurst Memorial Cup
''',
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'majors_events',
    relation: 'tour_tier',
    competition: 'Tour structure',
    sources: const ['atp-tournaments', 'wta-tournaments'],
    data: '''
Australian Open|Grand Slam
US Open|Grand Slam
Indian Wells Masters|ATP Masters 1000
Rome Masters|ATP Masters 1000
Dubai Tennis Championships|ATP 500
Barcelona Open|ATP 500
''',
    extraOptions: const ['ATP 250', 'ATP Challenger'],
  );
}

void _addMajorsEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'majors_events',
    relation: 'event_city',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
Indian Wells Masters|Indian Wells
Madrid Open|Madrid
Cincinnati Masters|Mason
Paris Masters|Paris
Shanghai Masters|Shanghai
Miami Open|Miami Gardens
''',
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'majors_events',
    relation: 'event_venue',
    competition: 'ATP Masters 1000',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
Indian Wells Masters|Indian Wells Tennis Garden
Miami Open|Hard Rock Stadium
Monte-Carlo Masters|Monte Carlo Country Club
Rome Masters|Foro Italico
Madrid Open|Caja Mágica
Paris Masters|Accor Arena
''',
  );
}

void _addMajorsEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'majors_events',
    relation: 'event_country',
    competition: 'ATP Tour',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Delray Beach Open|United States
Buenos Aires Open|Argentina
Geneva Open|Switzerland
Queen's Club Championships|United Kingdom
Brisbane International|Australia
Zhuhai Championships|China
''',
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'majors_events',
    relation: 'first_year',
    competition: 'Tour structure',
    sources: const ['atp-tournaments', 'daviscup-history'],
    data: '''
the ATP Finals|1970
the Laver Cup|2017
the Davis Cup|1900
the Billie Jean King Cup|1963
the WTA Finals|1972
the ATP Tour|1990
''',
  );
}

void _addMajorsMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'majors_events',
    relation: 'record_holder',
    competition: 'Grand Slam records',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
most men's singles titles at Wimbledon|Roger Federer
most women's singles titles at Wimbledon|Martina Navratilova
most men's singles titles at Roland-Garros|Rafael Nadal
most women's singles titles at Roland-Garros|Chris Evert
most men's singles titles at the US Open|Jimmy Connors
most men's singles titles at the Australian Open|Novak Djokovic
''',
    extraOptions: const ['Steffi Graf', 'Pete Sampras'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'majors_events',
    relation: 'record_value',
    competition: 'Grand Slam records',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
most men's singles titles at Wimbledon|8
most women's singles titles at Wimbledon|9
most men's singles titles at Roland-Garros|14
most women's singles titles at Roland-Garros|7
most men's singles titles at the Australian Open|10
''',
    extraOptions: const ['12', '6'],
  );
}

void _addMajorsMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'majors_events',
    relation: 'event_venue',
    competition: 'Tour flagship events',
    sources: const ['atp-tournaments', 'wta-tournaments'],
    data: '''
Cincinnati Masters|Lindner Family Tennis Center
Shanghai Masters|Qizhong Forest Sports City
Canadian Open|Sobeys Stadium
Halle Open|OWL Arena
Queen's Club Championships|the Queen's Club
Swiss Indoors|St. Jakobshalle
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'majors_events',
    relation: 'show_court',
    competition: 'Tour flagship events',
    sources: const ['atp-tournaments', 'wta-tournaments'],
    data: '''
the Indian Wells Masters|Stadium 1
the Rome Masters|Campo Centrale
the Madrid Open|Manolo Santana Stadium
the Miami Open|the Stadium Court
the Monte-Carlo Masters|Court Rainier III
''',
  );
}

void _addMajorsMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'majors_events',
    relation: 'tour_tier',
    competition: 'Tour structure',
    sources: const ['atp-tournaments', 'wta-tournaments'],
    data: '''
Miami Open|ATP Masters 1000
Madrid Open|ATP Masters 1000
Halle Open|ATP 500
Queen's Club Championships|ATP 500
Rotterdam Open|ATP 500
Swiss Indoors|ATP 500
''',
    extraOptions: const ['Grand Slam', 'ATP 250'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'majors_events',
    relation: 'event_city',
    competition: 'Tour flagship events',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Rome Masters|Rome
Monte-Carlo Masters|Roquebrune-Cap-Martin
Canadian Open|Toronto and Montreal
Halle Open|Halle
Queen's Club Championships|London
''',
  );
}

void _addMajorsMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'majors_events',
    relation: 'record_holder',
    competition: 'Open Era firsts',
    sources: const ['wimbledon-history', 'rolandgarros-history'],
    data: '''
the first player to win a Golden Slam|Steffi Graf
the first Open Era Australian Open men's champion|Bill Bowrey
the first Open Era Wimbledon women's champion|Billie Jean King
the first Open Era Roland-Garros women's champion|Nancy Richey
the first Open Era US Open women's champion|Virginia Wade
the first Open Era Australian Open women's champion|Billie Jean King
''',
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'majors_events',
    relation: 'record_value',
    competition: 'Grand Slam records',
    sources: const ['wimbledon-history', 'wta-players'],
    data: '''
games in the 2010 Isner-Mahut fifth set|138
aces by John Isner against Nicolas Mahut|113
the length of the 2010 Isner-Mahut match in hours|11
Grand Slam singles titles won by Margaret Court|24
Grand Slam singles titles won by Serena Williams|23
''',
  );
}

void _addMajorsMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'majors_events',
    relation: 'event_country',
    competition: 'Tour calendar',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Rotterdam Open|Netherlands
Vienna Open|Austria
Hamburg Open|Germany
Marbella Open|Spain
Båstad Open|Sweden
Lyon Open|France
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'majors_events',
    relation: 'tour_tier',
    competition: 'Tour structure',
    sources: const ['atp-tournaments', 'wta-tournaments'],
    data: '''
French Open|Grand Slam
Wimbledon|Grand Slam
Canadian Open|ATP Masters 1000
Cincinnati Masters|ATP Masters 1000
Japan Open|ATP 500
''',
    extraOptions: const ['ATP 250', 'WTA 1000'],
  );
}

void _addMajorsHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'majors_events',
    relation: 'record_holder',
    competition: 'Grand Slam records',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
the youngest Open Era men's slam champion|Michael Chang
the youngest Open Era women's slam champion|Martina Hingis
the oldest Open Era men's slam champion|Ken Rosewall
most aces in a single match|John Isner
most Wimbledon men's singles finals|Roger Federer
most Grand Slam singles finals by a man|Novak Djokovic
most Grand Slam singles finals by a woman|Chris Evert
the first Open Era Wimbledon men's champion|Rod Laver
the first Open Era US Open men's champion|Arthur Ashe
the first Open Era Roland-Garros men's champion|Ken Rosewall
''',
  );
}

void _addMajorsHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'majors_events',
    relation: 'first_year',
    competition: 'Tour flagship events',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
the Indian Wells Masters|1976
the Miami Open|1985
the Monte-Carlo Masters|1897
the Rome Masters|1930
the Canadian Open|1881
the Cincinnati Masters|1899
the Shanghai Masters|2009
the Madrid Open|2002
the Paris Masters|1968
the Queen's Club Championships|1890
''',
  );
}

void _addMajorsHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'majors_events',
    relation: 'event_surface',
    competition: 'Tour flagship events',
    sources: const ['atp-tournaments', 'itf-rules'],
    data: '''
Monte-Carlo Masters|clay court
Cincinnati Masters|hard court
Halle Open|grass court
Queen's Club Championships|grass court
Shanghai Masters|hard court
''',
    extraOptions: const ['carpet court', 'indoor clay court'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'majors_events',
    relation: 'event_venue',
    competition: 'Tour calendar',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Erste Bank Open|Wiener Stadthalle
Rotterdam Open|Ahoy Rotterdam
Stockholm Open|Kungliga Tennishallen
Dubai Tennis Championships|Aviation Club Tennis Centre
Qatar Open|Khalifa Tennis Complex
''',
  );
}

void _addMajorsHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'majors_events',
    relation: 'second_court',
    competition: 'Grand Slam tournaments',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
Wimbledon|No. 1 Court
Roland-Garros|Court Suzanne-Lenglen
the Australian Open|Margaret Court Arena
the US Open|Louis Armstrong Stadium
the Indian Wells Masters|Stadium 2
''',
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'majors_events',
    relation: 'tour_tier',
    competition: 'WTA Tour structure',
    sources: const ['wta-tournaments', 'wta-rankings'],
    data: '''
Wuhan Open|WTA 1000
Doha Open|WTA 1000
Charleston Open|WTA 500
Stuttgart Open|WTA 500
Bad Homburg Open|WTA 250
''',
    extraOptions: const ['Grand Slam', 'ATP Masters 1000'],
  );
}

void _addMajorsHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'majors_events',
    relation: 'record_holder',
    competition: 'Grand Slam records',
    sources: const ['tennis-hall-of-fame', 'wimbledon-history'],
    data: '''
the first man to win all four majors in one year|Don Budge
the first woman to win all four majors in one year|Maureen Connolly
the first man to win a Career Golden Slam|Andre Agassi
the first woman to win a Career Golden Slam|Steffi Graf
the last man to win a calendar Grand Slam|Rod Laver
''',
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'majors_events',
    relation: 'introduced_year',
    competition: 'Grand Slam formats',
    sources: const ['wimbledon-history', 'usopen-history'],
    data: '''
the Centre Court roof at Wimbledon|2009
hard courts at the Australian Open|1988
hard courts at the US Open|1978
the final-set tiebreak at Wimbledon|2019
the US Open final-set tiebreak|1970
''',
  );
}

void _addMajorsGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'majors_events',
    relation: 'event_country',
    competition: 'World tour calendar',
    sources: const ['wta-tournaments', 'itf-world-tour'],
    data: '''
Wuhan Open|China
Guadalajara Open|Mexico
Doha Open|Qatar
Charleston Open|United States
Bad Homburg Open|Germany
Stuttgart Open|Germany
Berlin Open|Germany
Hobart International|Australia
Merida Open|Mexico
Abu Dhabi Open|United Arab Emirates
''',
  );
}

void _addMajorsGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'majors_events',
    relation: 'event_surface',
    competition: 'World tour calendar',
    sources: const ['wta-tournaments', 'itf-rules'],
    data: '''
Wuhan Open|hard court
Charleston Open|clay court
Stuttgart Open|clay court
Berlin Open|grass court
Bad Homburg Open|grass court
Doha Open|hard court
Guadalajara Open|hard court
Båstad Open|clay court
Newport Hall of Fame Open|grass court
Kitzbühel Open|clay court
''',
    extraOptions: const ['carpet court', 'indoor hard court'],
  );
}

void _addMajorsGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'majors_events',
    relation: 'event_venue',
    competition: 'World tour calendar',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Japan Open|Ariake Coliseum
China Open|National Tennis Center
Wuhan Open|Optics Valley Tennis Center
Mexican Open|Arena GNP Seguros
Rio Open|Jockey Club Brasileiro
Croatia Open Umag|ITC Stella Maris
Hamburg European Open|Am Rothenbaum
Kremlin Cup|Olympic Stadium
Winston-Salem Open|Wake Forest Tennis Complex
Newport Hall of Fame Open|the Newport Casino
''',
  );
}

void _addMajorsGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'majors_events',
    relation: 'tour_tier',
    competition: 'Tour structure',
    sources: const ['atp-tournaments', 'atp-rankings'],
    data: '''
Monte-Carlo Masters|ATP Masters 1000
Paris Masters|ATP Masters 1000
Shanghai Masters|ATP Masters 1000
Erste Bank Open|ATP 500
Rio Open|ATP 500
Mexican Open|ATP 500
China Open|ATP 500
Stockholm Open|ATP 250
Winston-Salem Open|ATP 250
Newport Hall of Fame Open|ATP 250
''',
    extraOptions: const ['Grand Slam', 'WTA 1000'],
  );
}

void _addMajorsGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'majors_events',
    relation: 'introduced_year',
    competition: 'Tennis milestones',
    sources: const ['itf-rules', 'atp-rankings'],
    data: '''
the Open Era|1968
the ATP computer rankings|1973
the WTA rankings|1975
the tiebreak at Wimbledon|1971
the Hawk-Eye challenge system|2006
the roof on Rod Laver Arena|1988
the roof on Court Philippe-Chatrier|2020
the Arthur Ashe Stadium roof|2016
the shot clock at the US Open|2018
the final-set tiebreak at Roland-Garros|2022
''',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TEAM EVENTS — 190 facts (easy 30, medium 35, hard 35, global 90).
// Davis Cup, Billie Jean King Cup (Fed Cup), Olympic tennis, Laver Cup,
// United Cup and the Hopman Cup. This scope surges in GLOBAL, where it is the
// second-largest after ATP.
// ─────────────────────────────────────────────────────────────────────────────

void _addTeamEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'itf-world-tour'],
    data: '''
2015 Davis Cup|Great Britain|2015
2016 Davis Cup|Argentina|2016
2017 Davis Cup|France|2017
2018 Davis Cup|Croatia|2018
2019 Davis Cup|Spain|2019
2022 Davis Cup|Canada|2022
''',
  );
}

void _addTeamEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'itf-world-tour'],
    data: '''
2012 Davis Cup|Czech Republic|2012
2013 Davis Cup|Czech Republic|2013
2014 Davis Cup|Switzerland|2014
2021 Davis Cup|Russian Tennis Federation|2021
2023 Davis Cup|Italy|2023
2024 Davis Cup|Italy|2024
''',
  );
}

void _addTeamEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'itf-world-tour'],
    data: '''
2006 Davis Cup|Russia|2006
2007 Davis Cup|United States|2007
2008 Davis Cup|Spain|2008
2009 Davis Cup|Spain|2009
2010 Davis Cup|Serbia|2010
2011 Davis Cup|Spain|2011
''',
  );
}

void _addTeamEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'itf-world-tour'],
    data: '''
2000 Davis Cup|Spain|2000
2001 Davis Cup|France|2001
2002 Davis Cup|Russia|2002
2003 Davis Cup|Australia|2003
2004 Davis Cup|Spain|2004
2005 Davis Cup|Croatia|2005
''',
  );
}

void _addTeamEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1990 Davis Cup|United States|1990
1991 Davis Cup|France|1991
1992 Davis Cup|United States|1992
1993 Davis Cup|Germany|1993
1994 Davis Cup|Sweden|1994
1995 Davis Cup|United States|1995
''',
  );
}

void _addTeamMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Billie Jean King Cup',
    sources: const ['bjkcup-history', 'itf-world-tour'],
    data: '''
2017 Fed Cup|United States|2017
2018 Fed Cup|Czech Republic|2018
2019 Fed Cup|France|2019
2021 Billie Jean King Cup|Russian Tennis Federation|2021
2022 Billie Jean King Cup|Switzerland|2022
2023 Billie Jean King Cup|Canada|2023
2024 Billie Jean King Cup|Italy|2024
''',
  );
}

void _addTeamMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Fed Cup',
    sources: const ['bjkcup-history', 'itf-world-tour'],
    data: '''
2010 Fed Cup|Italy|2010
2011 Fed Cup|Czech Republic|2011
2012 Fed Cup|Czech Republic|2012
2013 Fed Cup|Italy|2013
2014 Fed Cup|Czech Republic|2014
2015 Fed Cup|Czech Republic|2015
2016 Fed Cup|Czech Republic|2016
''',
    extraOptions: const ['United States', 'Russia', 'France'],
  );
}

void _addTeamMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Fed Cup',
    sources: const ['bjkcup-history', 'itf-world-tour'],
    data: '''
2003 Fed Cup|France|2003
2004 Fed Cup|Russia|2004
2005 Fed Cup|Russia|2005
2006 Fed Cup|Italy|2006
2007 Fed Cup|Russia|2007
2008 Fed Cup|Russia|2008
2009 Fed Cup|Italy|2009
''',
    extraOptions: const ['United States', 'Spain'],
  );
}

void _addTeamMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Fed Cup',
    sources: const ['bjkcup-history', 'tennis-hall-of-fame'],
    data: '''
1996 Fed Cup|United States|1996
1997 Fed Cup|France|1997
1998 Fed Cup|Spain|1998
1999 Fed Cup|United States|1999
2000 Fed Cup|United States|2000
2001 Fed Cup|Belgium|2001
2002 Fed Cup|Slovakia|2002
''',
  );
}

void _addTeamMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Fed Cup',
    sources: const ['bjkcup-history', 'tennis-hall-of-fame'],
    data: '''
1963 Fed Cup|United States|1963
1964 Fed Cup|Australia|1964
1965 Fed Cup|Australia|1965
1966 Fed Cup|United States|1966
1970 Fed Cup|Australia|1970
1975 Fed Cup|Czechoslovakia|1975
1980 Fed Cup|United States|1980
''',
    extraOptions: const ['South Africa', 'United Kingdom'],
  );
}

void _addTeamHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'team_events',
    relation: 'olympic_gold_men',
    competition: 'Olympic tennis',
    sources: const ['olympics-tennis', 'itf-world-tour'],
    data: '''
2000 Olympics|Yevgeny Kafelnikov|2000
2004 Olympics|Nicolás Massú|2004
2008 Olympics|Rafael Nadal|2008
2012 Olympics|Andy Murray|2012
2016 Olympics|Andy Murray|2016
2020 Olympics|Alexander Zverev|2020
2024 Olympics|Novak Djokovic|2024
''',
  );
}

void _addTeamHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'team_events',
    relation: 'olympic_gold_women',
    competition: 'Olympic tennis',
    sources: const ['olympics-tennis', 'itf-world-tour'],
    data: '''
2000 Olympics|Venus Williams|2000
2004 Olympics|Justine Henin|2004
2008 Olympics|Elena Dementieva|2008
2012 Olympics|Serena Williams|2012
2016 Olympics|Monica Puig|2016
2020 Olympics|Belinda Bencic|2020
2024 Olympics|Zheng Qinwen|2024
''',
  );
}

void _addTeamHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1980 Davis Cup|Czechoslovakia|1980
1981 Davis Cup|United States|1981
1982 Davis Cup|United States|1982
1983 Davis Cup|Australia|1983
1984 Davis Cup|Sweden|1984
1985 Davis Cup|Sweden|1985
1986 Davis Cup|Australia|1986
''',
  );
}

void _addTeamHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1973 Davis Cup|Australia|1973
1974 Davis Cup|South Africa|1974
1975 Davis Cup|Sweden|1975
1976 Davis Cup|Italy|1976
1977 Davis Cup|Australia|1977
1978 Davis Cup|United States|1978
1979 Davis Cup|United States|1979
''',
  );
}

void _addTeamHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1900 Davis Cup|United States|1900
1905 Davis Cup|British Isles|1905
1907 Davis Cup|Australasia|1907
1927 Davis Cup|France|1927
1937 Davis Cup|United States|1937
1950 Davis Cup|Australia|1950
1968 Davis Cup|United States|1968
''',
  );
}

void _addTeamGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1970 Davis Cup|United States|1970
1971 Davis Cup|United States|1971
1972 Davis Cup|United States|1972
1987 Davis Cup|Sweden|1987
1988 Davis Cup|Germany|1988
1989 Davis Cup|Germany|1989
1996 Davis Cup|France|1996
1997 Davis Cup|Sweden|1997
1998 Davis Cup|Sweden|1998
1999 Davis Cup|Australia|1999
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'team_events',
    relation: 'olympic_gold_men',
    competition: 'Olympic tennis',
    sources: const ['olympics-tennis', 'tennis-hall-of-fame'],
    data: '''
1924 Olympics|Vincent Richards|1924
1988 Olympics|Miloslav Mečíř|1988
1992 Olympics|Marc Rosset|1992
1996 Olympics|Andre Agassi|1996
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'team_events',
    relation: 'olympic_gold_women',
    competition: 'Olympic tennis',
    sources: const ['olympics-tennis', 'tennis-hall-of-fame'],
    data: '''
1924 Olympics|Helen Wills|1924
1988 Olympics|Steffi Graf|1988
1992 Olympics|Jennifer Capriati|1992
1996 Olympics|Lindsay Davenport|1996
''',
  );
}

void _addTeamGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Fed Cup',
    sources: const ['bjkcup-history', 'tennis-hall-of-fame'],
    data: '''
1986 Fed Cup|United States|1986
1987 Fed Cup|West Germany|1987
1988 Fed Cup|Czechoslovakia|1988
1989 Fed Cup|United States|1989
1990 Fed Cup|United States|1990
1991 Fed Cup|Spain|1991
1992 Fed Cup|Germany|1992
1993 Fed Cup|Spain|1993
1994 Fed Cup|Spain|1994
1995 Fed Cup|Spain|1995
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1954 Davis Cup|United States|1954
1955 Davis Cup|Australia|1955
1960 Davis Cup|Australia|1960
1963 Davis Cup|United States|1963
1964 Davis Cup|Australia|1964
1965 Davis Cup|Australia|1965
1966 Davis Cup|Australia|1966
1969 Davis Cup|United States|1969
''',
    extraOptions: const ['France', 'British Isles', 'Italy'],
  );
}

void _addTeamGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Fed Cup',
    sources: const ['bjkcup-history', 'tennis-hall-of-fame'],
    data: '''
1974 Fed Cup|Australia|1974
1976 Fed Cup|United States|1976
1977 Fed Cup|United States|1977
1978 Fed Cup|United States|1978
1979 Fed Cup|United States|1979
1981 Fed Cup|United States|1981
1982 Fed Cup|United States|1982
1983 Fed Cup|Czechoslovakia|1983
1984 Fed Cup|Czechoslovakia|1984
1985 Fed Cup|Czechoslovakia|1985
''',
    extraOptions: const ['Germany', 'Spain'],
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'team_events',
    relation: 'first_year',
    competition: 'Team tennis events',
    sources: const ['itf-world-tour', 'atp-tournaments'],
    data: '''
the Hopman Cup|1989
the United Cup|2023
the ATP Cup|2020
the Next Gen ATP Finals|2017
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'team_events',
    relation: 'event_country',
    competition: 'Team tennis events',
    sources: const ['lavercup-results', 'itf-world-tour'],
    data: '''
the Hopman Cup|Australia
the United Cup|Australia
the Laver Cup 2017|Czech Republic
the Laver Cup 2018|United States
''',
    extraOptions: const ['Switzerland', 'United Kingdom'],
  );
}

void _addTeamGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1935 Davis Cup|Great Britain|1935
1936 Davis Cup|Great Britain|1936
1938 Davis Cup|United States|1938
1939 Davis Cup|Australia|1939
1946 Davis Cup|United States|1946
1948 Davis Cup|United States|1948
1949 Davis Cup|United States|1949
1951 Davis Cup|Australia|1951
1952 Davis Cup|Australia|1952
1953 Davis Cup|Australia|1953
''',
    extraOptions: const ['France', 'Italy'],
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'team_events',
    relation: 'event_country',
    competition: 'Team tennis events',
    sources: const ['lavercup-results', 'olympics-tennis'],
    data: '''
the Laver Cup 2019|Switzerland
the Laver Cup 2021|United States
the Laver Cup 2022|United Kingdom
the Laver Cup 2023|Canada
the Laver Cup 2024|Germany
the 2024 Olympic tennis event|France
the 2020 Olympic tennis event|Japan
the 2016 Olympic tennis event|Brazil
''',
  );
}

void _addTeamGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'tennis-hall-of-fame'],
    data: '''
1920 Davis Cup|United States|1920
1924 Davis Cup|United States|1924
1925 Davis Cup|United States|1925
1926 Davis Cup|United States|1926
1928 Davis Cup|France|1928
1929 Davis Cup|France|1929
1930 Davis Cup|France|1930
1931 Davis Cup|France|1931
1932 Davis Cup|France|1932
1912 Davis Cup|British Isles|1912
''',
    extraOptions: const ['Australasia', 'Australia'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'team_events',
    relation: 'team_event_winner',
    competition: 'Davis Cup',
    sources: const ['daviscup-history', 'itf-world-tour'],
    data: '''
1902 Davis Cup|United States|1902
1903 Davis Cup|British Isles|1903
1904 Davis Cup|British Isles|1904
1908 Davis Cup|Australasia|1908
1909 Davis Cup|Australasia|1909
1911 Davis Cup|Australasia|1911
1913 Davis Cup|United States|1913
1914 Davis Cup|Australasia|1914
''',
    extraOptions: const ['France', 'Australia'],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DOUBLES — 145 facts (easy 25, medium 30, hard 35, global 55).
// Men's, women's and mixed doubles. Winning pairs are named by surname so every
// option stays inside the 34-character cap.
// ─────────────────────────────────────────────────────────────────────────────

void _addDoublesEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'doubles',
    relation: 'doubles_partner',
    competition: 'Doubles partnerships',
    sources: const ['atp-players', 'wta-players'],
    data: '''
Mike Bryan|Bob Bryan
Todd Woodbridge|Mark Woodforde
Martina Navratilova|Pam Shriver
Venus Williams|Serena Williams
Pierre-Hugues Herbert|Nicolas Mahut
''',
  );
}

void _addDoublesEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'doubles',
    relation: 'doubles_champion_men',
    competition: 'Wimbledon doubles',
    sources: const ['wimbledon-history', 'atp-tournaments'],
    data: '''
2019 Wimbledon|Cabal and Farah|2019
2021 Wimbledon|Mektić and Pavić|2021
2022 Wimbledon|Ebden and Purcell|2022
2023 Wimbledon|Koolhof and Skupski|2023
2024 Wimbledon|Heliövaara and Patten|2024
''',
  );
}

void _addDoublesEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'doubles',
    relation: 'doubles_champion_women',
    competition: 'Wimbledon doubles',
    sources: const ['wimbledon-history', 'wta-tournaments'],
    data: '''
2019 Wimbledon|Hsieh and Strýcová|2019
2021 Wimbledon|Hsieh and Mertens|2021
2022 Wimbledon|Krejčíková and Siniaková|2022
2023 Wimbledon|Hsieh and Wang|2023
2024 Wimbledon|Siniaková and Townsend|2024
''',
  );
}

void _addDoublesEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'doubles',
    relation: 'doubles_partner',
    competition: 'Doubles partnerships',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
John McEnroe|Peter Fleming
Ken Flach|Robert Seguso
Anders Järryd|Stefan Edberg
Jacco Eltingh|Paul Haarhuis
Daniel Nestor|Mark Knowles
''',
  );
}

void _addDoublesEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'doubles',
    relation: 'doubles_champion_mixed',
    competition: 'Wimbledon mixed doubles',
    sources: const ['wimbledon-history', 'itf-world-tour'],
    data: '''
2019 Wimbledon|Chan and Dodig|2019
2021 Wimbledon|Krawczyk and Skupski|2021
2022 Wimbledon|Krawczyk and Skupski|2022
2023 Wimbledon|Kichenok and Pavić|2023
2024 Wimbledon|Siniaková and Zieliński|2024
''',
  );
}

void _addDoublesMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'doubles',
    relation: 'doubles_champion_men',
    competition: 'US Open doubles',
    sources: const ['usopen-history', 'atp-tournaments'],
    data: '''
2019 US Open|Cabal and Farah|2019
2020 US Open|Pavić and Soares|2020
2021 US Open|Ram and Salisbury|2021
2022 US Open|Ram and Salisbury|2022
2023 US Open|Ram and Salisbury|2023
2024 US Open|Krawietz and Pütz|2024
''',
    extraOptions: const ['Mektić and Pavić', 'Ebden and Purcell'],
  );
}

void _addDoublesMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'doubles',
    relation: 'doubles_champion_women',
    competition: 'US Open doubles',
    sources: const ['usopen-history', 'wta-tournaments'],
    data: '''
2019 US Open|Mertens and Sabalenka|2019
2020 US Open|Siegemund and Zvonareva|2020
2021 US Open|Stosur and Zhang|2021
2022 US Open|Krejčíková and Siniaková|2022
2023 US Open|Gauff and Pegula|2023
2024 US Open|Errani and Paolini|2024
''',
  );
}

void _addDoublesMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'doubles',
    relation: 'doubles_partner',
    competition: 'Doubles partnerships',
    sources: const ['atp-players', 'wta-players'],
    data: '''
Bruno Soares|Jamie Murray
Rajeev Ram|Joe Salisbury
Kateřina Siniaková|Barbora Krejčíková
Elise Mertens|Aryna Sabalenka
Rohan Bopanna|Matthew Ebden
Ivan Dodig|Austin Krajicek
''',
  );
}

void _addDoublesMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'doubles',
    relation: 'doubles_champion_men',
    competition: 'Roland-Garros doubles',
    sources: const ['rolandgarros-history', 'atp-tournaments'],
    data: '''
2019 French Open|Krawietz and Mies|2019
2020 French Open|Krawietz and Mies|2020
2021 French Open|Herbert and Mahut|2021
2022 French Open|Arévalo and Rojer|2022
2023 French Open|Dodig and Krajicek|2023
2024 French Open|Arévalo and Pavić|2024
''',
  );
}

void _addDoublesMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'doubles',
    relation: 'doubles_champion_women',
    competition: 'Roland-Garros doubles',
    sources: const ['rolandgarros-history', 'wta-tournaments'],
    data: '''
2019 French Open|Babos and Mladenovic|2019
2020 French Open|Babos and Mladenovic|2020
2021 French Open|Krejčíková and Siniaková|2021
2022 French Open|Garcia and Mladenovic|2022
2023 French Open|Hsieh and Wang|2023
2024 French Open|Errani and Paolini|2024
''',
  );
}

void _addDoublesHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'doubles',
    relation: 'record_holder',
    competition: 'Doubles records',
    sources: const ['atp-players', 'wta-players'],
    data: '''
most Grand Slam men's doubles titles|Todd Woodbridge
most Grand Slam women's doubles titles|Martina Navratilova
most ATP doubles titles|Mike Bryan
most weeks at ATP doubles No. 1|Mike Bryan
most Wimbledon men's doubles titles|Todd Woodbridge
most Olympic tennis gold medals|Venus Williams
most Grand Slam mixed doubles titles|Margaret Court
''',
  );
}

void _addDoublesHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'doubles',
    relation: 'doubles_champion_men',
    competition: 'Australian Open doubles',
    sources: const ['ausopen-history', 'atp-tournaments'],
    data: '''
2019 Australian Open|Herbert and Mahut|2019
2020 Australian Open|Ram and Salisbury|2020
2021 Australian Open|Dodig and Polášek|2021
2022 Australian Open|Kokkinakis and Kyrgios|2022
2023 Australian Open|Hijikata and Kubler|2023
2024 Australian Open|Bopanna and Ebden|2024
2025 Australian Open|Bolelli and Vavassori|2025
''',
  );
}

void _addDoublesHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'doubles',
    relation: 'doubles_champion_women',
    competition: 'Australian Open doubles',
    sources: const ['ausopen-history', 'wta-tournaments'],
    data: '''
2019 Australian Open|Stosur and Zhang|2019
2020 Australian Open|Babos and Mladenovic|2020
2021 Australian Open|Mertens and Sabalenka|2021
2022 Australian Open|Krejčíková and Siniaková|2022
2023 Australian Open|Hsieh and Mertens|2023
2024 Australian Open|Hsieh and Mertens|2024
2025 Australian Open|Errani and Paolini|2025
''',
  );
}

void _addDoublesHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'doubles',
    relation: 'doubles_partner',
    competition: 'Doubles partnerships',
    sources: const ['tennis-hall-of-fame', 'atp-players'],
    data: '''
Bob Bryan|Mike Bryan
Gigi Fernández|Natasha Zvereva
Lisa Raymond|Rennae Stubbs
Cara Black|Liezel Huber
Max Mirnyi|Daniel Nestor
Leander Paes|Mahesh Bhupathi
Bob Hewitt|Frew McMillan
''',
  );
}

void _addDoublesHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'doubles',
    relation: 'doubles_champion_mixed',
    competition: 'Grand Slam mixed doubles',
    sources: const ['usopen-history', 'ausopen-history'],
    data: '''
2019 US Open|Mattek-Sands and Murray|2019
2021 US Open|Krawczyk and Salisbury|2021
2022 US Open|Peers and Sanders|2022
2023 US Open|Krajicek and Pegula|2023
2024 US Open|Errani and Vavassori|2024
2019 Australian Open|Krejčíková and Ram|2019
2020 Australian Open|Krejčíková and Mektić|2020
''',
  );
}

void _addDoublesGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'doubles',
    relation: 'doubles_champion_men',
    competition: 'Wimbledon doubles',
    sources: const ['wimbledon-history', 'atp-tournaments'],
    data: '''
2008 Wimbledon|Nestor and Zimonjić|2008
2009 Wimbledon|Nestor and Zimonjić|2009
2010 Wimbledon|Melzer and Petzschner|2010
2011 Wimbledon|Bob and Mike Bryan|2011
2012 Wimbledon|Marray and Nielsen|2012
2013 Wimbledon|Bob and Mike Bryan|2013
2014 Wimbledon|Pospisil and Sock|2014
2015 Wimbledon|Rojer and Tecău|2015
2016 Wimbledon|Herbert and Mahut|2016
2017 Wimbledon|Kubot and Melo|2017
2018 Wimbledon|Bryan and Sock|2018
''',
  );
}

void _addDoublesGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'doubles',
    relation: 'doubles_champion_women',
    competition: 'Wimbledon doubles',
    sources: const ['wimbledon-history', 'wta-tournaments'],
    data: '''
2008 Wimbledon|Venus and Serena Williams|2008
2009 Wimbledon|Venus and Serena Williams|2009
2010 Wimbledon|King and Shvedova|2010
2011 Wimbledon|Peschke and Srebotnik|2011
2012 Wimbledon|Venus and Serena Williams|2012
2013 Wimbledon|Hsieh and Peng|2013
2014 Wimbledon|Errani and Vinci|2014
2015 Wimbledon|Hingis and Mirza|2015
2016 Wimbledon|Venus and Serena Williams|2016
2017 Wimbledon|Makarova and Vesnina|2017
2018 Wimbledon|Krejčíková and Siniaková|2018
''',
  );
}

void _addDoublesGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'doubles',
    relation: 'doubles_champion_men',
    competition: 'Grand Slam doubles',
    sources: const ['rolandgarros-history', 'usopen-history'],
    data: '''
2010 French Open|Nestor and Zimonjić|2010
2011 French Open|Mirnyi and Nestor|2011
2012 French Open|Mirnyi and Nestor|2012
2013 French Open|Bob and Mike Bryan|2013
2014 French Open|Benneteau and Roger-Vasselin|2014
2015 French Open|Dodig and Melo|2015
2016 French Open|Feliciano and Marc López|2016
2017 French Open|Harrison and Venus|2017
2018 French Open|Herbert and Mahut|2018
2010 US Open|Bob and Mike Bryan|2010
2012 US Open|Bob and Mike Bryan|2012
''',
  );
}

void _addDoublesGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'doubles',
    relation: 'doubles_champion_women',
    competition: 'Grand Slam doubles',
    sources: const ['usopen-history', 'rolandgarros-history'],
    data: '''
2010 US Open|King and Shvedova|2010
2011 US Open|Huber and Raymond|2011
2012 US Open|Errani and Vinci|2012
2013 US Open|Hlaváčková and Hradecká|2013
2014 US Open|Makarova and Vesnina|2014
2015 US Open|Hingis and Mirza|2015
2016 US Open|Mattek-Sands and Šafářová|2016
2017 US Open|Chan and Hingis|2017
2018 US Open|Barty and Vandeweghe|2018
2010 French Open|Venus and Serena Williams|2010
2012 French Open|Errani and Vinci|2012
''',
  );
}

void _addDoublesGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'doubles',
    relation: 'doubles_partner',
    competition: 'Doubles partnerships',
    sources: const ['tennis-hall-of-fame', 'wta-players'],
    data: '''
Rosie Casals|Billie Jean King
Betty Stöve|Wendy Turnbull
Helena Suková|Jana Novotná
Kathy Jordan|Anne Smith
Peter McNamara|Paul McNamee
Sania Mirza|Martina Hingis
Nenad Zimonjić|Daniel Nestor
Marcelo Melo|Łukasz Kubot
Horia Tecău|Jean-Julien Rojer
Jack Sock|Mike Bryan
Timea Babos|Kristina Mladenovic
''',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RULES & TERMINOLOGY — 65 facts (easy 35, medium 15, hard 5, global 10).
// Front-loaded into EASY, where recognition of the language of the sport is the
// whole point, and almost absent from HARD, where deep cuts take over.
// ─────────────────────────────────────────────────────────────────────────────

void _addRulesEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
love|a score of zero
deuce|a game score tied at 40-40
ace|a serve the returner cannot touch
fault|a serve that misses the box
let|a serve that clips the net cord
break point|a chance to break the server
tiebreak|a game played to decide a set
''',
  );
}

void _addRulesEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
volley|a shot hit before the bounce
lob|a high shot over the opponent
smash|a hard overhead put-away
drop shot|a soft shot just over the net
slice|a shot hit with backspin
topspin|a shot hit with forward spin
approach shot|a shot hit while moving forward
''',
  );
}

void _addRulesEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
baseline|the back line of the court
service line|the line bounding the service box
tramlines|the doubles side lanes
net cord|the top band of the net
service box|the area a serve must land in
ad court|the receiver's left-hand side
deuce court|the receiver's right-hand side
''',
  );
}

void _addRulesEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'atp-tournaments'],
    data: '''
bagel|a set won six games to none
breadstick|a set won six games to one
golden set|a set won without losing a point
double fault|two missed serves in a row
foot fault|stepping on the line when serving
unforced error|a mistake under no pressure
winner|a shot the opponent cannot reach
''',
  );
}

void _addRulesEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Tournament regulations',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
seed|a ranked player placed in the draw
qualifier|a player who won pre-event rounds
wild card|an entry granted by the organisers
lucky loser|a beaten qualifier given a place
Grand Slam|all four majors won in one year
Career Grand Slam|all four majors won in a career
Golden Slam|all four majors and Olympic gold
''',
  );
}

void _addRulesMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'atp-tournaments'],
    data: '''
how many points win a standard tiebreak|7
how many games win a standard set|6
how many sets win a men's Grand Slam match|3
''',
    extraOptions: const ['2', '10', '4'],
  );
}

void _addRulesMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'wta-tournaments'],
    data: '''
how many sets win a women's Grand Slam match|2
how many points win a Grand Slam final-set tiebreak|10
how many players are on court in a doubles match|4
''',
    extraOptions: const ['6', '7', '3'],
  );
}

void _addRulesMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Court dimensions',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
how tall is the net at the posts in feet|3.5 feet
how tall is the net at the centre in feet|3 feet
how long is a tennis court in feet|78 feet
''',
    extraOptions: const ['27 feet', '36 feet'],
  );
}

void _addRulesMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Court dimensions',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
how wide is a singles court in feet|27 feet
how wide is a doubles court in feet|36 feet
how long is each service box in feet|21 feet
''',
    extraOptions: const ['78 feet', '39 feet'],
  );
}

void _addRulesMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Tournament regulations',
    sources: const ['itf-rules', 'atp-tournaments'],
    data: '''
how many seeds are in a Grand Slam singles draw|32
how many players are in a Grand Slam singles draw|128
how many Grand Slam tournaments are held each year|4
''',
    extraOptions: const ['16', '64', '8'],
  );
}

void _addRulesHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Tournament regulations',
    sources: const ['atp-tournaments', 'itf-rules'],
    data: '''
how many seconds does the ATP shot clock allow|25 seconds
''',
    extraOptions: const ['20 seconds', '30 seconds', '15 seconds'],
  );
}

void _addRulesHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Tournament regulations',
    sources: const ['itf-rules', 'atp-tournaments'],
    data: '''
how many Hawk-Eye challenges does a player get per set|3
''',
    extraOptions: const ['2', '4', '5'],
  );
}

void _addRulesHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Tournament regulations',
    sources: const ['itf-rules', 'wta-tournaments'],
    data: '''
how many minutes long is a Grand Slam medical timeout|3 minutes
''',
    extraOptions: const ['2 minutes', '5 minutes', '10 minutes'],
  );
}

void _addRulesHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'atp-tournaments'],
    data: '''
after how many games is the first ball change made|7 games
''',
    extraOptions: const ['9 games', '6 games', '11 games'],
  );
}

void _addRulesHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'rules_terms',
    relation: 'scoring_rule',
    competition: 'Equipment regulations',
    sources: const ['itf-rules', 'itf-world-tour'],
    data: '''
what is the diameter range of a regulation ball|2.57-2.70 inches
''',
    extraOptions: const [
      '2.00-2.25 inches',
      '3.00-3.25 inches',
      '2.85-3.00 inches',
    ],
  );
}

void _addRulesGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Tour terminology',
    sources: const ['atp-tournaments', 'itf-world-tour'],
    data: '''
Sunshine Double|winning Indian Wells and Miami
Channel Slam|the French Open and Wimbledon
''',
    extraOptions: const [
      'winning all four majors in a year',
      'winning Olympic gold and a major',
    ],
  );
}

void _addRulesGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Rules of Tennis',
    sources: const ['itf-rules', 'atp-tournaments'],
    data: '''
walkover|a win when the opponent withdraws
retirement|quitting an already-started match
''',
    extraOptions: const [
      'a disqualification for misconduct',
      'a match stopped for rain',
    ],
  );
}

void _addRulesGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Tournament formats',
    sources: const ['atp-tournaments', 'itf-rules'],
    data: '''
round robin|a group stage before knockout
best-of-five|a match won by taking three sets
''',
    extraOptions: const [
      'a match won by taking two sets',
      'a single knockout round',
    ],
  );
}

void _addRulesGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Tournament regulations',
    sources: const ['atp-rankings', 'itf-world-tour'],
    data: '''
protected ranking|an entry rank after long injury
special exempt|a place for a late finalist
''',
    extraOptions: const [
      'a rank given to a wild card',
      'a seeding for a former champion',
    ],
  );
}

void _addRulesGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'rules_terms',
    relation: 'definition',
    competition: 'Tour structure',
    sources: const ['itf-world-tour', 'atp-tournaments'],
    data: '''
ITF World Tennis Tour|the entry level below Challengers
ATP Challenger Tour|the tier below the main ATP Tour
''',
    extraOptions: const [
      'the top tier of world tennis',
      'the junior age-group circuit',
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// THE WIDER TENNIS WORLD — 95 facts (easy 10, medium 10, hard 15, global 60).
// Wheelchair tennis, junior slams, the ITF and Challenger tiers, governing
// bodies and tennis geography. Nearly two thirds of it sits in GLOBAL.
// ─────────────────────────────────────────────────────────────────────────────

void _addWorldEasyBand1() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'Wheelchair tennis',
    sources: const ['itf-wheelchair', 'itf-world-tour'],
    data: '''
Diede de Groot|Netherlands
Shingo Kunieda|Japan
''',
    extraOptions: const ['Great Britain', 'United States'],
  );
}

void _addWorldEasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'Wheelchair tennis',
    sources: const ['itf-wheelchair', 'itf-world-tour'],
    data: '''
Alfie Hewett|Great Britain
Gordon Reid|Great Britain
''',
    extraOptions: const ['Netherlands', 'Japan', 'Argentina'],
  );
}

void _addWorldEasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'Wheelchair tennis',
    sources: const ['itf-wheelchair', 'itf-world-tour'],
    data: '''
Yui Kamiji|Japan
Tokito Oda|Japan
''',
    extraOptions: const ['Netherlands', 'Great Britain', 'Belgium'],
  );
}

void _addWorldEasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'Wheelchair tennis',
    sources: const ['itf-wheelchair', 'tennis-hall-of-fame'],
    data: '''
Esther Vergeer|Netherlands
Jiske Griffioen|Netherlands
''',
    extraOptions: const ['Japan', 'Great Britain', 'Australia'],
  );
}

void _addWorldEasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'Wheelchair tennis',
    sources: const ['itf-wheelchair', 'itf-world-tour'],
    data: '''
Gustavo Fernández|Argentina
Dylan Alcott|Australia
''',
    extraOptions: const ['Netherlands', 'Japan', 'Great Britain'],
  );
}

void _addWorldMediumBand1() {
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'world_other',
    relation: 'wheelchair_champion',
    competition: 'Wimbledon wheelchair',
    sources: const ['itf-wheelchair', 'wimbledon-history'],
    data: '''
2023 Wimbledon men's|Tokito Oda|2023
2023 Wimbledon women's|Diede de Groot|2023
''',
    extraOptions: const ['Alfie Hewett', 'Yui Kamiji'],
  );
}

void _addWorldMediumBand2() {
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'world_other',
    relation: 'wheelchair_champion',
    competition: 'Wimbledon wheelchair',
    sources: const ['itf-wheelchair', 'wimbledon-history'],
    data: '''
2024 Wimbledon men's|Alfie Hewett|2024
2024 Wimbledon women's|Yui Kamiji|2024
''',
    extraOptions: const ['Diede de Groot', 'Tokito Oda'],
  );
}

void _addWorldMediumBand3() {
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'world_other',
    relation: 'wheelchair_champion',
    competition: 'Wimbledon wheelchair',
    sources: const ['itf-wheelchair', 'wimbledon-history'],
    data: '''
2022 Wimbledon men's|Shingo Kunieda|2022
2022 Wimbledon women's|Diede de Groot|2022
''',
    extraOptions: const ['Alfie Hewett', 'Yui Kamiji'],
  );
}

void _addWorldMediumBand4() {
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'world_other',
    relation: 'wheelchair_champion',
    competition: 'Wimbledon wheelchair',
    sources: const ['itf-wheelchair', 'wimbledon-history'],
    data: '''
2021 Wimbledon men's|Joachim Gérard|2021
2021 Wimbledon women's|Diede de Groot|2021
''',
    extraOptions: const ['Shingo Kunieda', 'Yui Kamiji'],
  );
}

void _addWorldMediumBand5() {
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'world_other',
    relation: 'wheelchair_champion',
    competition: 'Wimbledon wheelchair',
    sources: const ['itf-wheelchair', 'wimbledon-history'],
    data: '''
2019 Wimbledon men's|Gustavo Fernández|2019
2019 Wimbledon women's|Aniek van Koot|2019
''',
    extraOptions: const ['Diede de Groot', 'Shingo Kunieda'],
  );
}

void _addWorldHardBand1() {
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'world_other',
    relation: 'junior_champion_boys',
    competition: 'Wimbledon juniors',
    sources: const ['wimbledon-history', 'itf-world-tour'],
    data: '''
2021 Wimbledon|Samir Banerjee|2021
2022 Wimbledon|Mili Poljičak|2022
2023 Wimbledon|Henry Searle|2023
''',
    extraOptions: const ['Jakub Menšík'],
  );
}

void _addWorldHardBand2() {
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'world_other',
    relation: 'junior_champion_girls',
    competition: 'Wimbledon juniors',
    sources: const ['wimbledon-history', 'itf-world-tour'],
    data: '''
2021 Wimbledon|Ane Mintegi del Olmo|2021
2022 Wimbledon|Liv Hovde|2022
2023 Wimbledon|Clervie Ngounoue|2023
''',
    extraOptions: const ['Victoria Jiménez Kasintseva'],
  );
}

void _addWorldHardBand3() {
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'world_other',
    relation: 'junior_champion_boys',
    competition: 'Wimbledon juniors',
    sources: const ['wimbledon-history', 'itf-world-tour'],
    data: '''
2017 Wimbledon|Alejandro Davidovich Fokina|2017
2018 Wimbledon|Chun Hsin Tseng|2018
2019 Wimbledon|Shintaro Mochizuki|2019
''',
    extraOptions: const ['Denis Shapovalov'],
  );
}

void _addWorldHardBand4() {
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'world_other',
    relation: 'junior_champion_girls',
    competition: 'Wimbledon juniors',
    sources: const ['wimbledon-history', 'itf-world-tour'],
    data: '''
2017 Wimbledon|Claire Liu|2017
2018 Wimbledon|Iga Świątek|2018
2019 Wimbledon|Daria Snigur|2019
''',
    extraOptions: const ['Coco Gauff'],
  );
}

void _addWorldHardBand5() {
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'world_other',
    relation: 'junior_champion_boys',
    competition: 'Wimbledon juniors',
    sources: const ['wimbledon-history', 'tennis-hall-of-fame'],
    data: '''
2014 Wimbledon|Noah Rubin|2014
2015 Wimbledon|Reilly Opelka|2015
2016 Wimbledon|Denis Shapovalov|2016
''',
    extraOptions: const ['Stefanos Tsitsipas'],
  );
}

void _addWorldGlobalBand1() {
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'World tennis',
    sources: const ['atp-players', 'atp-rankings'],
    data: '''
Nick Kyrgios|Australia
Alex de Minaur|Australia
Cameron Norrie|United Kingdom
Jack Draper|United Kingdom
Sumit Nagal|India
Rohan Bopanna|India
Soonwoo Kwon|South Korea
Duckhee Lee|South Korea
Christian Garín|Chile
Thiago Monteiro|Brazil
João Fonseca|Brazil
Marcos Baghdatis|Cyprus
''',
  );
}

void _addWorldGlobalBand2() {
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'World tennis',
    sources: const ['wta-players', 'wta-rankings'],
    data: '''
Sania Mirza|India
Ankita Raina|India
Emma Raducanu|United Kingdom
Heather Watson|United Kingdom
Priscilla Hon|Australia
Ajla Tomljanović|Australia
Eugenie Bouchard|Canada
Rebecca Marino|Canada
Nuria Párrizas Díaz|Spain
Sara Sorribes Tormo|Spain
Xiyu Wang|China
Yue Yuan|China
''',
  );
}

void _addWorldGlobalBand3() {
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'world_other',
    relation: 'first_year',
    competition: 'Tennis institutions',
    sources: const ['itf-world-tour', 'itf-wheelchair'],
    data: '''
the International Tennis Federation|1913
the ATP|1972
the WTA|1973
the ATP Challenger Tour|1978
the Paralympic tennis event|1992
the Wimbledon wheelchair singles|2016
the Orange Bowl junior event|1947
the Davis Cup Finals format|2019
the US Open wheelchair singles|2005
the Australian Open wheelchair singles|2002
the Roland-Garros wheelchair singles|2007
the ITF World Tennis Tour|2019
''',
  );
}

void _addWorldGlobalBand4() {
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'world_other',
    relation: 'record_holder',
    competition: 'World tennis firsts',
    sources: const ['itf-wheelchair', 'tennis-hall-of-fame'],
    data: '''
most wheelchair Grand Slam singles titles|Esther Vergeer
most men's wheelchair slam singles titles|Shingo Kunieda
most Paralympic singles gold medals|Esther Vergeer
the first Asian man to reach a slam final|Kei Nishikori
the first Chinese player to win a major|Li Na
the first African woman to reach a slam final|Ons Jabeur
the first Black man to win Wimbledon|Arthur Ashe
the first Black woman to win a major|Althea Gibson
the first Indian to reach No. 1 in doubles|Leander Paes
the first Russian man to win a major|Yevgeny Kafelnikov
the first Croatian man to win Wimbledon|Goran Ivanišević
the first Serbian man to win a major|Novak Djokovic
''',
  );
}

void _addWorldGlobalBand5() {
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'world_other',
    relation: 'player_nationality',
    competition: 'World tennis',
    sources: const ['atp-players', 'tennis-hall-of-fame'],
    data: '''
Younes El Aynaoui|Morocco
Hicham Arazi|Morocco
Malek Jaziri|Tunisia
Kevin Anderson|South Africa
Lloyd Harris|South Africa
Ivo Karlović|Croatia
Michael Llodra|France
Guillermo Coria|Argentina
Juan Mónaco|Argentina
Paolo Lorenzi|Italy
Andreas Seppi|Italy
Tommy Robredo|Spain
''',
  );
}
