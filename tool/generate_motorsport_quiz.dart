// Generates the authored Motorsport Quiz assets and their development-only
// audit ledger. Run from the repository root with the bundled Dart SDK:
//
//   .\flutter\bin\cache\dart-sdk\bin\dart.exe tool\generate_motorsport_quiz.dart
//
// Runtime assets keep the compact p/o/a schema used by every Knowledge Arena
// sport. Audit metadata is deliberately kept out of the app bundle.
//
// Unlike the cricket and basketball generators, this bank does NOT pad short
// pools by re-wording a seed fact into several prompts. Every one of the 2,000
// questions is its own distinct, recorded motorsport fact. There is no variant
// path to fall back into: a short pool is a hard failure.
import 'dart:convert';
import 'dart:io';

const _modes = ['easy', 'medium', 'hard', 'global'];
const _scopes = [
  'f1',
  'motogp',
  'nascar',
  'indycar',
  'endurance',
  'rally',
  'feeder_other',
];
const _cutoff = '2026-08-19';

const _sourceRegistry = <String, Map<String, String>>{
  'f1-results-archive': {
    'kind': 'primary',
    'title': 'Formula 1 official results archive',
    'url': 'https://www.formula1.com/en/results.html',
  },
  'f1-drivers-hall': {
    'kind': 'primary',
    'title': 'Formula 1 official drivers and teams archive',
    'url': 'https://www.formula1.com/en/drivers.html',
  },
  'fia-regulations': {
    'kind': 'primary',
    'title': 'FIA Formula One sporting and technical regulations',
    'url': 'https://www.fia.com/regulation/category/110',
  },
  'fia-championship-records': {
    'kind': 'primary',
    'title': 'FIA world championship results and records',
    'url': 'https://www.fia.com/events/fia-formula-one-world-championship',
  },
  'motogp-results': {
    'kind': 'primary',
    'title': 'MotoGP official results and championship archive',
    'url': 'https://www.motogp.com/en/gp-results',
  },
  'motogp-history': {
    'kind': 'primary',
    'title': 'MotoGP official history and champions archive',
    'url': 'https://www.motogp.com/en/world-championship/history',
  },
  'nascar-results': {
    'kind': 'primary',
    'title': 'NASCAR official race results and standings',
    'url': 'https://www.nascar.com/results/',
  },
  'nascar-history': {
    'kind': 'primary',
    'title': 'NASCAR official history and champions archive',
    'url': 'https://www.nascar.com/nascar-hall-of-fame/',
  },
  'indycar-results': {
    'kind': 'primary',
    'title': 'INDYCAR official results and standings',
    'url': 'https://www.indycar.com/Stats',
  },
  'indy500-history': {
    'kind': 'primary',
    'title': 'Indianapolis Motor Speedway Indy 500 winners archive',
    'url': 'https://www.indianapolismotorspeedway.com/events/indy500/history',
  },
  'fiawec-results': {
    'kind': 'primary',
    'title': 'FIA World Endurance Championship official results',
    'url': 'https://www.fiawec.com/en/results',
  },
  'lemans-history': {
    'kind': 'primary',
    'title': 'Automobile Club de l\'Ouest 24 Hours of Le Mans archive',
    'url': 'https://www.24h-lemans.com/en/history',
  },
  'imsa-results': {
    'kind': 'primary',
    'title': 'IMSA official results and championship archive',
    'url': 'https://www.imsa.com/schedule-results/',
  },
  'wrc-results': {
    'kind': 'primary',
    'title': 'FIA World Rally Championship official results',
    'url': 'https://www.wrc.com/en/results/',
  },
  'dakar-history': {
    'kind': 'primary',
    'title': 'Dakar Rally official winners archive',
    'url': 'https://www.dakar.com/en/history',
  },
  'formulae-results': {
    'kind': 'primary',
    'title': 'ABB FIA Formula E World Championship official results',
    'url': 'https://www.fiaformulae.com/en/results',
  },
  'formula2-results': {
    'kind': 'primary',
    'title': 'FIA Formula 2 Championship official results',
    'url': 'https://www.fiaformula2.com/Results',
  },
  'formula3-results': {
    'kind': 'primary',
    'title': 'FIA Formula 3 Championship official results',
    'url': 'https://www.fiaformula3.com/Results',
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
/// these, so `f1` easy is 300 of the mode's 500 questions.
///
/// F1 leads the ladder at ~49% of the whole bank, but steps back sharply in
/// GLOBAL where endurance, rally and MotoGP take over — that is what makes the
/// world capstone feel like a different category rather than "hard mode again".
Map<String, int> _scopeCounts(String mode) => switch (mode) {
  'easy' => {
    'f1': 60,
    'motogp': 11,
    'nascar': 10,
    'indycar': 8,
    'endurance': 6,
    'rally': 3,
    'feeder_other': 2,
  },
  'medium' => {
    'f1': 57,
    'motogp': 11,
    'nascar': 10,
    'indycar': 9,
    'endurance': 8,
    'rally': 3,
    'feeder_other': 2,
  },
  'hard' => {
    'f1': 53,
    'motogp': 11,
    'nascar': 10,
    'indycar': 9,
    'endurance': 9,
    'rally': 5,
    'feeder_other': 3,
  },
  'global' => {
    'f1': 27,
    'motogp': 16,
    'nascar': 9,
    'indycar': 10,
    'endurance': 17,
    'rally': 12,
    'feeder_other': 9,
  },
  _ => throw ArgumentError.value(mode),
};

void main(List<String> args) {
  final reportOnly = args.contains('--report');
  _addF1Facts();
  _addMotoGpFacts();
  _addNascarFacts();
  _addIndyCarFacts();
  _addEnduranceFacts();
  _addRallyFacts();
  _addFeederFacts();
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
              'motorsport_${mode}_q${questionNumber.toString().padLeft(3, '0')}';
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
    _writeJson('assets/quiz/motorsport_$mode.json', {
      'sport': 'motorsport',
      'mode': mode,
      'version': 1,
      'bands': bands,
    });
  }

  _writeJson('tool/quiz_audit/motorsport.json', {
    'sport': 'motorsport',
    'version': 1,
    'factualCutoff': _cutoff,
    'sources': _sourceRegistry,
    'questions': auditQuestions,
  });
  stdout.writeln(
    'Generated ${auditQuestions.length} motorsport questions and audit entries.',
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
/// in the same table, which is what keeps every option plausible.
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
String _prompt(_Fact fact) {
  final subject = fact.subject;
  return switch (fact.relation) {
    'definition' => 'In motorsport, what does “$subject” mean?',
    'flag_meaning' => 'In motor racing, what does the $subject signal?',
    'champion_driver' => 'Who won the $subject drivers\u2019 title?',
    'champion_rider' => 'Who won the $subject riders\u2019 title?',
    'champion_team' => 'Which team won the $subject constructors\u2019 title?',
    'champion_manufacturer' =>
      'Which manufacturer won the $subject constructors\u2019 title?',
    'premier_title_count' =>
      'How many premier-class motorcycle titles did $subject win?',
    'race_winner' => 'Who won the $subject?',
    'race_winning_team' => 'Which team won the $subject?',
    'circuit_country' => 'Which country hosts $subject?',
    'circuit_city' => 'Which city or region is home to $subject?',
    'venue' => 'Which circuit hosts $subject?',
    'driver_team' => '$subject drove for which team?',
    'rider_manufacturer' => '$subject rode for which manufacturer?',
    'driver_manufacturer' =>
      '$subject raced for which manufacturer?',
    'driver_nationality' => 'Which country did $subject represent?',
    'engine_supplier' => '$subject used which engine supplier?',
    'team_base' => 'In which country is $subject based?',
    'record_holder' => 'Who holds the record for $subject?',
    'title_count' => 'How many world titles did $subject win?',
    'first_year' => 'In which year did $subject first take place?',
    'series_home' => 'Which country is the traditional home of $subject?',
    'car_number' => 'Which car number is most associated with $subject?',
    'tyre_supplier' => 'Which tyre supplier serves $subject?',
    'class_name' => 'Which racing category does $subject belong to?',
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
// FORMULA 1 — 985 facts (easy 300, medium 285, hard 265, global 135)
//
// Band 1 sits in the 2020s and works backwards: band 2 the 2010s, band 3 the
// 2000s, band 4 the 1980s-90s, band 5 the 1950s-70s. Chronology is the honest
// difficulty axis in motorsport — recognition falls off sharply with era.
// ─────────────────────────────────────────────────────────────────────────────

void _addF1Facts() {
  _addF1Easy();
  _addF1EasyBand2();
  _addF1EasyBand3();
  _addF1EasyBand4();
  _addF1EasyBand5();
  _addF1Medium();
  _addF1Hard();
  _addF1Global();
}

void _addF1Easy() {
  // ── band 1: terminology, flags, 2020s grid ────────────────────────────────
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'f1',
    relation: 'definition',
    competition: 'Formula 1',
    sources: const ['fia-regulations', 'f1-results-archive'],
    data: '''
pole position|fastest qualifying lap
DRS|a drag reduction rear wing flap
pit stop|a service stop in the pit lane
formation lap|the lap before a standing start
safety car|a car that neutralises the race
grid|the starting order on track
podium|the top three finishers
chicane|a tight sequence of corners
apex|the inner point of a corner
slipstream|a tow in the car ahead's wake
undercut|pitting early to gain position
overcut|staying out to gain position
parc fermé|restricted car storage rules
stewards|officials who judge incidents
paddock|the team compound behind pits
telemetry|live data sent from the car
downforce|aerodynamic load pushing down
marbles|discarded rubber off the line
lock-up|a wheel sliding under braking
gravel trap|a run-off area of loose stones
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'f1',
    relation: 'flag_meaning',
    competition: 'Formula 1',
    sources: const ['fia-regulations', 'f1-results-archive'],
    data: '''
yellow flag|danger ahead, do not overtake
red flag|the session has been stopped
chequered flag|the end of the session
blue flag|let a faster car through
black flag|the driver is disqualified
white flag|a slow vehicle is on track
green flag|the track is clear again
black and orange flag|a car has a mechanical fault
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'f1',
    relation: 'driver_nationality',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
Max Verstappen|Netherlands
Lewis Hamilton|United Kingdom
Charles Leclerc|Monaco
Lando Norris|United Kingdom
Carlos Sainz|Spain
George Russell|United Kingdom
Sergio Pérez|Mexico
Fernando Alonso|Spain
Oscar Piastri|Australia
Pierre Gasly|France
Esteban Ocon|France
Lance Stroll|Canada
Yuki Tsunoda|Japan
Valtteri Bottas|Finland
Kevin Magnussen|Denmark
Nico Hülkenberg|Germany
Alexander Albon|Thailand
Zhou Guanyu|China
Daniel Ricciardo|Australia
Sebastian Vettel|Germany
''',
  );
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'f1',
    relation: 'team_base',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
Scuderia Ferrari|Italy
McLaren|United Kingdom
Mercedes|United Kingdom
Red Bull Racing|United Kingdom
Williams|United Kingdom
Aston Martin|United Kingdom
Alpine|France
Haas|United States
Sauber|Switzerland
AlphaTauri|Italy
Toro Rosso|Italy
Minardi|Italy
''',
  );
}

void _addF1EasyBand2() {
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'f1',
    relation: 'driver_nationality',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
Jenson Button|United Kingdom
Nico Rosberg|Germany
Kimi Räikkönen|Finland
Felipe Massa|Brazil
Mark Webber|Australia
Romain Grosjean|France
Jean-Éric Vergne|France
Paul di Resta|United Kingdom
Adrian Sutil|Germany
Jules Bianchi|France
Pastor Maldonado|Venezuela
Bruno Senna|Brazil
Heikki Kovalainen|Finland
Vitaly Petrov|Russia
Kamui Kobayashi|Japan
Timo Glock|Germany
Robert Kubica|Poland
Sébastien Buemi|Switzerland
Jaime Alguersuari|Spain
Marcus Ericsson|Sweden
Felipe Nasr|Brazil
Pascal Wehrlein|Germany
Esteban Gutiérrez|Mexico
Stoffel Vandoorne|Belgium
Brendon Hartley|New Zealand
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'f1',
    relation: 'circuit_country',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
Silverstone Circuit|United Kingdom
Circuit de Monaco|Monaco
Autodromo Nazionale Monza|Italy
Circuit de Spa-Francorchamps|Belgium
Suzuka Circuit|Japan
Circuit Gilles Villeneuve|Canada
the Hungaroring|Hungary
the Red Bull Ring|Austria
Circuit de Barcelona-Catalunya|Spain
Marina Bay Street Circuit|Singapore
Yas Marina Circuit|United Arab Emirates
Bahrain International Circuit|Bahrain
Interlagos|Brazil
Circuit of the Americas|United States
Sochi Autodrom|Russia
Baku City Circuit|Azerbaijan
Shanghai International Circuit|China
Circuit Zandvoort|Netherlands
Imola|Italy
Circuit Paul Ricard|France
the Nürburgring|Germany
the Hockenheimring|Germany
Istanbul Park|Türkiye
Sepang International Circuit|Malaysia
Losail International Circuit|Qatar
''',
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'f1',
    relation: 'champion_driver',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
2010 Formula 1|Sebastian Vettel|2010
2011 Formula 1|Sebastian Vettel|2011
2012 Formula 1|Sebastian Vettel|2012
2013 Formula 1|Sebastian Vettel|2013
2014 Formula 1|Lewis Hamilton|2014
2015 Formula 1|Lewis Hamilton|2015
2016 Formula 1|Nico Rosberg|2016
2017 Formula 1|Lewis Hamilton|2017
2018 Formula 1|Lewis Hamilton|2018
2019 Formula 1|Lewis Hamilton|2019
''',
    extraOptions: const ['Fernando Alonso', 'Max Verstappen', 'Kimi Räikkönen'],
  );
}

void _addF1EasyBand3() {
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'f1',
    relation: 'champion_driver',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
2000 Formula 1|Michael Schumacher|2000
2001 Formula 1|Michael Schumacher|2001
2002 Formula 1|Michael Schumacher|2002
2003 Formula 1|Michael Schumacher|2003
2004 Formula 1|Michael Schumacher|2004
2005 Formula 1|Fernando Alonso|2005
2006 Formula 1|Fernando Alonso|2006
2007 Formula 1|Kimi Räikkönen|2007
2008 Formula 1|Lewis Hamilton|2008
2009 Formula 1|Jenson Button|2009
''',
    extraOptions: const ['David Coulthard', 'Juan Pablo Montoya', 'Felipe Massa'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'f1',
    relation: 'driver_nationality',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
David Coulthard|United Kingdom
Ralf Schumacher|Germany
Juan Pablo Montoya|Colombia
Giancarlo Fisichella|Italy
Jacques Villeneuve|Canada
Eddie Irvine|United Kingdom
Mika Häkkinen|Finland
Olivier Panis|France
Jos Verstappen|Netherlands
Pedro de la Rosa|Spain
Takuma Sato|Japan
Christian Klien|Austria
Anthony Davidson|United Kingdom
Scott Speed|United States
Robert Doornbos|Netherlands
Tiago Monteiro|Portugal
Christijan Albers|Netherlands
Alexander Wurz|Austria
Ricardo Zonta|Brazil
Cristiano da Matta|Brazil
''',
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'f1',
    relation: 'circuit_country',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
Indianapolis Motor Speedway|United States
Circuit de Nevers Magny-Cours|France
Autódromo do Estoril|Portugal
the A1-Ring|Austria
Circuit Ricardo Tormo|Spain
Fuji Speedway|Japan
the Adelaide Street Circuit|Australia
Kyalami|South Africa
Buddh International Circuit|India
Korea International Circuit|South Korea
the Valencia Street Circuit|Spain
Circuito de Jerez|Spain
Autódromo do Algarve|Portugal
Mugello Circuit|Italy
Circuit Zolder|Belgium
Donington Park|United Kingdom
Brands Hatch|United Kingdom
Autódromo Óscar Gálvez|Argentina
the Las Vegas Strip Circuit|United States
Miami International Autodrome|United States
''',
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'f1',
    relation: 'venue',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
the Italian Grand Prix|Monza
the British Grand Prix|Silverstone
the Belgian Grand Prix|Spa-Francorchamps
the Japanese Grand Prix|Suzuka
the Hungarian Grand Prix|the Hungaroring
the Austrian Grand Prix|the Red Bull Ring
the Canadian Grand Prix|Circuit Gilles Villeneuve
the Singapore Grand Prix|Marina Bay Street Circuit
the Mexico City Grand Prix|Autódromo Hermanos Rodríguez
the Brazilian Grand Prix|Interlagos
''',
  );
}

void _addF1EasyBand4() {
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'f1',
    relation: 'champion_driver',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
1980 Formula 1|Alan Jones|1980
1981 Formula 1|Nelson Piquet|1981
1982 Formula 1|Keke Rosberg|1982
1983 Formula 1|Nelson Piquet|1983
1984 Formula 1|Niki Lauda|1984
1985 Formula 1|Alain Prost|1985
1986 Formula 1|Alain Prost|1986
1987 Formula 1|Nelson Piquet|1987
1988 Formula 1|Ayrton Senna|1988
1989 Formula 1|Alain Prost|1989
1990 Formula 1|Ayrton Senna|1990
1991 Formula 1|Ayrton Senna|1991
1992 Formula 1|Nigel Mansell|1992
1993 Formula 1|Alain Prost|1993
1994 Formula 1|Michael Schumacher|1994
1995 Formula 1|Michael Schumacher|1995
1996 Formula 1|Damon Hill|1996
1997 Formula 1|Jacques Villeneuve|1997
1998 Formula 1|Mika Häkkinen|1998
1999 Formula 1|Mika Häkkinen|1999
''',
    extraOptions: const ['Gerhard Berger', 'Riccardo Patrese', 'Jean Alesi'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'f1',
    relation: 'driver_nationality',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
Ayrton Senna|Brazil
Alain Prost|France
Nigel Mansell|United Kingdom
Nelson Piquet|Brazil
Niki Lauda|Austria
Keke Rosberg|Finland
Alan Jones|Australia
Damon Hill|United Kingdom
Gerhard Berger|Austria
Riccardo Patrese|Italy
Jean Alesi|France
Martin Brundle|United Kingdom
Johnny Herbert|United Kingdom
Heinz-Harald Frentzen|Germany
Ukyo Katayama|Japan
Aguri Suzuki|Japan
Eddie Cheever|United States
Michele Alboreto|Italy
Elio de Angelis|Italy
Stefan Johansson|Sweden
Thierry Boutsen|Belgium
JJ Lehto|Finland
Andrea de Cesaris|Italy
Satoru Nakajima|Japan
Pedro Lamy|Portugal
''',
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'f1',
    relation: 'circuit_country',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
the Österreichring|Austria
Circuit de Dijon-Prenois|France
Circuito del Jarama|Spain
Autódromo de Jacarepaguá|Brazil
the Long Beach street circuit|United States
Watkins Glen International|United States
Circuit de Charade|France
Anderstorp Raceway|Sweden
Circuit Mont-Tremblant|Canada
Nivelles-Baulers|Belgium
the Montjuïc circuit|Spain
the Pescara Circuit|Italy
Reims-Gueux|France
AVUS|Germany
the TI Circuit at Aida|Japan
''',
  );
}

void _addF1EasyBand5() {
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'f1',
    relation: 'champion_driver',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
1950 Formula 1|Nino Farina|1950
1951 Formula 1|Juan Manuel Fangio|1951
1952 Formula 1|Alberto Ascari|1952
1953 Formula 1|Alberto Ascari|1953
1954 Formula 1|Juan Manuel Fangio|1954
1955 Formula 1|Juan Manuel Fangio|1955
1956 Formula 1|Juan Manuel Fangio|1956
1957 Formula 1|Juan Manuel Fangio|1957
1958 Formula 1|Mike Hawthorn|1958
1959 Formula 1|Jack Brabham|1959
1960 Formula 1|Jack Brabham|1960
1961 Formula 1|Phil Hill|1961
1962 Formula 1|Graham Hill|1962
1963 Formula 1|Jim Clark|1963
1964 Formula 1|John Surtees|1964
1965 Formula 1|Jim Clark|1965
1966 Formula 1|Jack Brabham|1966
1967 Formula 1|Denny Hulme|1967
1968 Formula 1|Graham Hill|1968
1969 Formula 1|Jackie Stewart|1969
1970 Formula 1|Jochen Rindt|1970
1971 Formula 1|Jackie Stewart|1971
1972 Formula 1|Emerson Fittipaldi|1972
1973 Formula 1|Jackie Stewart|1973
1974 Formula 1|Emerson Fittipaldi|1974
1975 Formula 1|Niki Lauda|1975
1976 Formula 1|James Hunt|1976
1977 Formula 1|Niki Lauda|1977
1978 Formula 1|Mario Andretti|1978
1979 Formula 1|Jody Scheckter|1979
''',
    extraOptions: const ['Stirling Moss', 'Ronnie Peterson', 'Chris Amon'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'f1',
    relation: 'driver_nationality',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
Juan Manuel Fangio|Argentina
Alberto Ascari|Italy
Nino Farina|Italy
Stirling Moss|United Kingdom
Jim Clark|United Kingdom
Graham Hill|United Kingdom
Jackie Stewart|United Kingdom
Jack Brabham|Australia
Denny Hulme|New Zealand
Bruce McLaren|New Zealand
Phil Hill|United States
Dan Gurney|United States
Mario Andretti|United States
Emerson Fittipaldi|Brazil
Jochen Rindt|Austria
Ronnie Peterson|Sweden
Jody Scheckter|South Africa
James Hunt|United Kingdom
Carlos Reutemann|Argentina
Clay Regazzoni|Switzerland
Jo Siffert|Switzerland
Mike Hawthorn|United Kingdom
John Surtees|United Kingdom
Wolfgang von Trips|Germany
Jean Behra|France
Maurice Trintignant|France
Luigi Musso|Italy
Chris Amon|New Zealand
Pedro Rodríguez|Mexico
Jacky Ickx|Belgium
''',
  );
}




















void _addF1Medium() {
  // ── band 1: 2020s teams, engines and line-ups ─────────────────────────────
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'f1',
    relation: 'champion_team',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
2015 Formula 1|Mercedes|2015
2016 Formula 1|Mercedes|2016
2017 Formula 1|Mercedes|2017
2018 Formula 1|Mercedes|2018
2019 Formula 1|Mercedes|2019
2020 Formula 1|Mercedes|2020
2021 Formula 1|Mercedes|2021
2022 Formula 1|Red Bull Racing|2022
2023 Formula 1|Red Bull Racing|2023
2024 Formula 1|McLaren|2024
2025 Formula 1|McLaren|2025
''',
    extraOptions: const ['Ferrari', 'Aston Martin', 'Alpine'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'f1',
    relation: 'engine_supplier',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-regulations'],
    data: '''
Red Bull Racing in 2021|Honda
McLaren in 2021|Mercedes
Aston Martin in 2021|Mercedes
Williams in 2021|Mercedes
Alpine in 2021|Renault
AlphaTauri in 2021|Honda
Haas in 2021|Ferrari
Alfa Romeo in 2021|Ferrari
McLaren in 2019|Renault
Red Bull Racing in 2018|TAG Heuer
Racing Point in 2020|Mercedes
Red Bull Racing in 2023|Honda RBPT
McLaren in 2024|Mercedes
Sauber in 2024|Ferrari
Williams in 2024|Mercedes
RB in 2024|Honda RBPT
''',
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'f1',
    relation: 'driver_team',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'f1-results-archive'],
    data: '''
Max Verstappen in 2021|Red Bull Racing
Lewis Hamilton in 2021|Mercedes
Valtteri Bottas in 2021|Mercedes
Sergio Pérez in 2021|Red Bull Racing
Charles Leclerc in 2021|Ferrari
Carlos Sainz in 2021|Ferrari
Lando Norris in 2021|McLaren
Daniel Ricciardo in 2021|McLaren
Pierre Gasly in 2021|AlphaTauri
Yuki Tsunoda in 2021|AlphaTauri
Fernando Alonso in 2021|Alpine
Esteban Ocon in 2021|Alpine
Sebastian Vettel in 2021|Aston Martin
Lance Stroll in 2021|Aston Martin
George Russell in 2021|Williams
Nicholas Latifi in 2021|Williams
Kimi Räikkönen in 2021|Alfa Romeo
Antonio Giovinazzi in 2021|Alfa Romeo
Mick Schumacher in 2021|Haas
Nikita Mazepin in 2021|Haas
Oscar Piastri in 2023|McLaren
Nico Hülkenberg in 2023|Haas
Alexander Albon in 2023|Williams
Logan Sargeant in 2023|Williams
Zhou Guanyu in 2023|Alfa Romeo
Lewis Hamilton in 2025|Ferrari
Carlos Sainz in 2025|Williams
Isack Hadjar in 2025|Racing Bulls
Oliver Bearman in 2025|Haas
Kimi Antonelli in 2025|Mercedes
''',
  );

  // ── band 2: 2010s ─────────────────────────────────────────────────────────
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'f1',
    relation: 'champion_team',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
2005 Formula 1|Renault|2005
2006 Formula 1|Renault|2006
2007 Formula 1|Ferrari|2007
2008 Formula 1|Ferrari|2008
2009 Formula 1|Brawn GP|2009
2010 Formula 1|Red Bull Racing|2010
2011 Formula 1|Red Bull Racing|2011
2012 Formula 1|Red Bull Racing|2012
2013 Formula 1|Red Bull Racing|2013
2014 Formula 1|Mercedes|2014
''',
    extraOptions: const ['McLaren', 'Williams', 'Lotus'],
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'f1',
    relation: 'driver_team',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'f1-results-archive'],
    data: '''
Jenson Button in 2012|McLaren
Lewis Hamilton in 2012|McLaren
Fernando Alonso in 2012|Ferrari
Felipe Massa in 2012|Ferrari
Sebastian Vettel in 2012|Red Bull Racing
Mark Webber in 2012|Red Bull Racing
Nico Rosberg in 2012|Mercedes
Michael Schumacher in 2012|Mercedes
Kimi Räikkönen in 2012|Lotus
Romain Grosjean in 2012|Lotus
Paul di Resta in 2012|Force India
Nico Hülkenberg in 2012|Force India
Kamui Kobayashi in 2012|Sauber
Sergio Pérez in 2012|Sauber
Daniel Ricciardo in 2012|Toro Rosso
Jean-Éric Vergne in 2012|Toro Rosso
Pastor Maldonado in 2012|Williams
Bruno Senna in 2012|Williams
Heikki Kovalainen in 2012|Caterham
Vitaly Petrov in 2012|Caterham
Timo Glock in 2012|Marussia
Charles Pic in 2012|Marussia
Sebastian Vettel in 2015|Ferrari
Daniil Kvyat in 2015|Red Bull Racing
Max Verstappen in 2015|Toro Rosso
Carlos Sainz in 2015|Toro Rosso
Felipe Nasr in 2015|Sauber
Marcus Ericsson in 2015|Sauber
Fernando Alonso in 2015|McLaren
Jenson Button in 2015|McLaren
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'f1',
    relation: 'engine_supplier',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-regulations'],
    data: '''
Red Bull Racing in 2012|Renault
McLaren in 2012|Mercedes
Lotus in 2012|Renault
Sauber in 2012|Ferrari
Force India in 2012|Mercedes
Williams in 2012|Renault
Toro Rosso in 2012|Ferrari
Caterham in 2012|Renault
Marussia in 2012|Cosworth
HRT in 2012|Cosworth
McLaren in 2015|Honda
Manor in 2015|Ferrari
Red Bull Racing in 2016|TAG Heuer
Toro Rosso in 2016|Ferrari
Williams in 2016|Mercedes
Renault in 2016|Renault
Haas in 2016|Ferrari
''',
  );

  // ── band 3: 2000s ─────────────────────────────────────────────────────────
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'f1',
    relation: 'champion_team',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
1995 Formula 1|Benetton|1995
1996 Formula 1|Williams|1996
1997 Formula 1|Williams|1997
1998 Formula 1|McLaren|1998
1999 Formula 1|Ferrari|1999
2000 Formula 1|Ferrari|2000
2001 Formula 1|Ferrari|2001
2002 Formula 1|Ferrari|2002
2003 Formula 1|Ferrari|2003
2004 Formula 1|Ferrari|2004
''',
    extraOptions: const ['Jordan', 'BAR', 'Renault'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'f1',
    relation: 'driver_team',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'f1-results-archive'],
    data: '''
Michael Schumacher in 2002|Ferrari
Rubens Barrichello in 2002|Ferrari
David Coulthard in 2002|McLaren
Kimi Räikkönen in 2002|McLaren
Ralf Schumacher in 2002|Williams
Juan Pablo Montoya in 2002|Williams
Jenson Button in 2002|Renault
Jarno Trulli in 2002|Renault
Giancarlo Fisichella in 2002|Jordan
Takuma Sato in 2002|Jordan
Nick Heidfeld in 2002|Sauber
Felipe Massa in 2002|Sauber
Jacques Villeneuve in 2002|BAR
Olivier Panis in 2002|BAR
Eddie Irvine in 2002|Jaguar
Pedro de la Rosa in 2002|Jaguar
Mika Salo in 2002|Toyota
Allan McNish in 2002|Toyota
Mark Webber in 2002|Minardi
Alex Yoong in 2002|Minardi
Fernando Alonso in 2006|Renault
Giancarlo Fisichella in 2006|Renault
Lewis Hamilton in 2007|McLaren
Heikki Kovalainen in 2008|McLaren
Robert Kubica in 2008|BMW Sauber
Nick Heidfeld in 2008|BMW Sauber
Jenson Button in 2009|Brawn GP
Rubens Barrichello in 2009|Brawn GP
Sebastian Vettel in 2009|Red Bull Racing
Mark Webber in 2009|Red Bull Racing
''',
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'f1',
    relation: 'engine_supplier',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-regulations'],
    data: '''
Williams in 2002|BMW
McLaren in 2002|Mercedes
Renault in 2002|Renault
Jordan in 2002|Honda
Sauber in 2002|Petronas
BAR in 2002|Honda
Jaguar in 2002|Cosworth
Minardi in 2002|Asiatech
Arrows in 2002|Cosworth
Toyota in 2002|Toyota
Ferrari in 2002|Ferrari
Red Bull Racing in 2006|Ferrari
Toro Rosso in 2007|Ferrari
Super Aguri in 2007|Honda
Force India in 2009|Mercedes
Brawn GP in 2009|Mercedes
Williams in 2009|Toyota
''',
  );

  // ── band 4: 1980s-90s ─────────────────────────────────────────────────────
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'f1',
    relation: 'champion_team',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
1980 Formula 1|Williams|1980
1981 Formula 1|Williams|1981
1982 Formula 1|Ferrari|1982
1983 Formula 1|Ferrari|1983
1984 Formula 1|McLaren|1984
1985 Formula 1|McLaren|1985
1986 Formula 1|Williams|1986
1987 Formula 1|Williams|1987
1988 Formula 1|McLaren|1988
1989 Formula 1|McLaren|1989
1990 Formula 1|McLaren|1990
1991 Formula 1|McLaren|1991
1992 Formula 1|Williams|1992
1993 Formula 1|Williams|1993
1994 Formula 1|Williams|1994
''',
    extraOptions: const ['Team Lotus', 'Brabham', 'Benetton'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'f1',
    relation: 'driver_team',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'f1-results-archive'],
    data: '''
Ayrton Senna in 1988|McLaren
Alain Prost in 1988|McLaren
Nigel Mansell in 1992|Williams
Riccardo Patrese in 1992|Williams
Michael Schumacher in 1994|Benetton
Damon Hill in 1994|Williams
Gerhard Berger in 1994|Ferrari
Jean Alesi in 1994|Ferrari
Mika Häkkinen in 1994|McLaren
Martin Brundle in 1994|McLaren
Rubens Barrichello in 1994|Jordan
Eddie Irvine in 1994|Jordan
Johnny Herbert in 1995|Benetton
David Coulthard in 1995|Williams
Jacques Villeneuve in 1996|Williams
Heinz-Harald Frentzen in 1997|Williams
Ralf Schumacher in 1997|Jordan
Giancarlo Fisichella in 1997|Jordan
Jarno Trulli in 1998|Prost
Olivier Panis in 1998|Prost
Nelson Piquet in 1987|Williams
Niki Lauda in 1984|McLaren
Keke Rosberg in 1982|Williams
Elio de Angelis in 1985|Team Lotus
Michele Alboreto in 1985|Ferrari
Stefan Johansson in 1985|Ferrari
Thierry Boutsen in 1990|Williams
''',
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'f1',
    relation: 'engine_supplier',
    competition: 'Formula 1',
    sources: const ['f1-results-archive', 'fia-regulations'],
    data: '''
McLaren in 1988|Honda
Williams in 1988|Judd
Ferrari in 1988|Ferrari
Benetton in 1988|Ford
Team Lotus in 1988|Honda
Williams in 1992|Renault
McLaren in 1992|Honda
Benetton in 1994|Ford
Williams in 1994|Renault
McLaren in 1995|Mercedes
Jordan in 1995|Peugeot
Ferrari in 1995|Ferrari
Sauber in 1995|Ford
Arrows in 1997|Yamaha
Stewart in 1997|Ford
''',
  );

  // ── band 5: 1950s-70s ─────────────────────────────────────────────────────
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'f1',
    relation: 'champion_team',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
1958 Formula 1|Vanwall|1958
1959 Formula 1|Cooper|1959
1960 Formula 1|Cooper|1960
1961 Formula 1|Ferrari|1961
1962 Formula 1|BRM|1962
1963 Formula 1|Team Lotus|1963
1964 Formula 1|Ferrari|1964
1965 Formula 1|Team Lotus|1965
1966 Formula 1|Brabham|1966
1967 Formula 1|Brabham|1967
1968 Formula 1|Team Lotus|1968
1969 Formula 1|Matra|1969
1970 Formula 1|Team Lotus|1970
1971 Formula 1|Tyrrell|1971
1972 Formula 1|Team Lotus|1972
1973 Formula 1|Team Lotus|1973
1974 Formula 1|McLaren|1974
1975 Formula 1|Ferrari|1975
1976 Formula 1|Ferrari|1976
1977 Formula 1|Ferrari|1977
1978 Formula 1|Team Lotus|1978
1979 Formula 1|Ferrari|1979
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'f1',
    relation: 'driver_team',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'f1-results-archive'],
    data: '''
Juan Manuel Fangio in 1957|Maserati
Juan Manuel Fangio in 1954|Mercedes
Alberto Ascari in 1952|Ferrari
Stirling Moss in 1955|Mercedes
Mike Hawthorn in 1958|Ferrari
Jack Brabham in 1959|Cooper
Phil Hill in 1961|Ferrari
Graham Hill in 1962|BRM
Jim Clark in 1963|Team Lotus
John Surtees in 1964|Ferrari
Denny Hulme in 1967|Brabham
Jackie Stewart in 1969|Matra
Jochen Rindt in 1970|Team Lotus
Jackie Stewart in 1971|Tyrrell
Emerson Fittipaldi in 1972|Team Lotus
Emerson Fittipaldi in 1974|McLaren
Niki Lauda in 1975|Ferrari
James Hunt in 1976|McLaren
Mario Andretti in 1978|Team Lotus
Jody Scheckter in 1979|Ferrari
Ronnie Peterson in 1978|Team Lotus
Carlos Reutemann in 1978|Ferrari
Clay Regazzoni in 1974|Ferrari
Bruce McLaren in 1968|McLaren
Jacky Ickx in 1970|Ferrari
''',
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'f1',
    relation: 'team_base',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
Vanwall|United Kingdom
the Cooper Car Company|United Kingdom
BRM|United Kingdom
Team Lotus|United Kingdom
Brabham|United Kingdom
Matra|France
Tyrrell|United Kingdom
Maserati|Italy
Alfa Romeo|Italy
Gordini|France
''',
    extraOptions: const ['Germany', 'Switzerland'],
  );
}

void _addF1Hard() {
  // Race-by-race winners. Every prompt names its season, so nothing here rots.
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'f1',
    relation: 'race_winner',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
2021 Bahrain Grand Prix|Lewis Hamilton|2021
2021 Emilia Romagna Grand Prix|Max Verstappen|2021
2021 Portuguese Grand Prix|Lewis Hamilton|2021
2021 Spanish Grand Prix|Lewis Hamilton|2021
2021 Monaco Grand Prix|Max Verstappen|2021
2021 Azerbaijan Grand Prix|Sergio Pérez|2021
2021 French Grand Prix|Max Verstappen|2021
2021 Styrian Grand Prix|Max Verstappen|2021
2021 Austrian Grand Prix|Max Verstappen|2021
2021 British Grand Prix|Lewis Hamilton|2021
2021 Hungarian Grand Prix|Esteban Ocon|2021
2021 Belgian Grand Prix|Max Verstappen|2021
2021 Dutch Grand Prix|Max Verstappen|2021
2021 Italian Grand Prix|Daniel Ricciardo|2021
2021 Russian Grand Prix|Lewis Hamilton|2021
2021 Turkish Grand Prix|Valtteri Bottas|2021
2021 United States Grand Prix|Max Verstappen|2021
2021 Mexico City Grand Prix|Max Verstappen|2021
2021 São Paulo Grand Prix|Lewis Hamilton|2021
2021 Qatar Grand Prix|Lewis Hamilton|2021
2021 Saudi Arabian Grand Prix|Lewis Hamilton|2021
2021 Abu Dhabi Grand Prix|Max Verstappen|2021
2022 Bahrain Grand Prix|Charles Leclerc|2022
2022 Saudi Arabian Grand Prix|Max Verstappen|2022
2022 Australian Grand Prix|Charles Leclerc|2022
2022 Emilia Romagna Grand Prix|Max Verstappen|2022
2022 Miami Grand Prix|Max Verstappen|2022
2022 Spanish Grand Prix|Max Verstappen|2022
2022 Monaco Grand Prix|Sergio Pérez|2022
2022 Azerbaijan Grand Prix|Max Verstappen|2022
2022 Canadian Grand Prix|Max Verstappen|2022
2022 British Grand Prix|Carlos Sainz|2022
2022 Austrian Grand Prix|Charles Leclerc|2022
2022 French Grand Prix|Max Verstappen|2022
2022 Hungarian Grand Prix|Max Verstappen|2022
2022 Belgian Grand Prix|Max Verstappen|2022
2022 Dutch Grand Prix|Max Verstappen|2022
2022 Italian Grand Prix|Max Verstappen|2022
2022 Singapore Grand Prix|Sergio Pérez|2022
2022 Japanese Grand Prix|Max Verstappen|2022
2022 United States Grand Prix|Max Verstappen|2022
2022 Mexico City Grand Prix|Max Verstappen|2022
2022 São Paulo Grand Prix|George Russell|2022
2022 Abu Dhabi Grand Prix|Max Verstappen|2022
2023 Singapore Grand Prix|Carlos Sainz|2023
2023 British Grand Prix|Max Verstappen|2023
2023 Azerbaijan Grand Prix|Sergio Pérez|2023
2024 Australian Grand Prix|Carlos Sainz|2024
2024 Miami Grand Prix|Lando Norris|2024
2024 Monaco Grand Prix|Charles Leclerc|2024
2024 São Paulo Grand Prix|Max Verstappen|2024
2025 Australian Grand Prix|Lando Norris|2025
2025 Japanese Grand Prix|Max Verstappen|2025
''',
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'f1',
    relation: 'race_winner',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
2012 Australian Grand Prix|Jenson Button|2012
2012 Malaysian Grand Prix|Fernando Alonso|2012
2012 Chinese Grand Prix|Nico Rosberg|2012
2012 Bahrain Grand Prix|Sebastian Vettel|2012
2012 Spanish Grand Prix|Pastor Maldonado|2012
2012 Monaco Grand Prix|Mark Webber|2012
2012 Canadian Grand Prix|Lewis Hamilton|2012
2012 European Grand Prix|Fernando Alonso|2012
2012 British Grand Prix|Mark Webber|2012
2012 German Grand Prix|Fernando Alonso|2012
2012 Hungarian Grand Prix|Lewis Hamilton|2012
2012 Belgian Grand Prix|Jenson Button|2012
2012 Italian Grand Prix|Lewis Hamilton|2012
2012 Singapore Grand Prix|Sebastian Vettel|2012
2012 Japanese Grand Prix|Sebastian Vettel|2012
2012 Korean Grand Prix|Sebastian Vettel|2012
2012 Indian Grand Prix|Sebastian Vettel|2012
2012 Abu Dhabi Grand Prix|Kimi Räikkönen|2012
2012 United States Grand Prix|Lewis Hamilton|2012
2012 Brazilian Grand Prix|Jenson Button|2012
2010 Bahrain Grand Prix|Fernando Alonso|2010
2010 Australian Grand Prix|Jenson Button|2010
2010 Malaysian Grand Prix|Sebastian Vettel|2010
2010 Chinese Grand Prix|Jenson Button|2010
2010 Spanish Grand Prix|Lewis Hamilton|2010
2010 Monaco Grand Prix|Mark Webber|2010
2010 Turkish Grand Prix|Lewis Hamilton|2010
2010 Canadian Grand Prix|Lewis Hamilton|2010
2010 European Grand Prix|Sebastian Vettel|2010
2010 British Grand Prix|Mark Webber|2010
2010 German Grand Prix|Fernando Alonso|2010
2010 Hungarian Grand Prix|Mark Webber|2010
2010 Belgian Grand Prix|Lewis Hamilton|2010
2010 Italian Grand Prix|Fernando Alonso|2010
2010 Singapore Grand Prix|Fernando Alonso|2010
2010 Japanese Grand Prix|Sebastian Vettel|2010
2010 Korean Grand Prix|Fernando Alonso|2010
2010 Brazilian Grand Prix|Sebastian Vettel|2010
2010 Abu Dhabi Grand Prix|Sebastian Vettel|2010
2014 Australian Grand Prix|Nico Rosberg|2014
2014 Malaysian Grand Prix|Lewis Hamilton|2014
2014 Bahrain Grand Prix|Lewis Hamilton|2014
2014 Canadian Grand Prix|Daniel Ricciardo|2014
2014 Hungarian Grand Prix|Daniel Ricciardo|2014
2014 Belgian Grand Prix|Daniel Ricciardo|2014
2016 Spanish Grand Prix|Max Verstappen|2016
2016 Monaco Grand Prix|Lewis Hamilton|2016
2016 Abu Dhabi Grand Prix|Lewis Hamilton|2016
2017 Australian Grand Prix|Sebastian Vettel|2017
2017 Chinese Grand Prix|Lewis Hamilton|2017
2018 Australian Grand Prix|Sebastian Vettel|2018
2019 Australian Grand Prix|Valtteri Bottas|2019
2019 German Grand Prix|Max Verstappen|2019
''',
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'f1',
    relation: 'race_winner',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
2002 Australian Grand Prix|Michael Schumacher|2002
2002 Malaysian Grand Prix|Ralf Schumacher|2002
2002 Brazilian Grand Prix|Michael Schumacher|2002
2002 San Marino Grand Prix|Michael Schumacher|2002
2002 Spanish Grand Prix|Michael Schumacher|2002
2002 Austrian Grand Prix|Michael Schumacher|2002
2002 Monaco Grand Prix|David Coulthard|2002
2002 Canadian Grand Prix|Michael Schumacher|2002
2002 European Grand Prix|Rubens Barrichello|2002
2002 British Grand Prix|Michael Schumacher|2002
2002 French Grand Prix|Michael Schumacher|2002
2002 German Grand Prix|Michael Schumacher|2002
2002 Hungarian Grand Prix|Rubens Barrichello|2002
2002 Belgian Grand Prix|Michael Schumacher|2002
2002 Italian Grand Prix|Rubens Barrichello|2002
2002 Japanese Grand Prix|Michael Schumacher|2002
2005 Australian Grand Prix|Giancarlo Fisichella|2005
2005 Malaysian Grand Prix|Fernando Alonso|2005
2005 Bahrain Grand Prix|Fernando Alonso|2005
2005 San Marino Grand Prix|Fernando Alonso|2005
2005 Spanish Grand Prix|Kimi Räikkönen|2005
2005 Monaco Grand Prix|Kimi Räikkönen|2005
2005 European Grand Prix|Fernando Alonso|2005
2005 Canadian Grand Prix|Kimi Räikkönen|2005
2005 United States Grand Prix|Michael Schumacher|2005
2005 French Grand Prix|Fernando Alonso|2005
2005 British Grand Prix|Juan Pablo Montoya|2005
2005 German Grand Prix|Fernando Alonso|2005
2005 Hungarian Grand Prix|Kimi Räikkönen|2005
2005 Turkish Grand Prix|Kimi Räikkönen|2005
2005 Italian Grand Prix|Juan Pablo Montoya|2005
2005 Belgian Grand Prix|Kimi Räikkönen|2005
2005 Brazilian Grand Prix|Juan Pablo Montoya|2005
2005 Japanese Grand Prix|Kimi Räikkönen|2005
2005 Chinese Grand Prix|Fernando Alonso|2005
2000 Australian Grand Prix|Michael Schumacher|2000
2000 Brazilian Grand Prix|Michael Schumacher|2000
2001 Australian Grand Prix|Michael Schumacher|2001
2003 Australian Grand Prix|David Coulthard|2003
2003 Brazilian Grand Prix|Giancarlo Fisichella|2003
2003 Hungarian Grand Prix|Fernando Alonso|2003
2004 Australian Grand Prix|Michael Schumacher|2004
2004 Monaco Grand Prix|Jarno Trulli|2004
2004 Belgian Grand Prix|Kimi Räikkönen|2004
2006 Bahrain Grand Prix|Fernando Alonso|2006
2006 Hungarian Grand Prix|Jenson Button|2006
2007 Australian Grand Prix|Kimi Räikkönen|2007
2007 Canadian Grand Prix|Lewis Hamilton|2007
2008 Australian Grand Prix|Lewis Hamilton|2008
2008 Italian Grand Prix|Sebastian Vettel|2008
2009 Australian Grand Prix|Jenson Button|2009
2009 Belgian Grand Prix|Kimi Räikkönen|2009
2003 Monaco Grand Prix|Juan Pablo Montoya|2003
''',
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'f1',
    relation: 'race_winner',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
1988 Brazilian Grand Prix|Alain Prost|1988
1988 San Marino Grand Prix|Ayrton Senna|1988
1988 Monaco Grand Prix|Alain Prost|1988
1988 Mexican Grand Prix|Alain Prost|1988
1988 Canadian Grand Prix|Ayrton Senna|1988
1988 Detroit Grand Prix|Ayrton Senna|1988
1988 French Grand Prix|Alain Prost|1988
1988 British Grand Prix|Ayrton Senna|1988
1988 German Grand Prix|Ayrton Senna|1988
1988 Hungarian Grand Prix|Ayrton Senna|1988
1988 Belgian Grand Prix|Ayrton Senna|1988
1988 Italian Grand Prix|Gerhard Berger|1988
1988 Portuguese Grand Prix|Alain Prost|1988
1988 Spanish Grand Prix|Alain Prost|1988
1988 Japanese Grand Prix|Ayrton Senna|1988
1988 Australian Grand Prix|Alain Prost|1988
1992 South African Grand Prix|Nigel Mansell|1992
1992 Mexican Grand Prix|Nigel Mansell|1992
1992 Brazilian Grand Prix|Nigel Mansell|1992
1992 Spanish Grand Prix|Nigel Mansell|1992
1992 San Marino Grand Prix|Nigel Mansell|1992
1992 Monaco Grand Prix|Ayrton Senna|1992
1992 Canadian Grand Prix|Gerhard Berger|1992
1992 French Grand Prix|Nigel Mansell|1992
1992 British Grand Prix|Nigel Mansell|1992
1992 German Grand Prix|Nigel Mansell|1992
1992 Hungarian Grand Prix|Ayrton Senna|1992
1992 Belgian Grand Prix|Michael Schumacher|1992
1992 Italian Grand Prix|Ayrton Senna|1992
1992 Portuguese Grand Prix|Nigel Mansell|1992
1992 Japanese Grand Prix|Riccardo Patrese|1992
1992 Australian Grand Prix|Gerhard Berger|1992
1994 Brazilian Grand Prix|Michael Schumacher|1994
1994 Monaco Grand Prix|Michael Schumacher|1994
1994 Spanish Grand Prix|Damon Hill|1994
1994 British Grand Prix|Damon Hill|1994
1994 Belgian Grand Prix|Damon Hill|1994
1994 Italian Grand Prix|Damon Hill|1994
1994 Australian Grand Prix|Nigel Mansell|1994
1996 Australian Grand Prix|Damon Hill|1996
1996 Monaco Grand Prix|Olivier Panis|1996
1996 Spanish Grand Prix|Michael Schumacher|1996
1997 Australian Grand Prix|David Coulthard|1997
1997 Monaco Grand Prix|Michael Schumacher|1997
1997 European Grand Prix|Jacques Villeneuve|1997
1998 Australian Grand Prix|Mika Häkkinen|1998
1998 Monaco Grand Prix|Mika Häkkinen|1998
1998 Belgian Grand Prix|Damon Hill|1998
1999 Australian Grand Prix|Eddie Irvine|1999
1999 British Grand Prix|David Coulthard|1999
1999 European Grand Prix|Johnny Herbert|1999
1985 Portuguese Grand Prix|Ayrton Senna|1985
1987 British Grand Prix|Nigel Mansell|1987
''',
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'f1',
    relation: 'race_winner',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
1976 Brazilian Grand Prix|Niki Lauda|1976
1976 South African Grand Prix|Niki Lauda|1976
1976 United States West Grand Prix|Clay Regazzoni|1976
1976 Spanish Grand Prix|James Hunt|1976
1976 Belgian Grand Prix|Niki Lauda|1976
1976 Monaco Grand Prix|Niki Lauda|1976
1976 Swedish Grand Prix|Jody Scheckter|1976
1976 French Grand Prix|James Hunt|1976
1976 German Grand Prix|James Hunt|1976
1976 Austrian Grand Prix|John Watson|1976
1976 Dutch Grand Prix|James Hunt|1976
1976 Italian Grand Prix|Ronnie Peterson|1976
1976 Canadian Grand Prix|James Hunt|1976
1976 United States East Grand Prix|James Hunt|1976
1976 Japanese Grand Prix|Mario Andretti|1976
1970 South African Grand Prix|Jack Brabham|1970
1970 Spanish Grand Prix|Jackie Stewart|1970
1970 Monaco Grand Prix|Jochen Rindt|1970
1970 Belgian Grand Prix|Pedro Rodríguez|1970
1970 Dutch Grand Prix|Jochen Rindt|1970
1970 French Grand Prix|Jochen Rindt|1970
1970 British Grand Prix|Jochen Rindt|1970
1970 German Grand Prix|Jochen Rindt|1970
1970 Austrian Grand Prix|Jacky Ickx|1970
1970 Italian Grand Prix|Clay Regazzoni|1970
1970 Canadian Grand Prix|Jacky Ickx|1970
1970 United States Grand Prix|Emerson Fittipaldi|1970
1970 Mexican Grand Prix|Jacky Ickx|1970
1967 South African Grand Prix|Pedro Rodríguez|1967
1967 Monaco Grand Prix|Denny Hulme|1967
1967 Dutch Grand Prix|Jim Clark|1967
1967 Belgian Grand Prix|Dan Gurney|1967
1967 French Grand Prix|Jack Brabham|1967
1967 British Grand Prix|Jim Clark|1967
1967 German Grand Prix|Denny Hulme|1967
1967 Canadian Grand Prix|Jack Brabham|1967
1967 Italian Grand Prix|John Surtees|1967
1967 United States Grand Prix|Jim Clark|1967
1967 Mexican Grand Prix|Jim Clark|1967
1955 British Grand Prix|Stirling Moss|1955
1957 German Grand Prix|Juan Manuel Fangio|1957
1958 Moroccan Grand Prix|Stirling Moss|1958
1961 Italian Grand Prix|Phil Hill|1961
1963 Belgian Grand Prix|Jim Clark|1963
1965 British Grand Prix|Jim Clark|1965
1966 Italian Grand Prix|Ludovico Scarfiotti|1966
1968 Spanish Grand Prix|Graham Hill|1968
1969 Italian Grand Prix|Jackie Stewart|1969
1972 British Grand Prix|Emerson Fittipaldi|1972
1973 Monaco Grand Prix|Jackie Stewart|1973
1974 Monaco Grand Prix|Ronnie Peterson|1974
1975 Austrian Grand Prix|Vittorio Brambilla|1975
1977 Japanese Grand Prix|James Hunt|1977
1979 French Grand Prix|Jean-Pierre Jabouille|1979
''',
  );
}

void _addF1Global() {
  // GLOBAL leans on the championship's world geography and its all-time
  // records rather than on European race results.
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'f1',
    relation: 'venue',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
the Saudi Arabian Grand Prix|Jeddah Corniche Circuit
the Qatar Grand Prix|Losail International Circuit
the Miami Grand Prix|Miami International Autodrome
the Las Vegas Grand Prix|the Las Vegas Strip Circuit
the Abu Dhabi Grand Prix|Yas Marina Circuit
the Bahrain Grand Prix|Bahrain International Circuit
the Azerbaijan Grand Prix|Baku City Circuit
the Chinese Grand Prix|Shanghai International Circuit
the United States Grand Prix|Circuit of the Americas
the Australian Grand Prix|Albert Park Circuit
the Dutch Grand Prix|Circuit Zandvoort
the Emilia Romagna Grand Prix|Imola
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'f1',
    relation: 'circuit_city',
    competition: 'Formula 1 World Championship',
    sources: const ['f1-results-archive', 'fia-championship-records'],
    data: '''
Yas Marina Circuit|Abu Dhabi
Marina Bay Street Circuit|Singapore
Baku City Circuit|Baku
Jeddah Corniche Circuit|Jeddah
Circuit of the Americas|Austin
Miami International Autodrome|Miami Gardens
Albert Park Circuit|Melbourne
Suzuka Circuit|Suzuka
Interlagos|São Paulo
Autódromo Hermanos Rodríguez|Mexico City
Shanghai International Circuit|Shanghai
Bahrain International Circuit|Sakhir
Losail International Circuit|Lusail
Circuit Gilles Villeneuve|Montreal
the Las Vegas Strip Circuit|Las Vegas
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'f1',
    relation: 'first_year',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
the Bahrain Grand Prix|2004
the Chinese Grand Prix|2004
the Turkish Grand Prix|2005
the Singapore Grand Prix|2008
the Abu Dhabi Grand Prix|2009
the Korean Grand Prix|2010
the Indian Grand Prix|2011
the Russian Grand Prix|2014
the Azerbaijan Grand Prix|2017
the Mexican Grand Prix|1963
the Japanese Grand Prix|1976
the Malaysian Grand Prix|1999
the Las Vegas Grand Prix|2023
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'f1',
    relation: 'car_number',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-regulations'],
    data: '''
Lewis Hamilton|44
Charles Leclerc|16
Lando Norris|4
Fernando Alonso|14
Sebastian Vettel|5
Kimi Räikkönen|7
Sergio Pérez|11
Valtteri Bottas|77
Daniel Ricciardo|3
Carlos Sainz|55
George Russell|63
Esteban Ocon|31
Pierre Gasly|10
Oscar Piastri|81
''',
    extraOptions: const ['22', '18', '27'],
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'f1',
    relation: 'title_count',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-drivers-hall'],
    data: '''
Michael Schumacher|seven
Lewis Hamilton|seven
Juan Manuel Fangio|five
Alain Prost|four
Sebastian Vettel|four
Max Verstappen|four
Ayrton Senna|three
Jackie Stewart|three
Niki Lauda|three
Nelson Piquet|three
Jack Brabham|three
Jim Clark|two
Graham Hill|two
Emerson Fittipaldi|two
Fernando Alonso|two
Mika Häkkinen|two
Alberto Ascari|two
Nigel Mansell|one
Damon Hill|one
Jenson Button|one
Kimi Räikkönen|one
Nico Rosberg|one
Jacques Villeneuve|one
James Hunt|one
Mario Andretti|one
John Surtees|one
Phil Hill|one
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'f1',
    relation: 'title_count',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-drivers-hall'],
    data: '''
Denny Hulme|one
Jody Scheckter|one
Keke Rosberg|one
Alan Jones|one
Jochen Rindt|one
Mike Hawthorn|one
Nino Farina|one
Lando Norris|one
''',
    extraOptions: const ['two', 'three', 'four'],
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'f1',
    relation: 'record_holder',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
the most Formula 1 race wins|Lewis Hamilton
the most Formula 1 pole positions|Lewis Hamilton
the most Formula 1 race starts|Fernando Alonso
the most wins in a single season|Max Verstappen
the youngest Formula 1 world champion|Sebastian Vettel
the youngest Formula 1 race winner|Max Verstappen
the oldest Formula 1 world champion|Juan Manuel Fangio
the most consecutive Formula 1 wins|Max Verstappen
the most Formula 1 fastest laps|Michael Schumacher
the youngest Formula 1 pole-sitter|Sebastian Vettel
the most Formula 1 podium finishes|Lewis Hamilton
the most points in a single season|Max Verstappen
the most Grand Prix wins for Ferrari|Michael Schumacher
the most Grand Prix wins for McLaren|Ayrton Senna
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'f1',
    relation: 'tyre_supplier',
    competition: 'Formula 1',
    sources: const ['fia-regulations', 'f1-results-archive'],
    data: '''
Formula 1 since 2011|Pirelli
Formula 1 from 2007 to 2010|Bridgestone
Formula 1 from 2001 to 2006|Bridgestone and Michelin
Formula 1 from 1997 to 2000|Bridgestone and Goodyear
Formula 1 in the 1980s|Goodyear and Pirelli
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'f1',
    relation: 'first_year',
    competition: 'Formula 1 World Championship',
    sources: const ['fia-championship-records', 'f1-results-archive'],
    data: '''
the British Grand Prix|1950
the Monaco Grand Prix|1950
the Italian Grand Prix|1950
the Belgian Grand Prix|1950
the French Grand Prix|1950
the Swiss Grand Prix|1950
the German Grand Prix|1951
the Spanish Grand Prix|1951
the Dutch Grand Prix|1952
the Argentine Grand Prix|1953
the Portuguese Grand Prix|1958
the Moroccan Grand Prix|1958
the South African Grand Prix|1962
the Austrian Grand Prix|1964
the Canadian Grand Prix|1967
the Swedish Grand Prix|1973
the Brazilian Grand Prix|1973
the San Marino Grand Prix|1981
the Australian Grand Prix|1985
the Hungarian Grand Prix|1986
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'f1',
    relation: 'team_base',
    competition: 'Formula 1',
    sources: const ['f1-drivers-hall', 'fia-championship-records'],
    data: '''
March Engineering|United Kingdom
Hesketh Racing|United Kingdom
Ligier|France
Osella|Italy
Zakspeed|Germany
AGS|France
Coloni|Italy
''',
    extraOptions: const ['Brazil', 'Japan'],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTOGP — 245 facts (easy 55, medium 55, hard 55, global 80)
// Premier class only: "500cc" for seasons up to 2001, "MotoGP" from 2002.
// ─────────────────────────────────────────────────────────────────────────────

void _addMotoGpFacts() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'motogp',
    relation: 'champion_rider',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
2025 MotoGP|Marc Márquez|2025
2024 MotoGP|Jorge Martín|2024
2023 MotoGP|Francesco Bagnaia|2023
2022 MotoGP|Francesco Bagnaia|2022
2021 MotoGP|Fabio Quartararo|2021
2020 MotoGP|Joan Mir|2020
2019 MotoGP|Marc Márquez|2019
2018 MotoGP|Marc Márquez|2018
2017 MotoGP|Marc Márquez|2017
2016 MotoGP|Marc Márquez|2016
2015 MotoGP|Jorge Lorenzo|2015
''',
    extraOptions: const ['Maverick Viñales', 'Brad Binder'],
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'motogp',
    relation: 'champion_rider',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
2014 MotoGP|Marc Márquez|2014
2013 MotoGP|Marc Márquez|2013
2012 MotoGP|Jorge Lorenzo|2012
2011 MotoGP|Casey Stoner|2011
2010 MotoGP|Jorge Lorenzo|2010
2009 MotoGP|Valentino Rossi|2009
2008 MotoGP|Valentino Rossi|2008
2007 MotoGP|Casey Stoner|2007
2006 MotoGP|Nicky Hayden|2006
2005 MotoGP|Valentino Rossi|2005
2004 MotoGP|Valentino Rossi|2004
''',
    extraOptions: const ['Dani Pedrosa', 'Andrea Dovizioso'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'motogp',
    relation: 'champion_rider',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
2003 MotoGP|Valentino Rossi|2003
2002 MotoGP|Valentino Rossi|2002
2001 500cc|Valentino Rossi|2001
2000 500cc|Kenny Roberts Jr|2000
1999 500cc|Àlex Crivillé|1999
1998 500cc|Mick Doohan|1998
1997 500cc|Mick Doohan|1997
1996 500cc|Mick Doohan|1996
1995 500cc|Mick Doohan|1995
1994 500cc|Mick Doohan|1994
1993 500cc|Kevin Schwantz|1993
''',
    extraOptions: const ['Max Biaggi', 'Loris Capirossi'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'motogp',
    relation: 'champion_rider',
    competition: '500cc World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
1992 500cc|Wayne Rainey|1992
1991 500cc|Wayne Rainey|1991
1990 500cc|Wayne Rainey|1990
1989 500cc|Eddie Lawson|1989
1988 500cc|Eddie Lawson|1988
1987 500cc|Wayne Gardner|1987
1986 500cc|Eddie Lawson|1986
1985 500cc|Freddie Spencer|1985
1984 500cc|Eddie Lawson|1984
1983 500cc|Freddie Spencer|1983
1982 500cc|Franco Uncini|1982
''',
    extraOptions: const ['Randy Mamola', 'Kevin Schwantz'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'motogp',
    relation: 'champion_rider',
    competition: '500cc World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
1981 500cc|Marco Lucchinelli|1981
1980 500cc|Kenny Roberts|1980
1979 500cc|Kenny Roberts|1979
1978 500cc|Kenny Roberts|1978
1977 500cc|Barry Sheene|1977
1976 500cc|Barry Sheene|1976
1975 500cc|Giacomo Agostini|1975
1974 500cc|Phil Read|1974
1973 500cc|Phil Read|1973
1972 500cc|Giacomo Agostini|1972
1971 500cc|Giacomo Agostini|1971
''',
    extraOptions: const ['Mike Hailwood', 'Franco Uncini'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'motogp',
    relation: 'rider_manufacturer',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
Marc Márquez in 2025|Ducati
Jorge Martín in 2024|Ducati
Francesco Bagnaia in 2023|Ducati
Fabio Quartararo in 2021|Yamaha
Joan Mir in 2020|Suzuki
Marc Márquez in 2019|Honda
Maverick Viñales in 2021|Yamaha
Enea Bastianini in 2022|Ducati
Aleix Espargaró in 2022|Aprilia
Brad Binder in 2021|KTM
Miguel Oliveira in 2021|KTM
''',
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'motogp',
    relation: 'rider_manufacturer',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
Jorge Lorenzo in 2015|Yamaha
Valentino Rossi in 2015|Yamaha
Casey Stoner in 2011|Honda
Dani Pedrosa in 2012|Honda
Cal Crutchlow in 2016|Honda
Andrea Dovizioso in 2017|Ducati
Andrea Iannone in 2016|Ducati
Jack Miller in 2019|Ducati
Alex Rins in 2019|Suzuki
Johann Zarco in 2018|Yamaha
Pol Espargaró in 2019|KTM
''',
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'motogp',
    relation: 'rider_manufacturer',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
Valentino Rossi in 2004|Yamaha
Valentino Rossi in 2003|Honda
Nicky Hayden in 2006|Honda
Casey Stoner in 2007|Ducati
Loris Capirossi in 2006|Ducati
Max Biaggi in 2004|Honda
Sete Gibernau in 2004|Honda
Marco Melandri in 2005|Honda
Kenny Roberts Jr in 2000|Suzuki
John Hopkins in 2007|Suzuki
Colin Edwards in 2005|Yamaha
''',
    extraOptions: const ['Aprilia', 'KTM'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'motogp',
    relation: 'rider_manufacturer',
    competition: '500cc World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
Mick Doohan in 1998|Honda
Àlex Crivillé in 1999|Honda
Kevin Schwantz in 1993|Suzuki
Wayne Rainey in 1992|Yamaha
Eddie Lawson in 1989|Honda
Wayne Gardner in 1987|Honda
Freddie Spencer in 1985|Honda
Franco Uncini in 1982|Suzuki
Marco Lucchinelli in 1981|Suzuki
Eddie Lawson in 1986|Yamaha
Randy Mamola in 1984|Honda
''',
    extraOptions: const ['Ducati', 'Cagiva'],
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'motogp',
    relation: 'rider_manufacturer',
    competition: '500cc World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
Giacomo Agostini in 1972|MV Agusta
Giacomo Agostini in 1975|Yamaha
Phil Read in 1974|MV Agusta
Barry Sheene in 1976|Suzuki
Kenny Roberts in 1978|Yamaha
Mike Hailwood in 1964|MV Agusta
John Surtees in 1959|MV Agusta
Geoff Duke in 1955|Gilera
Umberto Masetti in 1950|Gilera
Libero Liberati in 1957|Gilera
Gary Hocking in 1961|MV Agusta
''',
    extraOptions: const ['Honda', 'Norton'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'motogp',
    relation: 'race_winner',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
2021 MotoGP Qatar Grand Prix|Maverick Viñales|2021
2021 MotoGP Portuguese Grand Prix|Fabio Quartararo|2021
2021 MotoGP Spanish Grand Prix|Jack Miller|2021
2021 MotoGP French Grand Prix|Jack Miller|2021
2021 MotoGP Italian Grand Prix|Fabio Quartararo|2021
2021 MotoGP Catalan Grand Prix|Miguel Oliveira|2021
2021 MotoGP German Grand Prix|Marc Márquez|2021
2021 MotoGP Dutch TT|Miguel Oliveira|2021
2021 MotoGP Styrian Grand Prix|Jorge Martín|2021
2021 MotoGP Austrian Grand Prix|Brad Binder|2021
2021 MotoGP British Grand Prix|Fabio Quartararo|2021
''',
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'motogp',
    relation: 'race_winner',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
2015 MotoGP Qatar Grand Prix|Valentino Rossi|2015
2015 MotoGP Americas Grand Prix|Marc Márquez|2015
2015 MotoGP Argentine Grand Prix|Valentino Rossi|2015
2015 MotoGP Spanish Grand Prix|Jorge Lorenzo|2015
2015 MotoGP French Grand Prix|Jorge Lorenzo|2015
2015 MotoGP Italian Grand Prix|Jorge Lorenzo|2015
2015 MotoGP Catalan Grand Prix|Jorge Lorenzo|2015
2015 MotoGP Dutch TT|Valentino Rossi|2015
2015 MotoGP German Grand Prix|Marc Márquez|2015
2015 MotoGP Indianapolis Grand Prix|Marc Márquez|2015
2015 MotoGP Czech Grand Prix|Jorge Lorenzo|2015
''',
    extraOptions: const ['Dani Pedrosa', 'Andrea Iannone'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'motogp',
    relation: 'race_winner',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
2008 MotoGP Qatar Grand Prix|Casey Stoner|2008
2008 MotoGP Spanish Grand Prix|Dani Pedrosa|2008
2008 MotoGP Portuguese Grand Prix|Dani Pedrosa|2008
2008 MotoGP Chinese Grand Prix|Valentino Rossi|2008
2008 MotoGP French Grand Prix|Valentino Rossi|2008
2008 MotoGP Italian Grand Prix|Valentino Rossi|2008
2008 MotoGP Catalan Grand Prix|Dani Pedrosa|2008
2008 MotoGP British Grand Prix|Casey Stoner|2008
2008 MotoGP Dutch TT|Valentino Rossi|2008
2008 MotoGP German Grand Prix|Casey Stoner|2008
2008 MotoGP United States Grand Prix|Valentino Rossi|2008
''',
    extraOptions: const ['Jorge Lorenzo', 'Colin Edwards'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'motogp',
    relation: 'record_holder',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
the most premier-class world titles|Giacomo Agostini
the most premier-class race wins|Valentino Rossi
the most Grand Prix wins across all classes|Giacomo Agostini
the youngest premier-class world champion|Marc Márquez
the most consecutive premier-class titles|Giacomo Agostini
the most premier-class pole positions|Marc Márquez
''',
    extraOptions: const ['Mick Doohan', 'Jorge Lorenzo'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'motogp',
    relation: 'premier_title_count',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
Giacomo Agostini|eight
Valentino Rossi|seven
Marc Márquez|seven
Mike Hailwood|four
Mick Doohan|five
''',
    extraOptions: const ['three', 'two'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'motogp',
    relation: 'champion_rider',
    competition: '500cc World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
1949 500cc|Leslie Graham|1949
1950 500cc|Umberto Masetti|1950
1951 500cc|Geoff Duke|1951
1952 500cc|Umberto Masetti|1952
1953 500cc|Geoff Duke|1953
1954 500cc|Geoff Duke|1954
1955 500cc|Geoff Duke|1955
1956 500cc|John Surtees|1956
1957 500cc|Libero Liberati|1957
1958 500cc|John Surtees|1958
1959 500cc|John Surtees|1959
''',
    extraOptions: const ['Gary Hocking', 'Mike Hailwood'],
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'motogp',
    relation: 'driver_nationality',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
Marc Márquez|Spain
Francesco Bagnaia|Italy
Fabio Quartararo|France
Joan Mir|Spain
Jorge Martín|Spain
Brad Binder|South Africa
Miguel Oliveira|Portugal
Maverick Viñales|Spain
Aleix Espargaró|Spain
Enea Bastianini|Italy
Johann Zarco|France
Jack Miller|Australia
Takaaki Nakagami|Japan
Alex Rins|Spain
Luca Marini|Italy
Pedro Acosta|Spain
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'motogp',
    relation: 'driver_nationality',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
Valentino Rossi|Italy
Jorge Lorenzo|Spain
Casey Stoner|Australia
Dani Pedrosa|Spain
Nicky Hayden|United States
Max Biaggi|Italy
Loris Capirossi|Italy
Sete Gibernau|Spain
Marco Melandri|Italy
Colin Edwards|United States
Andrea Dovizioso|Italy
Cal Crutchlow|United Kingdom
Kenny Roberts Jr|United States
Àlex Crivillé|Spain
Mick Doohan|Australia
Wayne Rainey|United States
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'motogp',
    relation: 'circuit_country',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
the Sachsenring|Germany
the TT Circuit Assen|Netherlands
the Twin Ring Motegi|Japan
the Phillip Island circuit|Australia
the Chang International Circuit|Thailand
the Termas de Río Hondo circuit|Argentina
the Misano World Circuit|San Marino
the Automotodrom Brno|Czechia
the Motorland Aragón circuit|Spain
the Mandalika circuit|Indonesia
the Laguna Seca circuit|United States
the Portimão circuit|Portugal
the Balaton Park Circuit|Hungary
the Kymiring|Finland
the Sokol International Racetrack|Kazakhstan
the Buddh circuit|India
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'motogp',
    relation: 'champion_manufacturer',
    competition: 'MotoGP World Championship',
    sources: const ['motogp-results', 'motogp-history'],
    data: '''
2025 MotoGP|Ducati|2025
2024 MotoGP|Ducati|2024
2023 MotoGP|Ducati|2023
2022 MotoGP|Ducati|2022
2021 MotoGP|Ducati|2021
2020 MotoGP|Ducati|2020
2019 MotoGP|Honda|2019
2018 MotoGP|Honda|2018
2017 MotoGP|Honda|2017
2016 MotoGP|Honda|2016
2015 MotoGP|Yamaha|2015
2014 MotoGP|Honda|2014
2013 MotoGP|Honda|2013
2012 MotoGP|Honda|2012
2011 MotoGP|Honda|2011
2010 MotoGP|Yamaha|2010
''',
    extraOptions: const ['Suzuki', 'Aprilia', 'KTM'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'motogp',
    relation: 'premier_title_count',
    competition: '500cc World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
Geoff Duke|four
Eddie Lawson|four
Kenny Roberts|three
Wayne Rainey|three
Barry Sheene|two
Freddie Spencer|two
John Surtees|four
Phil Read|two
''',
    extraOptions: const ['five', 'one'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'motogp',
    relation: 'driver_nationality',
    competition: '500cc World Championship',
    sources: const ['motogp-history', 'motogp-results'],
    data: '''
Giacomo Agostini|Italy
Mike Hailwood|United Kingdom
Geoff Duke|United Kingdom
Barry Sheene|United Kingdom
Kenny Roberts|United States
Freddie Spencer|United States
Eddie Lawson|United States
Wayne Gardner|Australia
''',
    extraOptions: const ['Spain', 'Japan'],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NASCAR — 195 facts (easy 50, medium 50, hard 50, global 45)
// ─────────────────────────────────────────────────────────────────────────────

void _addNascarFacts() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
2024 NASCAR Cup Series|Joey Logano|2024
2023 NASCAR Cup Series|Ryan Blaney|2023
2022 NASCAR Cup Series|Joey Logano|2022
2021 NASCAR Cup Series|Kyle Larson|2021
2020 NASCAR Cup Series|Chase Elliott|2020
2019 NASCAR Cup Series|Kyle Busch|2019
2018 NASCAR Cup Series|Joey Logano|2018
2017 NASCAR Cup Series|Martin Truex Jr|2017
2016 NASCAR Cup Series|Jimmie Johnson|2016
2015 NASCAR Cup Series|Kyle Busch|2015
''',
    extraOptions: const ['Denny Hamlin', 'Kevin Harvick'],
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
2014 NASCAR Cup Series|Kevin Harvick|2014
2013 NASCAR Cup Series|Jimmie Johnson|2013
2012 NASCAR Cup Series|Brad Keselowski|2012
2011 NASCAR Cup Series|Tony Stewart|2011
2010 NASCAR Cup Series|Jimmie Johnson|2010
2009 NASCAR Cup Series|Jimmie Johnson|2009
2008 NASCAR Cup Series|Jimmie Johnson|2008
2007 NASCAR Cup Series|Jimmie Johnson|2007
2006 NASCAR Cup Series|Jimmie Johnson|2006
2005 NASCAR Cup Series|Tony Stewart|2005
''',
    extraOptions: const ['Carl Edwards', 'Matt Kenseth'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
2004 NASCAR Cup Series|Kurt Busch|2004
2003 NASCAR Cup Series|Matt Kenseth|2003
2002 NASCAR Cup Series|Tony Stewart|2002
2001 NASCAR Cup Series|Jeff Gordon|2001
2000 NASCAR Cup Series|Bobby Labonte|2000
1999 NASCAR Cup Series|Dale Jarrett|1999
1998 NASCAR Cup Series|Jeff Gordon|1998
1997 NASCAR Cup Series|Jeff Gordon|1997
1996 NASCAR Cup Series|Terry Labonte|1996
1995 NASCAR Cup Series|Jeff Gordon|1995
''',
    extraOptions: const ['Mark Martin', 'Rusty Wallace'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
1994 NASCAR Cup Series|Dale Earnhardt|1994
1993 NASCAR Cup Series|Dale Earnhardt|1993
1992 NASCAR Cup Series|Alan Kulwicki|1992
1991 NASCAR Cup Series|Dale Earnhardt|1991
1990 NASCAR Cup Series|Dale Earnhardt|1990
1989 NASCAR Cup Series|Rusty Wallace|1989
1988 NASCAR Cup Series|Bill Elliott|1988
1987 NASCAR Cup Series|Dale Earnhardt|1987
1986 NASCAR Cup Series|Dale Earnhardt|1986
1985 NASCAR Cup Series|Darrell Waltrip|1985
''',
    extraOptions: const ['Davey Allison', 'Harry Gant'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
1984 NASCAR Cup Series|Terry Labonte|1984
1983 NASCAR Cup Series|Bobby Allison|1983
1982 NASCAR Cup Series|Darrell Waltrip|1982
1981 NASCAR Cup Series|Darrell Waltrip|1981
1980 NASCAR Cup Series|Dale Earnhardt|1980
1979 NASCAR Cup Series|Richard Petty|1979
1978 NASCAR Cup Series|Cale Yarborough|1978
1977 NASCAR Cup Series|Cale Yarborough|1977
1976 NASCAR Cup Series|Cale Yarborough|1976
1975 NASCAR Cup Series|Richard Petty|1975
''',
    extraOptions: const ['Benny Parsons', 'David Pearson'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
2025 Daytona 500|William Byron|2025
2024 Daytona 500|William Byron|2024
2023 Daytona 500|Ricky Stenhouse Jr|2023
2022 Daytona 500|Austin Cindric|2022
2021 Daytona 500|Michael McDowell|2021
2020 Daytona 500|Denny Hamlin|2020
2019 Daytona 500|Denny Hamlin|2019
2018 Daytona 500|Austin Dillon|2018
2017 Daytona 500|Kurt Busch|2017
2016 Daytona 500|Denny Hamlin|2016
''',
    extraOptions: const ['Joey Logano', 'Chase Elliott'],
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
2015 Daytona 500|Joey Logano|2015
2014 Daytona 500|Dale Earnhardt Jr|2014
2013 Daytona 500|Jimmie Johnson|2013
2012 Daytona 500|Matt Kenseth|2012
2011 Daytona 500|Trevor Bayne|2011
2010 Daytona 500|Jamie McMurray|2010
2009 Daytona 500|Matt Kenseth|2009
2008 Daytona 500|Ryan Newman|2008
2007 Daytona 500|Kevin Harvick|2007
2006 Daytona 500|Jimmie Johnson|2006
''',
    extraOptions: const ['Tony Stewart', 'Kyle Busch'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
2005 Daytona 500|Jeff Gordon|2005
2004 Daytona 500|Dale Earnhardt Jr|2004
2003 Daytona 500|Michael Waltrip|2003
2002 Daytona 500|Ward Burton|2002
2001 Daytona 500|Michael Waltrip|2001
2000 Daytona 500|Dale Jarrett|2000
1999 Daytona 500|Jeff Gordon|1999
1998 Daytona 500|Dale Earnhardt|1998
1997 Daytona 500|Jeff Gordon|1997
1996 Daytona 500|Dale Jarrett|1996
''',
    extraOptions: const ['Sterling Marlin', 'Bobby Labonte'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
1995 Daytona 500|Sterling Marlin|1995
1994 Daytona 500|Sterling Marlin|1994
1993 Daytona 500|Dale Jarrett|1993
1992 Daytona 500|Davey Allison|1992
1991 Daytona 500|Ernie Irvan|1991
1990 Daytona 500|Derrike Cope|1990
1989 Daytona 500|Darrell Waltrip|1989
1988 Daytona 500|Bobby Allison|1988
1987 Daytona 500|Bill Elliott|1987
1986 Daytona 500|Geoff Bodine|1986
''',
    extraOptions: const ['Dale Earnhardt', 'Rusty Wallace'],
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
1985 Daytona 500|Bill Elliott|1985
1984 Daytona 500|Cale Yarborough|1984
1983 Daytona 500|Cale Yarborough|1983
1982 Daytona 500|Bobby Allison|1982
1981 Daytona 500|Richard Petty|1981
1980 Daytona 500|Buddy Baker|1980
1979 Daytona 500|Richard Petty|1979
1978 Daytona 500|Bobby Allison|1978
1977 Daytona 500|Cale Yarborough|1977
1976 Daytona 500|David Pearson|1976
''',
    extraOptions: const ['Benny Parsons', 'Darrell Waltrip'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
1974 NASCAR Cup Series|Richard Petty|1974
1973 NASCAR Cup Series|Benny Parsons|1973
1972 NASCAR Cup Series|Richard Petty|1972
1971 NASCAR Cup Series|Richard Petty|1971
1970 NASCAR Cup Series|Bobby Isaac|1970
1969 NASCAR Cup Series|David Pearson|1969
1968 NASCAR Cup Series|David Pearson|1968
1967 NASCAR Cup Series|Richard Petty|1967
1966 NASCAR Cup Series|David Pearson|1966
1965 NASCAR Cup Series|Ned Jarrett|1965
''',
    extraOptions: const ['Cale Yarborough', 'Bobby Allison'],
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
1964 NASCAR Cup Series|Richard Petty|1964
1963 NASCAR Cup Series|Joe Weatherly|1963
1962 NASCAR Cup Series|Joe Weatherly|1962
1961 NASCAR Cup Series|Ned Jarrett|1961
1960 NASCAR Cup Series|Rex White|1960
1959 NASCAR Cup Series|Lee Petty|1959
1958 NASCAR Cup Series|Lee Petty|1958
1957 NASCAR Cup Series|Buck Baker|1957
1956 NASCAR Cup Series|Buck Baker|1956
1955 NASCAR Cup Series|Tim Flock|1955
''',
    extraOptions: const ['Herb Thomas', 'Fireball Roberts'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
1975 Daytona 500|Benny Parsons|1975
1974 Daytona 500|Richard Petty|1974
1973 Daytona 500|Richard Petty|1973
1972 Daytona 500|A. J. Foyt|1972
1971 Daytona 500|Richard Petty|1971
1970 Daytona 500|Pete Hamilton|1970
1969 Daytona 500|LeeRoy Yarbrough|1969
1968 Daytona 500|Cale Yarborough|1968
1967 Daytona 500|Mario Andretti|1967
1966 Daytona 500|Richard Petty|1966
''',
    extraOptions: const ['David Pearson', 'Bobby Allison'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'nascar',
    relation: 'race_winner',
    competition: 'Daytona 500',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
1965 Daytona 500|Fred Lorenzen|1965
1964 Daytona 500|Richard Petty|1964
1963 Daytona 500|Tiny Lund|1963
1962 Daytona 500|Fireball Roberts|1962
1961 Daytona 500|Marvin Panch|1961
1960 Daytona 500|Junior Johnson|1960
1959 Daytona 500|Lee Petty|1959
''',
    extraOptions: const ['Ned Jarrett', 'Rex White', 'Buck Baker'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
1954 NASCAR Cup Series|Lee Petty|1954
1953 NASCAR Cup Series|Herb Thomas|1953
1952 NASCAR Cup Series|Tim Flock|1952
''',
    extraOptions: const ['Bill Rexford', 'Red Byron', 'Buck Baker'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'nascar',
    relation: 'champion_driver',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
1951 NASCAR Cup Series|Herb Thomas|1951
1950 NASCAR Cup Series|Bill Rexford|1950
1949 NASCAR Cup Series|Red Byron|1949
''',
    extraOptions: const ['Lee Petty', 'Tim Flock', 'Curtis Turner'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'nascar',
    relation: 'record_holder',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-history', 'nascar-results'],
    data: '''
the most NASCAR Cup Series race wins|Richard Petty
the most Daytona 500 wins|Richard Petty
the most consecutive Cup Series titles|Jimmie Johnson
the youngest Daytona 500 winner|Trevor Bayne
the most Cup Series wins in one season|Richard Petty
the first NASCAR Cup Series champion|Red Byron
the oldest Daytona 500 winner|Bobby Allison
''',
    extraOptions: const ['Dale Earnhardt', 'Jeff Gordon'],
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'nascar',
    relation: 'circuit_city',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
Daytona International Speedway|Daytona Beach
Talladega Superspeedway|Talladega
Bristol Motor Speedway|Bristol
Darlington Raceway|Darlington
Charlotte Motor Speedway|Concord
Martinsville Speedway|Martinsville
Richmond Raceway|Richmond
Phoenix Raceway|Avondale
Las Vegas Motor Speedway|Las Vegas
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'nascar',
    relation: 'circuit_city',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
Homestead-Miami Speedway|Homestead
Sonoma Raceway|Sonoma
Michigan International Speedway|Brooklyn
Pocono Raceway|Long Pond
Kansas Speedway|Kansas City
Texas Motor Speedway|Fort Worth
Atlanta Motor Speedway|Hampton
Dover Motor Speedway|Dover
New Hampshire Motor Speedway|Loudon
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'nascar',
    relation: 'driver_manufacturer',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
Dale Earnhardt in 1994|Chevrolet
Jeff Gordon in 1998|Chevrolet
Jimmie Johnson in 2010|Chevrolet
Kyle Larson in 2021|Chevrolet
Joey Logano in 2022|Ford
Brad Keselowski in 2012|Dodge
Kyle Busch in 2019|Toyota
Martin Truex Jr in 2017|Toyota
Denny Hamlin in 2020|Toyota
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'nascar',
    relation: 'driver_manufacturer',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
Bill Elliott in 1988|Ford
Dale Jarrett in 1999|Ford
Rusty Wallace in 1989|Pontiac
Alan Kulwicki in 1992|Ford
Bobby Labonte in 2000|Pontiac
Tony Stewart in 2005|Chevrolet
Matt Kenseth in 2003|Ford
Kurt Busch in 2004|Ford
Ryan Blaney in 2023|Ford
''',
    extraOptions: const ['Toyota', 'Dodge'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'nascar',
    relation: 'driver_manufacturer',
    competition: 'NASCAR Cup Series',
    sources: const ['nascar-results', 'nascar-history'],
    data: '''
Richard Petty in 1972|Plymouth
Cale Yarborough in 1977|Chevrolet
David Pearson in 1969|Ford
Bobby Isaac in 1970|Dodge
Ned Jarrett in 1965|Ford
Rex White in 1960|Chevrolet
Lee Petty in 1959|Plymouth
Buck Baker in 1957|Chevrolet
Tim Flock in 1955|Chrysler
''',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INDYCAR — 180 facts (easy 40, medium 45, hard 45, global 50)
// The Indianapolis 500 has run since 1911, which gives band 5 real depth.
// ─────────────────────────────────────────────────────────────────────────────

void _addIndyCarFacts() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
2025 Indianapolis 500|Álex Palou|2025
2024 Indianapolis 500|Josef Newgarden|2024
2023 Indianapolis 500|Josef Newgarden|2023
2022 Indianapolis 500|Marcus Ericsson|2022
2021 Indianapolis 500|Hélio Castroneves|2021
2020 Indianapolis 500|Takuma Sato|2020
2019 Indianapolis 500|Simon Pagenaud|2019
2018 Indianapolis 500|Will Power|2018
''',
    extraOptions: const ['Scott Dixon', 'Alexander Rossi'],
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
2017 Indianapolis 500|Takuma Sato|2017
2016 Indianapolis 500|Alexander Rossi|2016
2015 Indianapolis 500|Juan Pablo Montoya|2015
2014 Indianapolis 500|Ryan Hunter-Reay|2014
2013 Indianapolis 500|Tony Kanaan|2013
2012 Indianapolis 500|Dario Franchitti|2012
2011 Indianapolis 500|Dan Wheldon|2011
2010 Indianapolis 500|Dario Franchitti|2010
''',
    extraOptions: const ['Will Power', 'Scott Dixon'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
2009 Indianapolis 500|Hélio Castroneves|2009
2008 Indianapolis 500|Scott Dixon|2008
2007 Indianapolis 500|Dario Franchitti|2007
2006 Indianapolis 500|Sam Hornish Jr|2006
2005 Indianapolis 500|Dan Wheldon|2005
2004 Indianapolis 500|Buddy Rice|2004
2003 Indianapolis 500|Gil de Ferran|2003
2002 Indianapolis 500|Hélio Castroneves|2002
''',
    extraOptions: const ['Tony Kanaan', 'Buddy Lazier'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
2001 Indianapolis 500|Hélio Castroneves|2001
2000 Indianapolis 500|Juan Pablo Montoya|2000
1999 Indianapolis 500|Kenny Bräck|1999
1998 Indianapolis 500|Eddie Cheever|1998
1997 Indianapolis 500|Arie Luyendyk|1997
1996 Indianapolis 500|Buddy Lazier|1996
1995 Indianapolis 500|Jacques Villeneuve|1995
1994 Indianapolis 500|Al Unser Jr|1994
''',
    extraOptions: const ['Scott Goodyear', 'Michael Andretti'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1993 Indianapolis 500|Emerson Fittipaldi|1993
1992 Indianapolis 500|Al Unser Jr|1992
1991 Indianapolis 500|Rick Mears|1991
1990 Indianapolis 500|Arie Luyendyk|1990
1989 Indianapolis 500|Emerson Fittipaldi|1989
1988 Indianapolis 500|Rick Mears|1988
1987 Indianapolis 500|Al Unser|1987
1986 Indianapolis 500|Bobby Rahal|1986
''',
    extraOptions: const ['Danny Sullivan', 'Mario Andretti'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'indycar',
    relation: 'champion_driver',
    competition: 'IndyCar Series',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
2025 IndyCar Series|Álex Palou|2025
2024 IndyCar Series|Álex Palou|2024
2023 IndyCar Series|Álex Palou|2023
2022 IndyCar Series|Will Power|2022
2021 IndyCar Series|Álex Palou|2021
2020 IndyCar Series|Scott Dixon|2020
2019 IndyCar Series|Josef Newgarden|2019
2018 IndyCar Series|Scott Dixon|2018
2017 IndyCar Series|Josef Newgarden|2017
''',
    extraOptions: const ['Simon Pagenaud', 'Pato O\'Ward'],
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'indycar',
    relation: 'champion_driver',
    competition: 'IndyCar Series',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
2016 IndyCar Series|Simon Pagenaud|2016
2015 IndyCar Series|Scott Dixon|2015
2014 IndyCar Series|Will Power|2014
2013 IndyCar Series|Scott Dixon|2013
2012 IndyCar Series|Ryan Hunter-Reay|2012
2011 IndyCar Series|Dario Franchitti|2011
2010 IndyCar Series|Dario Franchitti|2010
2009 IndyCar Series|Dario Franchitti|2009
2008 IndyCar Series|Scott Dixon|2008
''',
    extraOptions: const ['Hélio Castroneves', 'Tony Kanaan'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'indycar',
    relation: 'champion_driver',
    competition: 'IndyCar Series',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
2007 IndyCar Series|Dario Franchitti|2007
2006 IndyCar Series|Sam Hornish Jr|2006
2005 IndyCar Series|Dan Wheldon|2005
2004 IndyCar Series|Tony Kanaan|2004
2003 IndyCar Series|Scott Dixon|2003
2002 IndyCar Series|Sam Hornish Jr|2002
2001 IndyCar Series|Sam Hornish Jr|2001
''',
    extraOptions: const ['Buddy Rice', 'Gil de Ferran', 'Gil Wheldon'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'indycar',
    relation: 'first_year',
    competition: 'IndyCar',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
the Indianapolis 500|1911
the Indy Racing League|1996
''',
    extraOptions: const ['1946', '1979', '2008'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1985 Indianapolis 500|Danny Sullivan|1985
1984 Indianapolis 500|Rick Mears|1984
1983 Indianapolis 500|Tom Sneva|1983
1982 Indianapolis 500|Gordon Johncock|1982
1981 Indianapolis 500|Bobby Unser|1981
1980 Indianapolis 500|Johnny Rutherford|1980
1979 Indianapolis 500|Rick Mears|1979
1978 Indianapolis 500|Al Unser|1978
1977 Indianapolis 500|A. J. Foyt|1977
''',
    extraOptions: const ['Mario Andretti', 'Gordon Smiley'],
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1976 Indianapolis 500|Johnny Rutherford|1976
1975 Indianapolis 500|Bobby Unser|1975
1974 Indianapolis 500|Johnny Rutherford|1974
1973 Indianapolis 500|Gordon Johncock|1973
1972 Indianapolis 500|Mark Donohue|1972
1971 Indianapolis 500|Al Unser|1971
1970 Indianapolis 500|Al Unser|1970
1969 Indianapolis 500|Mario Andretti|1969
1968 Indianapolis 500|Bobby Unser|1968
''',
    extraOptions: const ['A. J. Foyt', 'Parnelli Jones'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1967 Indianapolis 500|A. J. Foyt|1967
1966 Indianapolis 500|Graham Hill|1966
1965 Indianapolis 500|Jim Clark|1965
1964 Indianapolis 500|A. J. Foyt|1964
1963 Indianapolis 500|Parnelli Jones|1963
1962 Indianapolis 500|Rodger Ward|1962
1961 Indianapolis 500|A. J. Foyt|1961
1960 Indianapolis 500|Jim Rathmann|1960
1959 Indianapolis 500|Rodger Ward|1959
''',
    extraOptions: const ['Jimmy Bryan', 'Eddie Sachs'],
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1958 Indianapolis 500|Jimmy Bryan|1958
1957 Indianapolis 500|Sam Hanks|1957
1956 Indianapolis 500|Pat Flaherty|1956
1955 Indianapolis 500|Bob Sweikert|1955
1954 Indianapolis 500|Bill Vukovich|1954
1953 Indianapolis 500|Bill Vukovich|1953
1952 Indianapolis 500|Troy Ruttman|1952
1951 Indianapolis 500|Lee Wallard|1951
1950 Indianapolis 500|Johnnie Parsons|1950
''',
    extraOptions: const ['Rodger Ward', 'Jim Rathmann'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'indycar',
    relation: 'driver_nationality',
    competition: 'IndyCar',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
Dan Wheldon|United Kingdom
Kenny Bräck|Sweden
Gil de Ferran|Brazil
Sam Hornish Jr|United States
Buddy Rice|United States
Arie Luyendyk|Netherlands
Rick Mears|United States
Al Unser|United States
Bobby Unser|United States
''',
    extraOptions: const ['Brazil', 'Spain'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'indycar',
    relation: 'driver_nationality',
    competition: 'IndyCar',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
A. J. Foyt|United States
Johnny Rutherford|United States
Bobby Rahal|United States
Danny Sullivan|United States
Parnelli Jones|United States
Rodger Ward|United States
Pato O'Ward|Mexico
Christian Lundgaard|Denmark
Felix Rosenqvist|Sweden
''',
    extraOptions: const ['Canada', 'Australia'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'indycar',
    relation: 'record_holder',
    competition: 'IndyCar',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
the most IndyCar Series championships|Scott Dixon
the first Indianapolis 500 winner|Ray Harroun
the most Indianapolis 500 starts|A. J. Foyt
the most IndyCar career race wins|A. J. Foyt
the youngest Indianapolis 500 winner|Troy Ruttman
the oldest Indianapolis 500 winner|Al Unser
the first back-to-back Indy 500 winner|Wilbur Shaw
the most Indianapolis 500 pole positions|Rick Mears
the first woman to lead the Indy 500|Danica Patrick
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'indycar',
    relation: 'driver_nationality',
    competition: 'IndyCar',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
Álex Palou|Spain
Scott Dixon|New Zealand
Hélio Castroneves|Brazil
Dario Franchitti|United Kingdom
Tony Kanaan|Brazil
Will Power|Australia
Josef Newgarden|United States
Simon Pagenaud|France
Alexander Rossi|United States
Ryan Hunter-Reay|United States
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'indycar',
    relation: 'circuit_city',
    competition: 'IndyCar Series',
    sources: const ['indycar-results', 'indy500-history'],
    data: '''
the Indianapolis Motor Speedway|Speedway
Long Beach street circuit|Long Beach
Barber Motorsports Park|Birmingham
Road America|Elkhart Lake
Mid-Ohio Sports Car Course|Lexington
World Wide Technology Raceway|Madison
Iowa Speedway|Newton
Portland International Raceway|Portland
Laguna Seca|Monterey
the Streets of St. Petersburg|St. Petersburg
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1948 Indianapolis 500|Mauri Rose|1948
1947 Indianapolis 500|Mauri Rose|1947
1946 Indianapolis 500|George Robson|1946
1940 Indianapolis 500|Wilbur Shaw|1940
1939 Indianapolis 500|Wilbur Shaw|1939
1938 Indianapolis 500|Floyd Roberts|1938
1937 Indianapolis 500|Wilbur Shaw|1937
1936 Indianapolis 500|Louis Meyer|1936
1935 Indianapolis 500|Kelly Petillo|1935
1934 Indianapolis 500|Bill Cummings|1934
''',
    extraOptions: const ['Ted Horn', 'Rex Mays'],
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1933 Indianapolis 500|Louis Meyer|1933
1932 Indianapolis 500|Fred Frame|1932
1931 Indianapolis 500|Louis Schneider|1931
1930 Indianapolis 500|Billy Arnold|1930
1929 Indianapolis 500|Ray Keech|1929
1928 Indianapolis 500|Louis Meyer|1928
1927 Indianapolis 500|George Souders|1927
1926 Indianapolis 500|Frank Lockhart|1926
1925 Indianapolis 500|Peter DePaolo|1925
1923 Indianapolis 500|Tommy Milton|1923
''',
    extraOptions: const ['Harry Hartz', 'Leon Duray'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'indycar',
    relation: 'race_winner',
    competition: 'Indianapolis 500',
    sources: const ['indy500-history', 'indycar-results'],
    data: '''
1922 Indianapolis 500|Jimmy Murphy|1922
1921 Indianapolis 500|Tommy Milton|1921
1920 Indianapolis 500|Gaston Chevrolet|1920
1919 Indianapolis 500|Howdy Wilcox|1919
1916 Indianapolis 500|Dario Resta|1916
1915 Indianapolis 500|Ralph DePalma|1915
1914 Indianapolis 500|René Thomas|1914
1913 Indianapolis 500|Jules Goux|1913
1912 Indianapolis 500|Joe Dawson|1912
1911 Indianapolis 500|Ray Harroun|1911
''',
    extraOptions: const ['Barney Oldfield', 'Eddie Rickenbacker'],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ENDURANCE — 200 facts (easy 30, medium 40, hard 45, global 85)
// Anchored on the 24 Hours of Le Mans, run since 1923, which reaches further
// back than any other event in this bank.
// ─────────────────────────────────────────────────────────────────────────────

void _addEnduranceFacts() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
2025 24 Hours of Le Mans|Ferrari|2025
2024 24 Hours of Le Mans|Ferrari|2024
2023 24 Hours of Le Mans|Ferrari|2023
2022 24 Hours of Le Mans|Toyota|2022
2021 24 Hours of Le Mans|Toyota|2021
2020 24 Hours of Le Mans|Toyota|2020
''',
    extraOptions: const ['Porsche', 'Audi', 'Peugeot'],
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
2019 24 Hours of Le Mans|Toyota|2019
2018 24 Hours of Le Mans|Toyota|2018
2017 24 Hours of Le Mans|Porsche|2017
2016 24 Hours of Le Mans|Porsche|2016
2015 24 Hours of Le Mans|Porsche|2015
2014 24 Hours of Le Mans|Audi|2014
''',
    extraOptions: const ['Ferrari', 'Peugeot', 'Nissan'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
2013 24 Hours of Le Mans|Audi|2013
2012 24 Hours of Le Mans|Audi|2012
2011 24 Hours of Le Mans|Audi|2011
2010 24 Hours of Le Mans|Audi|2010
2009 24 Hours of Le Mans|Peugeot|2009
2008 24 Hours of Le Mans|Audi|2008
''',
    extraOptions: const ['Porsche', 'Toyota', 'Aston Martin'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
2007 24 Hours of Le Mans|Audi|2007
2006 24 Hours of Le Mans|Audi|2006
2005 24 Hours of Le Mans|Audi|2005
2004 24 Hours of Le Mans|Audi|2004
2003 24 Hours of Le Mans|Bentley|2003
2002 24 Hours of Le Mans|Audi|2002
''',
    extraOptions: const ['Porsche', 'Cadillac', 'Panoz'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
2001 24 Hours of Le Mans|Audi|2001
2000 24 Hours of Le Mans|Audi|2000
1999 24 Hours of Le Mans|BMW|1999
1998 24 Hours of Le Mans|Porsche|1998
1997 24 Hours of Le Mans|Porsche|1997
1996 24 Hours of Le Mans|Porsche|1996
''',
    extraOptions: const ['Toyota', 'Nissan', 'Mercedes-Benz'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1995 24 Hours of Le Mans|McLaren|1995
1994 24 Hours of Le Mans|Porsche|1994
1993 24 Hours of Le Mans|Peugeot|1993
1992 24 Hours of Le Mans|Peugeot|1992
1991 24 Hours of Le Mans|Mazda|1991
1990 24 Hours of Le Mans|Jaguar|1990
1989 24 Hours of Le Mans|Mercedes-Benz|1989
1988 24 Hours of Le Mans|Jaguar|1988
''',
    extraOptions: const ['Toyota', 'Nissan'],
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1987 24 Hours of Le Mans|Porsche|1987
1986 24 Hours of Le Mans|Porsche|1986
1985 24 Hours of Le Mans|Porsche|1985
1984 24 Hours of Le Mans|Porsche|1984
1983 24 Hours of Le Mans|Porsche|1983
1982 24 Hours of Le Mans|Porsche|1982
1981 24 Hours of Le Mans|Porsche|1981
1980 24 Hours of Le Mans|Rondeau|1980
''',
    extraOptions: const ['Lancia', 'Jaguar', 'Sauber'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1979 24 Hours of Le Mans|Porsche|1979
1978 24 Hours of Le Mans|Renault|1978
1977 24 Hours of Le Mans|Porsche|1977
1976 24 Hours of Le Mans|Porsche|1976
1975 24 Hours of Le Mans|Gulf-Mirage|1975
1974 24 Hours of Le Mans|Matra-Simca|1974
1973 24 Hours of Le Mans|Matra-Simca|1973
1972 24 Hours of Le Mans|Matra-Simca|1972
''',
    extraOptions: const ['Alfa Romeo', 'Ferrari'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1971 24 Hours of Le Mans|Porsche|1971
1970 24 Hours of Le Mans|Porsche|1970
1969 24 Hours of Le Mans|Ford|1969
1968 24 Hours of Le Mans|Ford|1968
1967 24 Hours of Le Mans|Ford|1967
1966 24 Hours of Le Mans|Ford|1966
1965 24 Hours of Le Mans|Ferrari|1965
1964 24 Hours of Le Mans|Ferrari|1964
''',
    extraOptions: const ['Chaparral', 'Matra'],
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1963 24 Hours of Le Mans|Ferrari|1963
1962 24 Hours of Le Mans|Ferrari|1962
1961 24 Hours of Le Mans|Ferrari|1961
1960 24 Hours of Le Mans|Ferrari|1960
1959 24 Hours of Le Mans|Aston Martin|1959
1958 24 Hours of Le Mans|Ferrari|1958
1957 24 Hours of Le Mans|Jaguar|1957
1956 24 Hours of Le Mans|Jaguar|1956
''',
    extraOptions: const ['Maserati', 'Porsche'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1955 24 Hours of Le Mans|Jaguar|1955
1954 24 Hours of Le Mans|Ferrari|1954
1953 24 Hours of Le Mans|Jaguar|1953
1952 24 Hours of Le Mans|Mercedes-Benz|1952
1951 24 Hours of Le Mans|Jaguar|1951
1950 24 Hours of Le Mans|Talbot-Lago|1950
1949 24 Hours of Le Mans|Ferrari|1949
''',
    extraOptions: const ['Aston Martin', 'Cunningham'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'endurance',
    relation: 'record_holder',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
the most outright Le Mans wins by a driver|Tom Kristensen
the most outright Le Mans wins by a marque|Porsche
''',
    extraOptions: const ['Jacky Ickx', 'Audi', 'Ferrari'],
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1939 24 Hours of Le Mans|Bugatti|1939
1938 24 Hours of Le Mans|Delahaye|1938
1937 24 Hours of Le Mans|Bugatti|1937
1935 24 Hours of Le Mans|Lagonda|1935
1934 24 Hours of Le Mans|Alfa Romeo|1934
1933 24 Hours of Le Mans|Alfa Romeo|1933
1932 24 Hours of Le Mans|Alfa Romeo|1932
1931 24 Hours of Le Mans|Alfa Romeo|1931
1930 24 Hours of Le Mans|Bentley|1930
''',
    extraOptions: const ['Talbot', 'Bugatti Type 57'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'endurance',
    relation: 'race_winning_team',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
1929 24 Hours of Le Mans|Bentley|1929
1928 24 Hours of Le Mans|Bentley|1928
1927 24 Hours of Le Mans|Bentley|1927
1926 24 Hours of Le Mans|Lorraine-Dietrich|1926
1925 24 Hours of Le Mans|Lorraine-Dietrich|1925
1924 24 Hours of Le Mans|Bentley|1924
1923 24 Hours of Le Mans|Chenard et Walcker|1923
''',
    extraOptions: const ['Bugatti', 'Alfa Romeo', 'Delahaye'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'endurance',
    relation: 'record_holder',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
the most consecutive Le Mans wins by a driver|Tom Kristensen
the first diesel-powered Le Mans winner|Audi
''',
    extraOptions: const ['Derek Bell', 'Peugeot', 'Porsche'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'endurance',
    relation: 'driver_nationality',
    competition: '24 Hours of Le Mans',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
Tom Kristensen|Denmark
Derek Bell|United Kingdom
Allan McNish|United Kingdom
Emanuele Pirro|Italy
Frank Biela|Germany
Rinaldo Capello|Italy
André Lotterer|Germany
Benoît Tréluyer|France
Marcel Fässler|Switzerland
''',
    extraOptions: const ['Japan', 'Belgium'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'endurance',
    relation: 'record_holder',
    competition: 'endurance racing',
    sources: const ['lemans-history', 'imsa-results'],
    data: '''
the first Japanese marque to win Le Mans|Mazda
the first hybrid car to win Le Mans|Audi
the most Le Mans wins by a British marque|Jaguar
the first rotary-engined Le Mans winner|Mazda
the marque with the most Le Mans class wins|Porsche
the first mid-engined Le Mans winner|Ferrari
the first American marque to win Le Mans|Ford
the first Le Mans winner using a turbo engine|Renault
the first Italian marque to win Le Mans|Alfa Romeo
''',
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'endurance',
    relation: 'venue',
    competition: 'endurance racing',
    sources: const ['fiawec-results', 'imsa-results'],
    data: '''
the 24 Hours of Le Mans|Circuit de la Sarthe
the 12 Hours of Sebring|Sebring International Raceway
the 24 Hours of Daytona|Daytona International Speedway
the Petit Le Mans|Road Atlanta
the 24 Hours of Spa|Spa-Francorchamps
the Nürburgring 24 Hours|the Nürburgring
the 6 Hours of Fuji|Fuji Speedway
the 6 Hours of Monza|Autodromo Nazionale Monza
the 6 Hours of Imola|Imola
the 8 Hours of Bahrain|Bahrain International Circuit
the 6 Hours of Portimão|the Portimão circuit
the Bathurst 12 Hour|Mount Panorama
the 6 Hours of São Paulo|Interlagos
the 6 Hours of Austin|Circuit of the Americas
the 6 Hours of Shanghai|Shanghai International Circuit
the 6 Hours of Silverstone|Silverstone Circuit
the 6 Hours of Watkins Glen|Watkins Glen International
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'endurance',
    relation: 'class_name',
    competition: 'endurance racing',
    sources: const ['fiawec-results', 'lemans-history'],
    data: '''
the Toyota GR010 Hybrid|Hypercar
the Porsche 963|Hypercar
the Ferrari 499P|Hypercar
the Cadillac V-Series.R|Hypercar
the Peugeot 9X8|Hypercar
the BMW M Hybrid V8|Hypercar
the Oreca 07|LMP2
the Ligier JS P217|LMP2
the Porsche 911 RSR|LMGTE
the Ferrari 488 GTE|LMGTE
the Aston Martin Vantage AMR|LMGTE
the Chevrolet Corvette C8.R|LMGTE
the Audi R18 e-tron quattro|LMP1
the Porsche 919 Hybrid|LMP1
the Toyota TS050 Hybrid|LMP1
the Audi R10 TDI|LMP1
the Peugeot 908 HDi FAP|LMP1
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'endurance',
    relation: 'driver_nationality',
    competition: 'endurance racing',
    sources: const ['fiawec-results', 'lemans-history'],
    data: '''
Timo Bernhard|Germany
Earl Bamber|New Zealand
Nick Tandy|United Kingdom
Neel Jani|Switzerland
Romain Dumas|France
Kazuki Nakajima|Japan
Mike Conway|United Kingdom
José María López|Argentina
Alessandro Pier Guidi|Italy
James Calado|United Kingdom
Nicklas Nielsen|Denmark
Yifei Ye|China
Phil Hanson|United Kingdom
Olivier Gendebien|Belgium
Henri Pescarolo|France
Klaus Ludwig|Germany
Jan Lammers|Netherlands
''',
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'endurance',
    relation: 'first_year',
    competition: 'endurance racing',
    sources: const ['lemans-history', 'imsa-results'],
    data: '''
the 24 Hours of Le Mans|1923
the 12 Hours of Sebring|1952
the 24 Hours of Daytona|1962
the FIA World Endurance Championship|2012
the Nürburgring 24 Hours|1970
the 24 Hours of Spa|1924
the Bathurst 12 Hour|1991
the Petit Le Mans|1998
the American Le Mans Series|1999
''',
    extraOptions: const ['1934', '1975', '2006'],
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'endurance',
    relation: 'driver_nationality',
    competition: 'endurance racing',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
Gérard Larrousse|France
Hans-Joachim Stuck|Germany
Jochen Mass|Germany
Yannick Dalmas|France
Andy Wallace|United Kingdom
Ken Miles|United Kingdom
Carroll Shelby|United States
Luigi Chinetti|Italy
''',
    extraOptions: const ['Denmark', 'Japan'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'endurance',
    relation: 'class_name',
    competition: 'endurance racing',
    sources: const ['lemans-history', 'fiawec-results'],
    data: '''
the Porsche 956|Group C
the Porsche 962C|Group C
the Jaguar XJR-9|Group C
the Sauber-Mercedes C9|Group C
the Peugeot 905|Group C
the Mazda 787B|Group C
the Ford GT40|prototype sports car
the Ferrari 250 LM|prototype sports car
the Porsche 917|prototype sports car
the Matra MS670|prototype sports car
the Audi R8 sports prototype|LMP900
the Panoz LMP-1 Roadster|LMP900
the Bentley Speed 8|LMGTP
the Porsche 911 GT1|GT1
the McLaren F1 GTR|GT1
the Nissan R390 GT1|GT1
the Chrysler Viper GTS-R|GT2
''',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RALLY — 115 facts (easy 15, medium 15, hard 25, global 60)
// WRC titles run 1973-2024 here; the 2025 season is left out because it falls
// after the bank's factual cutoff for this scope.
// ─────────────────────────────────────────────────────────────────────────────

void _addRallyFacts() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2024 World Rally Championship|Thierry Neuville|2024
2023 World Rally Championship|Kalle Rovanperä|2023
2022 World Rally Championship|Kalle Rovanperä|2022
''',
    extraOptions: const ['Ott Tänak', 'Elfyn Evans', 'Sébastien Ogier'],
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2021 World Rally Championship|Sébastien Ogier|2021
2020 World Rally Championship|Sébastien Ogier|2020
2019 World Rally Championship|Ott Tänak|2019
''',
    extraOptions: const ['Thierry Neuville', 'Elfyn Evans', 'Kalle Rovanperä'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2018 World Rally Championship|Sébastien Ogier|2018
2017 World Rally Championship|Sébastien Ogier|2017
2016 World Rally Championship|Sébastien Ogier|2016
''',
    extraOptions: const ['Thierry Neuville', 'Jari-Matti Latvala', 'Ott Tänak'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2015 World Rally Championship|Sébastien Ogier|2015
2014 World Rally Championship|Sébastien Ogier|2014
2013 World Rally Championship|Sébastien Ogier|2013
''',
    extraOptions: const ['Sébastien Loeb', 'Mikko Hirvonen', 'Jari-Matti Latvala'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2012 World Rally Championship|Sébastien Loeb|2012
2011 World Rally Championship|Sébastien Loeb|2011
2010 World Rally Championship|Sébastien Loeb|2010
''',
    extraOptions: const ['Mikko Hirvonen', 'Petter Solberg', 'Marcus Grönholm'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2009 World Rally Championship|Sébastien Loeb|2009
2008 World Rally Championship|Sébastien Loeb|2008
2007 World Rally Championship|Sébastien Loeb|2007
''',
    extraOptions: const ['Marcus Grönholm', 'Mikko Hirvonen', 'Petter Solberg'],
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2006 World Rally Championship|Sébastien Loeb|2006
2005 World Rally Championship|Sébastien Loeb|2005
2004 World Rally Championship|Sébastien Loeb|2004
''',
    extraOptions: const ['Petter Solberg', 'Marcus Grönholm', 'Markko Märtin'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2003 World Rally Championship|Petter Solberg|2003
2002 World Rally Championship|Marcus Grönholm|2002
2001 World Rally Championship|Richard Burns|2001
''',
    extraOptions: const ['Colin McRae', 'Tommi Mäkinen', 'Carlos Sainz'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2000 World Rally Championship|Marcus Grönholm|2000
1999 World Rally Championship|Tommi Mäkinen|1999
1998 World Rally Championship|Tommi Mäkinen|1998
''',
    extraOptions: const ['Richard Burns', 'Colin McRae', 'Didier Auriol'],
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
1997 World Rally Championship|Tommi Mäkinen|1997
1996 World Rally Championship|Tommi Mäkinen|1996
1995 World Rally Championship|Colin McRae|1995
''',
    extraOptions: const ['Carlos Sainz', 'Didier Auriol', 'Juha Kankkunen'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
1994 World Rally Championship|Didier Auriol|1994
1993 World Rally Championship|Juha Kankkunen|1993
1992 World Rally Championship|Carlos Sainz|1992
1991 World Rally Championship|Juha Kankkunen|1991
1990 World Rally Championship|Carlos Sainz|1990
''',
    extraOptions: const ['Massimo Biasion', 'Colin McRae'],
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
1989 World Rally Championship|Massimo Biasion|1989
1988 World Rally Championship|Massimo Biasion|1988
1987 World Rally Championship|Juha Kankkunen|1987
1986 World Rally Championship|Juha Kankkunen|1986
1985 World Rally Championship|Timo Salonen|1985
''',
    extraOptions: const ['Markku Alén', 'Walter Röhrl'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'rally',
    relation: 'champion_driver',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
1984 World Rally Championship|Stig Blomqvist|1984
1983 World Rally Championship|Hannu Mikkola|1983
1982 World Rally Championship|Walter Röhrl|1982
1981 World Rally Championship|Ari Vatanen|1981
1980 World Rally Championship|Walter Röhrl|1980
''',
    extraOptions: const ['Björn Waldegård', 'Markku Alén'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'rally',
    relation: 'champion_manufacturer',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2024 World Rally Championship|Toyota|2024
2023 World Rally Championship|Toyota|2023
2022 World Rally Championship|Toyota|2022
2021 World Rally Championship|Toyota|2021
2020 World Rally Championship|Hyundai|2020
''',
    extraOptions: const ['Ford', 'Citroën', 'Volkswagen'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'rally',
    relation: 'champion_manufacturer',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2019 World Rally Championship|Hyundai|2019
2018 World Rally Championship|Toyota|2018
2016 World Rally Championship|Volkswagen|2016
2015 World Rally Championship|Volkswagen|2015
2014 World Rally Championship|Volkswagen|2014
''',
    extraOptions: const ['Citroën', 'Ford', 'Peugeot'],
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'rally',
    relation: 'driver_nationality',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
Sébastien Loeb|France
Sébastien Ogier|France
Kalle Rovanperä|Finland
Thierry Neuville|Belgium
Ott Tänak|Estonia
Colin McRae|United Kingdom
Tommi Mäkinen|Finland
Marcus Grönholm|Finland
Richard Burns|United Kingdom
Petter Solberg|Norway
Juha Kankkunen|Finland
Walter Röhrl|Germany
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'rally',
    relation: 'race_winner',
    competition: 'Dakar Rally',
    sources: const ['dakar-history', 'wrc-results'],
    data: '''
2025 Dakar Rally car category|Yazeed Al-Rajhi|2025
2024 Dakar Rally car category|Carlos Sainz|2024
2023 Dakar Rally car category|Nasser Al-Attiyah|2023
2022 Dakar Rally car category|Nasser Al-Attiyah|2022
2021 Dakar Rally car category|Stéphane Peterhansel|2021
2020 Dakar Rally car category|Carlos Sainz|2020
2019 Dakar Rally car category|Nasser Al-Attiyah|2019
2018 Dakar Rally car category|Carlos Sainz|2018
2017 Dakar Rally car category|Stéphane Peterhansel|2017
2016 Dakar Rally car category|Stéphane Peterhansel|2016
2015 Dakar Rally car category|Nasser Al-Attiyah|2015
2014 Dakar Rally car category|Nani Roma|2014
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'rally',
    relation: 'champion_manufacturer',
    competition: 'World Rally Championship',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
2013 World Rally Championship|Volkswagen|2013
2012 World Rally Championship|Citroën|2012
2011 World Rally Championship|Citroën|2011
2010 World Rally Championship|Citroën|2010
2009 World Rally Championship|Citroën|2009
2008 World Rally Championship|Citroën|2008
2007 World Rally Championship|Ford|2007
2006 World Rally Championship|Ford|2006
2005 World Rally Championship|Citroën|2005
2004 World Rally Championship|Citroën|2004
2003 World Rally Championship|Citroën|2003
2002 World Rally Championship|Peugeot|2002
''',
    extraOptions: const ['Subaru', 'Mitsubishi'],
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'rally',
    relation: 'series_home',
    competition: 'rallying',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
the Monte Carlo Rally|Monaco
the Acropolis Rally|Greece
the Safari Rally|Kenya
the Rally of the 1000 Lakes|Finland
the Rally Sanremo|Italy
the RAC Rally|United Kingdom
the Tour de Corse|France
the Rally Catalunya|Spain
the Ypres Rally|Belgium
the Baja 1000|Mexico
the Pikes Peak Hill Climb|United States
the Rallye Deutschland|Germany
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'rally',
    relation: 'record_holder',
    competition: 'rallying',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
the most World Rally Championship titles|Sébastien Loeb
the most WRC rally victories|Sébastien Loeb
the most Dakar Rally car victories|Stéphane Peterhansel
the youngest WRC world champion|Kalle Rovanperä
the first WRC world champion|Björn Waldegård
the most WRC titles won by a manufacturer|Lancia
''',
    extraOptions: const ['Sébastien Ogier', 'Citroën', 'Carlos Sainz'],
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'rally',
    relation: 'first_year',
    competition: 'rallying',
    sources: const ['wrc-results', 'dakar-history'],
    data: '''
the World Rally Championship|1973
the Dakar Rally|1979
the Monte Carlo Rally|1911
the Safari Rally|1953
the Acropolis Rally|1951
the Pikes Peak Hill Climb|1916
''',
    extraOptions: const ['1962', '1988'],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FEEDER AND OTHER SERIES — 80 facts (easy 10, medium 10, hard 15, global 45)
// Formula E, Formula 2 / GP2, FIA Formula 3 and the wider world of racing.
// ─────────────────────────────────────────────────────────────────────────────

void _addFeederFacts() {
  _addRows(
    mode: 'easy',
    band: 1,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'Formula E World Championship',
    sources: const ['formulae-results', 'fia-championship-records'],
    data: '''
2024-25 Formula E|Oliver Rowland|2025
2023-24 Formula E|Pascal Wehrlein|2024
''',
    extraOptions: const ['Jake Dennis', 'Mitch Evans', 'Nick Cassidy'],
  );
  _addRows(
    mode: 'easy',
    band: 2,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'Formula E World Championship',
    sources: const ['formulae-results', 'fia-championship-records'],
    data: '''
2022-23 Formula E|Jake Dennis|2023
2021-22 Formula E|Stoffel Vandoorne|2022
''',
    extraOptions: const ['Nyck de Vries', 'Mitch Evans', 'Edoardo Mortara'],
  );
  _addRows(
    mode: 'easy',
    band: 3,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'Formula E World Championship',
    sources: const ['formulae-results', 'fia-championship-records'],
    data: '''
2020-21 Formula E|Nyck de Vries|2021
2019-20 Formula E|António Félix da Costa|2020
''',
    extraOptions: const ['Jean-Éric Vergne', 'Lucas di Grassi', 'Sam Bird'],
  );
  _addRows(
    mode: 'easy',
    band: 4,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'Formula E Championship',
    sources: const ['formulae-results', 'fia-championship-records'],
    data: '''
2018-19 Formula E|Jean-Éric Vergne|2019
2017-18 Formula E|Jean-Éric Vergne|2018
''',
    extraOptions: const ['Lucas di Grassi', 'Sébastien Buemi', 'Sam Bird'],
  );
  _addRows(
    mode: 'easy',
    band: 5,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'Formula E Championship',
    sources: const ['formulae-results', 'fia-championship-records'],
    data: '''
2016-17 Formula E|Lucas di Grassi|2017
2015-16 Formula E|Sébastien Buemi|2016
''',
    extraOptions: const ['Nelson Piquet Jr', 'Jean-Éric Vergne', 'Sam Bird'],
  );
  _addRows(
    mode: 'medium',
    band: 1,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'FIA Formula 2 Championship',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2024 Formula 2|Gabriel Bortoleto|2024
2023 Formula 2|Théo Pourchaire|2023
''',
    extraOptions: const ['Isack Hadjar', 'Frederik Vesti', 'Ayumu Iwasa'],
  );
  _addRows(
    mode: 'medium',
    band: 2,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'FIA Formula 2 Championship',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2022 Formula 2|Felipe Drugovich|2022
2021 Formula 2|Oscar Piastri|2021
''',
    extraOptions: const ['Théo Pourchaire', 'Liam Lawson', 'Guanyu Zhou'],
  );
  _addRows(
    mode: 'medium',
    band: 3,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'FIA Formula 2 Championship',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2020 Formula 2|Mick Schumacher|2020
2019 Formula 2|Nyck de Vries|2019
''',
    extraOptions: const ['Callum Ilott', 'Nicholas Latifi', 'Yuki Tsunoda'],
  );
  _addRows(
    mode: 'medium',
    band: 4,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'FIA Formula 2 Championship',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2018 Formula 2|George Russell|2018
2017 Formula 2|Charles Leclerc|2017
''',
    extraOptions: const ['Lando Norris', 'Alexander Albon', 'Artem Markelov'],
  );
  _addRows(
    mode: 'medium',
    band: 5,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'GP2 Series',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2016 GP2 Series|Pierre Gasly|2016
2015 GP2 Series|Stoffel Vandoorne|2015
''',
    extraOptions: const ['Antonio Giovinazzi', 'Alex Lynn', 'Sergey Sirotkin'],
  );
  _addRows(
    mode: 'hard',
    band: 1,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'GP2 Series',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2014 GP2 Series|Jolyon Palmer|2014
2013 GP2 Series|Fabio Leimer|2013
2012 GP2 Series|Davide Valsecchi|2012
''',
    extraOptions: const ['Felipe Nasr', 'Sam Bird', 'James Calado'],
  );
  _addRows(
    mode: 'hard',
    band: 2,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'GP2 Series',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2011 GP2 Series|Romain Grosjean|2011
2010 GP2 Series|Pastor Maldonado|2010
2009 GP2 Series|Nico Hülkenberg|2009
''',
    extraOptions: const ['Sergio Pérez', 'Jules Bianchi', 'Luca Filippi'],
  );
  _addRows(
    mode: 'hard',
    band: 3,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'GP2 Series',
    sources: const ['formula2-results', 'fia-championship-records'],
    data: '''
2008 GP2 Series|Giorgio Pantano|2008
2007 GP2 Series|Timo Glock|2007
2006 GP2 Series|Lewis Hamilton|2006
''',
    extraOptions: const ['Nelson Piquet Jr', 'Bruno Senna', 'Lucas di Grassi'],
  );
  _addRows(
    mode: 'hard',
    band: 4,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'junior single-seater racing',
    sources: const ['formula3-results', 'formula2-results'],
    data: '''
2005 GP2 Series|Nico Rosberg|2005
2024 FIA Formula 3|Leonardo Fornaroli|2024
2023 FIA Formula 3|Gabriel Bortoleto|2023
''',
    extraOptions: const ['Heikki Kovalainen', 'Dino Beganovic', 'Zane Maloney'],
  );
  _addRows(
    mode: 'hard',
    band: 5,
    scope: 'feeder_other',
    relation: 'champion_driver',
    competition: 'FIA Formula 3 Championship',
    sources: const ['formula3-results', 'fia-championship-records'],
    data: '''
2022 FIA Formula 3|Victor Martins|2022
2021 FIA Formula 3|Dennis Hauger|2021
2020 FIA Formula 3|Oscar Piastri|2020
''',
    extraOptions: const ['Zak O\'Sullivan', 'Logan Sargeant', 'Théo Pourchaire'],
  );
  _addRows(
    mode: 'global',
    band: 1,
    scope: 'feeder_other',
    relation: 'driver_nationality',
    competition: 'Formula E and Formula 2',
    sources: const ['formulae-results', 'formula2-results'],
    data: '''
Jake Dennis|United Kingdom
Nyck de Vries|Netherlands
António Félix da Costa|Portugal
Lucas di Grassi|Brazil
Oliver Rowland|United Kingdom
Théo Pourchaire|France
Felipe Drugovich|Brazil
Gabriel Bortoleto|Brazil
Victor Martins|France
''',
  );
  _addRows(
    mode: 'global',
    band: 2,
    scope: 'feeder_other',
    relation: 'circuit_city',
    competition: 'Formula E World Championship',
    sources: const ['formulae-results', 'fia-championship-records'],
    data: '''
the Monaco ePrix|Monaco
the Berlin ePrix|Berlin
the London ePrix|London
the New York City ePrix|Brooklyn
the Mexico City ePrix|Mexico City
the Tokyo ePrix|Tokyo
the São Paulo ePrix|São Paulo
the Jakarta ePrix|Jakarta
the Diriyah ePrix|Diriyah
''',
  );
  _addRows(
    mode: 'global',
    band: 3,
    scope: 'feeder_other',
    relation: 'first_year',
    competition: 'motorsport series',
    sources: const ['fia-championship-records', 'formulae-results'],
    data: '''
the Formula E World Championship|2014
the FIA Formula 2 Championship|2017
the GP2 Series|2005
the FIA Formula 3 Championship|2019
the British Touring Car Championship|1958
the Formula 3000 championship|1985
the Macau Grand Prix|1954
the Formula Ford championship|1967
the A1 Grand Prix series|2005
''',
    extraOptions: const ['1971', '1996'],
  );
  _addRows(
    mode: 'global',
    band: 4,
    scope: 'feeder_other',
    relation: 'series_home',
    competition: 'motorsport series',
    sources: const ['fia-championship-records', 'imsa-results'],
    data: '''
Super Formula|Japan
the Supercars Championship|Australia
the Macau Grand Prix|China
the Bathurst 1000|Australia
the Indy NXT series|United States
the Super GT championship|Japan
the Stock Car Pro Series|Brazil
the Formula Regional Oceania series|New Zealand
the Porsche Carrera Cup Deutschland|Germany
''',
  );
  _addRows(
    mode: 'global',
    band: 5,
    scope: 'feeder_other',
    relation: 'driver_nationality',
    competition: 'Formula E and junior racing',
    sources: const ['formulae-results', 'formula3-results'],
    data: '''
Edoardo Mortara|Switzerland
Sam Bird|United Kingdom
Robin Frijns|Netherlands
Mitch Evans|New Zealand
Sérgio Sette Câmara|Brazil
Maximilian Günther|Germany
Nick Cassidy|New Zealand
Dennis Hauger|Norway
Leonardo Fornaroli|Italy
''',
  );
}
