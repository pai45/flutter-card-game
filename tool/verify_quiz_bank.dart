// Validates the authored trivia database in `assets/quiz/`.
//
//   dart run tool/verify_quiz_bank.dart
//
// Paths resolve from this script's location, not the working directory, so if
// the package's native-asset build hooks are broken you can sidestep them by
// running it from outside the repo: `dart <repo>/tool/verify_quiz_bank.dart`.
//
// Pure dart:io — no Flutter deps — so it runs fast in a pre-commit hook or CI.
// Exits non-zero on any error. Warnings (answer-position bias) do not fail the
// run but are printed, because they need a human judgement call.
import 'dart:convert';
import 'dart:io';

const sports = ['football', 'cricket', 'basketball', 'tennis', 'motorsport'];
const modes = ['easy', 'medium', 'hard', 'global'];

const bandCount = 5;
const bandSize = 100;
const setsPerBand = 10;
const questionsPerSet = 10;
const optionCount = 4;

// The play screen must lay out at 320pt / 1.3x text scale (pinned by
// test/quiz_set_flow_test.dart). These caps keep new content inside that.
const maxPromptChars = 110;
const maxOptionChars = 34;

// Each answer index should land in roughly a quarter of a band.
const minAnswerShare = 0.20;
const maxAnswerShare = 0.30;

const cricketAuditPath = 'tool/quiz_audit/cricket.json';
const cricketCutoff = '2026-08-09';
const expectedCricketScopes = <String, Map<String, int>>{
  'easy': {'mens_international': 425, 'womens_international': 0, 'ipl': 75},
  'medium': {'mens_international': 300, 'womens_international': 75, 'ipl': 125},
  'hard': {'mens_international': 325, 'womens_international': 100, 'ipl': 75},
  'global': {'mens_international': 325, 'womens_international': 150, 'ipl': 25},
};

const basketballAuditPath = 'tool/quiz_audit/basketball.json';
const basketballCutoff = '2026-08-17';
const expectedBasketballScopes = <String, Map<String, int>>{
  'easy': {
    'nba': 350,
    'wnba': 50,
    'fiba_men': 40,
    'fiba_women': 10,
    'ncaa_men': 20,
    'ncaa_women': 5,
    'euroleague_world': 25,
  },
  'medium': {
    'nba': 325,
    'wnba': 50,
    'fiba_men': 35,
    'fiba_women': 15,
    'ncaa_men': 35,
    'ncaa_women': 15,
    'euroleague_world': 25,
  },
  'hard': {
    'nba': 300,
    'wnba': 50,
    'fiba_men': 40,
    'fiba_women': 20,
    'ncaa_men': 35,
    'ncaa_women': 15,
    'euroleague_world': 40,
  },
  'global': {
    'nba': 125,
    'wnba': 75,
    'fiba_men': 120,
    'fiba_women': 55,
    'ncaa_men': 25,
    'ncaa_women': 25,
    'euroleague_world': 75,
  },
};

const motorsportAuditPath = 'tool/quiz_audit/motorsport.json';
const motorsportCutoff = '2026-08-19';
const expectedMotorsportScopes = <String, Map<String, int>>{
  'easy': {
    'f1': 300,
    'motogp': 55,
    'nascar': 50,
    'indycar': 40,
    'endurance': 30,
    'rally': 15,
    'feeder_other': 10,
  },
  'medium': {
    'f1': 285,
    'motogp': 55,
    'nascar': 50,
    'indycar': 45,
    'endurance': 40,
    'rally': 15,
    'feeder_other': 10,
  },
  'hard': {
    'f1': 265,
    'motogp': 55,
    'nascar': 50,
    'indycar': 45,
    'endurance': 45,
    'rally': 25,
    'feeder_other': 15,
  },
  'global': {
    'f1': 135,
    'motogp': 80,
    'nascar': 45,
    'indycar': 50,
    'endurance': 85,
    'rally': 60,
    'feeder_other': 45,
  },
};

const tennisAuditPath = 'tool/quiz_audit/tennis.json';
const tennisCutoff = '2026-08-21';
const expectedTennisScopes = <String, Map<String, int>>{
  'easy': {
    'atp': 240,
    'wta': 100,
    'majors_events': 60,
    'team_events': 30,
    'doubles': 25,
    'rules_terms': 35,
    'world_other': 10,
  },
  'medium': {
    'atp': 245,
    'wta': 110,
    'majors_events': 55,
    'team_events': 35,
    'doubles': 30,
    'rules_terms': 15,
    'world_other': 10,
  },
  'hard': {
    'atp': 250,
    'wta': 110,
    'majors_events': 50,
    'team_events': 35,
    'doubles': 35,
    'rules_terms': 5,
    'world_other': 15,
  },
  'global': {
    'atp': 130,
    'wta': 105,
    'majors_events': 50,
    'team_events': 90,
    'doubles': 55,
    'rules_terms': 10,
    'world_other': 60,
  },
};

final class AuditSpec {
  const AuditSpec({
    required this.sport,
    required this.path,
    required this.cutoff,
    required this.expectedScopes,
    this.requirePrimarySource = false,
    this.requireContextMetadata = false,
    this.requireDistinctFacts = false,
  });

  final String sport;
  final String path;
  final String cutoff;
  final Map<String, Map<String, int>> expectedScopes;
  final bool requirePrimarySource;
  final bool requireContextMetadata;

  /// Rejects re-worded duplicates of an existing fact. Cricket and basketball
  /// pad short pools by rephrasing a seed fact up to eight ways; motorsport
  /// does not, and this keeps that guarantee enforced rather than conventional.
  final bool requireDistinctFacts;
}

const auditedSports = [
  AuditSpec(
    sport: 'cricket',
    path: cricketAuditPath,
    cutoff: cricketCutoff,
    expectedScopes: expectedCricketScopes,
  ),
  AuditSpec(
    sport: 'basketball',
    path: basketballAuditPath,
    cutoff: basketballCutoff,
    expectedScopes: expectedBasketballScopes,
    requirePrimarySource: true,
    requireContextMetadata: true,
  ),
  AuditSpec(
    sport: 'motorsport',
    path: motorsportAuditPath,
    cutoff: motorsportCutoff,
    expectedScopes: expectedMotorsportScopes,
    requirePrimarySource: true,
    requireContextMetadata: true,
    requireDistinctFacts: true,
  ),
  AuditSpec(
    sport: 'tennis',
    path: tennisAuditPath,
    cutoff: tennisCutoff,
    expectedScopes: expectedTennisScopes,
    requirePrimarySource: true,
    requireContextMetadata: true,
    requireDistinctFacts: true,
  ),
];

const bandNames = [
  'FOUNDATION',
  'PROSPECT',
  'CONTENDER',
  'SPECIALIST',
  'LEGEND',
];

final errors = <String>[];
final warnings = <String>[];

/// Repo root, resolved from this script's own location rather than the working
/// directory, so the checker runs from anywhere.
final String repoRoot = File.fromUri(
  Platform.script,
).parent.parent.path.replaceAll(r'\', '/');

String bankPath(String sport, String mode) =>
    '$repoRoot/assets/quiz/${sport}_$mode.json';

void main() {
  if (!Directory('$repoRoot/assets/quiz').existsSync()) {
    stderr.writeln('$repoRoot/assets/quiz/ not found.');
    exit(1);
  }

  // sport -> mode -> bands authored
  final coverage = <String, Map<String, int>>{
    for (final sport in sports) sport: {for (final mode in modes) mode: 0},
  };
  var totalQuestions = 0;

  for (final sport in sports) {
    // Duplicate prompts are only a problem within a sport — "who won the 2019
    // World Cup" is a different question in cricket and in football.
    final seenPrompts = <String, String>{};
    for (final mode in modes) {
      final path = 'assets/quiz/${sport}_$mode.json';
      final file = File(bankPath(sport, mode));
      if (!file.existsSync()) {
        warnings.add('$path — not authored yet');
        continue;
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (e) {
        errors.add('$path — will not parse: $e');
        continue;
      }

      if (json['sport'] != sport) {
        errors.add('$path — "sport" is ${json['sport']}, expected $sport');
      }
      if (json['mode'] != mode) {
        errors.add('$path — "mode" is ${json['mode']}, expected $mode');
      }

      final bands = json['bands'];
      if (bands is! Map) {
        errors.add('$path — missing "bands" object');
        continue;
      }

      var authored = 0;
      var ended = false;
      for (var band = 1; band <= bandCount; band++) {
        final entries = bands['$band'];
        if (entries is! List || entries.isEmpty) {
          ended = true;
          continue;
        }
        if (ended) {
          errors.add(
            '$path band $band — bands must be contiguous from 1 '
            '(band ${band - 1} is empty but $band is not)',
          );
        }
        if (entries.length != bandSize) {
          errors.add(
            '$path band $band — has ${entries.length} questions, '
            'expected exactly $bandSize',
          );
          continue;
        }
        authored++;
        totalQuestions += entries.length;
        _checkBand(path, band, entries, seenPrompts, '$sport/$mode');
      }
      coverage[sport]![mode] = authored;
    }
  }

  for (final spec in auditedSports) {
    _checkAudit(spec);
  }

  _printCoverage(coverage, totalQuestions);

  for (final warning in warnings) {
    stdout.writeln('  warn  $warning');
  }
  for (final error in errors) {
    stdout.writeln('  FAIL  $error');
  }

  stdout.writeln('');
  if (errors.isEmpty) {
    stdout.writeln(
      'OK — $totalQuestions questions valid'
      '${warnings.isEmpty ? '' : ', ${warnings.length} warning(s)'}.',
    );
    exit(0);
  }
  stdout.writeln('FAILED — ${errors.length} error(s).');
  exit(1);
}

void _checkBand(
  String path,
  int band,
  List<dynamic> entries,
  Map<String, String> seenPrompts,
  String scope,
) {
  final answerCounts = List<int>.filled(optionCount, 0);

  for (var i = 0; i < entries.length; i++) {
    final where = '$path band $band #${i + 1}';
    final entry = entries[i];
    if (entry is! Map) {
      errors.add('$where — not an object');
      continue;
    }

    final prompt = entry['p'];
    final options = entry['o'];
    final answer = entry['a'];

    if (prompt is! String || prompt.trim().isEmpty) {
      errors.add('$where — "p" must be a non-empty string');
      continue;
    }
    if (prompt.length > maxPromptChars) {
      errors.add(
        '$where — prompt is ${prompt.length} chars (max $maxPromptChars): '
        '"${prompt.substring(0, 40)}…"',
      );
    }
    if (scope.startsWith('cricket/') &&
        prompt.toLowerCase().contains('hypothetical')) {
      errors.add(
        '$where — cricket questions must use recorded facts, not hypothetical scenarios',
      );
    }

    if (options is! List || options.length != optionCount) {
      errors.add('$where — "o" must have exactly $optionCount options');
      continue;
    }
    final labels = <String>[];
    for (final option in options) {
      if (option is! String || option.trim().isEmpty) {
        errors.add('$where — every option must be a non-empty string');
        continue;
      }
      if (option.length > maxOptionChars) {
        errors.add(
          '$where — option "$option" is ${option.length} chars '
          '(max $maxOptionChars)',
        );
      }
      labels.add(option);
    }
    if (labels.toSet().length != labels.length) {
      errors.add('$where — duplicate option labels');
    }
    // A widget test asserts a prompt renders exactly once on screen.
    if (labels.any((label) => label == prompt)) {
      errors.add('$where — an option repeats the prompt verbatim');
    }

    if (answer is! int || answer < 0 || answer >= optionCount) {
      errors.add('$where — "a" must be an int in 0..${optionCount - 1}');
      continue;
    }
    answerCounts[answer]++;

    final normalized = _normalize(prompt);
    final previous = seenPrompts[normalized];
    if (previous != null) {
      errors.add('$where — duplicate prompt, already used at $previous');
    } else {
      seenPrompts[normalized] = '$where ($scope)';
    }
  }

  for (var index = 0; index < optionCount; index++) {
    final share = answerCounts[index] / entries.length;
    if (share < minAnswerShare || share > maxAnswerShare) {
      warnings.add(
        '$path band $band — answer index $index is '
        '${(share * 100).toStringAsFixed(0)}% of the band '
        '(want ${(minAnswerShare * 100).toInt()}–'
        '${(maxAnswerShare * 100).toInt()}%)',
      );
    }
  }
}

/// Lowercase, strip punctuation, collapse whitespace — so "Who won the 2019
/// final?" and "who won the 2019 final" collide.
String _normalize(String prompt) => prompt
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

void _printCoverage(Map<String, Map<String, int>> coverage, int total) {
  stdout.writeln('');
  stdout.writeln('QUIZ DATABASE COVERAGE   (bands authored of $bandCount)');
  stdout.writeln('');
  stdout.writeln(
    '  ${'sport'.padRight(12)}${modes.map((m) => m.padRight(10)).join()}sets',
  );
  stdout.writeln('  ${'-' * 54}');

  var grandSets = 0;
  for (final sport in sports) {
    final row = StringBuffer('  ${sport.padRight(12)}');
    var sportSets = 0;
    for (final mode in modes) {
      final bands = coverage[sport]![mode]!;
      sportSets += bands * setsPerBand;
      row.write('${_bar(bands)}  '.padRight(10));
    }
    grandSets += sportSets;
    row.write('$sportSets/${bandCount * setsPerBand * modes.length}');
    stdout.writeln(row);
  }
  stdout.writeln('  ${'-' * 54}');
  final totalLabel = '  ${'TOTAL'.padRight(12)}$total questions'.padRight(40);
  final totalSets = sports.length * modes.length * bandCount * setsPerBand;
  stdout.writeln('$totalLabel$grandSets/$totalSets');
  stdout.writeln('');
  stdout.writeln(
    '  bands: ${List.generate(bandCount, (i) => '${i + 1} ${bandNames[i]}').join(' · ')}',
  );
  stdout.writeln(
    '  (1 band = $bandSize questions = $setsPerBand sets '
    'of $questionsPerSet)',
  );
  stdout.writeln('');
}

String _bar(int bands) => '${'#' * bands}${'.' * (bandCount - bands)}';

void _checkAudit(AuditSpec spec) {
  final relativePath = spec.path;
  final file = File('$repoRoot/$relativePath');
  if (!file.existsSync()) {
    errors.add(
      '$relativePath — required ${spec.sport} audit ledger is missing',
    );
    return;
  }

  Map<String, dynamic> audit;
  try {
    audit = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    errors.add('$relativePath — will not parse: $e');
    return;
  }

  if (audit['sport'] != spec.sport) {
    errors.add('$relativePath — "sport" must be ${spec.sport}');
  }
  if (audit['factualCutoff'] != spec.cutoff) {
    errors.add(
      '$relativePath — factualCutoff is ${audit['factualCutoff']}, '
      'expected ${spec.cutoff}',
    );
  }
  final sources = audit['sources'];
  final questions = audit['questions'];
  if (sources is! Map) {
    errors.add('$relativePath — missing "sources" object');
    return;
  }
  if (questions is! Map) {
    errors.add('$relativePath — missing "questions" object');
    return;
  }

  for (final entry in sources.entries) {
    final value = entry.value;
    if (value is! Map ||
        value['title'] is! String ||
        value['url'] is! String ||
        (spec.requirePrimarySource && value['kind'] != 'primary')) {
      errors.add('$relativePath — source ${entry.key} is malformed');
      continue;
    }
    final uri = Uri.tryParse(value['url'] as String);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      errors.add(
        '$relativePath — source ${entry.key} must use a valid HTTPS URL',
      );
    }
  }

  final expectedIds = <String>{};
  final factKeys = <String, String>{};
  final scopeCounts = <String, Map<String, int>>{
    for (final mode in modes)
      mode: {for (final scope in spec.expectedScopes[mode]!.keys) scope: 0},
  };

  for (final mode in modes) {
    final bank = File(bankPath(spec.sport, mode));
    if (!bank.existsSync()) continue;
    final json = jsonDecode(bank.readAsStringSync()) as Map<String, dynamic>;
    final bands = json['bands'] as Map;
    var number = 0;
    for (var band = 1; band <= bandCount; band++) {
      final entries = bands['$band'];
      if (entries is! List || entries.length != bandSize) continue;
      final answerCounts = List<int>.filled(optionCount, 0);
      for (var index = 0; index < entries.length; index++) {
        number++;
        final id =
            '${spec.sport}_${mode}_q${number.toString().padLeft(3, '0')}';
        expectedIds.add(id);
        final where = '$relativePath $id';
        final authored = entries[index];
        final record = questions[id];
        if (authored is! Map || record is! Map) {
          errors.add('$where — missing authored question or audit entry');
          continue;
        }

        final options = authored['o'];
        final answerIndex = authored['a'];
        if (options is! List ||
            answerIndex is! int ||
            answerIndex < 0 ||
            answerIndex >= options.length) {
          errors.add('$where — authored answer cannot be resolved');
          continue;
        }
        answerCounts[answerIndex]++;
        final mappedAnswer = options[answerIndex];
        if (record['answer'] != mappedAnswer) {
          errors.add(
            '$where — canonical answer "${record['answer']}" does not match '
            'o[a] "$mappedAnswer"',
          );
        }
        if (record['cutoff'] != spec.cutoff) {
          errors.add('$where — cutoff must be ${spec.cutoff}');
        }

        final factKey = record['factKey'];
        if (factKey is! String || factKey.isEmpty) {
          errors.add('$where — factKey must be a non-empty string');
        } else {
          if (spec.requireDistinctFacts &&
              RegExp(r'^(v\d+|fact-\d+)-').hasMatch(factKey)) {
            errors.add(
              '$where — ${spec.sport} must author distinct facts, but '
              'factKey "$factKey" is a re-worded variant',
            );
          }
          if (factKey.startsWith('scenario-')) {
            errors.add(
              '$where — ${spec.sport} factKey must not identify a scenario',
            );
          }
          final previous = factKeys[factKey];
          if (previous != null) {
            errors.add(
              '$where — factKey "$factKey" is already used by $previous',
            );
          } else {
            factKeys[factKey] = id;
          }
        }

        final scope = record['scope'];
        if (scope is! String || !scopeCounts[mode]!.containsKey(scope)) {
          errors.add('$where — unknown content scope "$scope"');
        } else {
          scopeCounts[mode]![scope] = scopeCounts[mode]![scope]! + 1;
        }

        final difficulty = record['difficulty'];
        final expectedSet = ((number - 1) ~/ questionsPerSet) + 1;
        if (difficulty is! Map ||
            difficulty['mode'] != mode ||
            difficulty['band'] != band ||
            difficulty['set'] != expectedSet) {
          errors.add(
            '$where — difficulty must be $mode/band $band/set $expectedSet',
          );
        }

        if (spec.requireContextMetadata) {
          final competition = record['competition'];
          final season = record['season'];
          if (competition is! String || competition.trim().isEmpty) {
            errors.add('$where — competition must be a non-empty string');
          }
          if (season is! String || season.trim().isEmpty) {
            errors.add('$where — season must be a non-empty string');
          }
        }

        final refs = record['sources'];
        if (refs is! List || refs.length < 2) {
          errors.add('$where — at least two source references are required');
        } else {
          var hasPrimary = false;
          for (final ref in refs) {
            if (ref is! String || !sources.containsKey(ref)) {
              errors.add('$where — unknown source reference "$ref"');
            } else if ((sources[ref] as Map)['kind'] == 'primary') {
              hasPrimary = true;
            }
          }
          if (spec.requirePrimarySource && !hasPrimary) {
            errors.add('$where — at least one primary source is required');
          }
        }
      }
      for (var answerIndex = 0; answerIndex < optionCount; answerIndex++) {
        if (answerCounts[answerIndex] != bandSize ~/ optionCount) {
          errors.add(
            'assets/quiz/${spec.sport}_$mode.json band $band — answer index '
            '$answerIndex occurs ${answerCounts[answerIndex]} times, expected 25',
          );
        }
      }
    }
  }

  if (questions.length != expectedIds.length) {
    errors.add(
      '$relativePath — has ${questions.length} entries, '
      'expected ${expectedIds.length}',
    );
  }
  for (final id in questions.keys) {
    if (!expectedIds.contains(id)) {
      errors.add('$relativePath — unexpected audit entry $id');
    }
  }
  for (final mode in modes) {
    final expected = spec.expectedScopes[mode]!;
    final actual = scopeCounts[mode]!;
    for (final scope in expected.keys) {
      if (actual[scope] != expected[scope]) {
        errors.add(
          '$relativePath — $mode/$scope has ${actual[scope]}, '
          'expected ${expected[scope]}',
        );
      }
    }
  }
}
