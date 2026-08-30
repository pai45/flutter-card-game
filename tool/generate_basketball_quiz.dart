// Generates the authored Basketball Quiz assets and their development-only
// audit ledger. Run from the repository root with the bundled Dart SDK:
//
//   .\flutter\bin\cache\dart-sdk\bin\dart.exe tool\generate_basketball_quiz.dart
//
// Runtime assets keep the compact p/o/a schema used by every Knowledge Arena
// sport. Audit metadata is deliberately kept out of the app bundle.
import 'dart:convert';
import 'dart:io';

const _modes = ['easy', 'medium', 'hard', 'global'];
const _scopes = [
  'nba',
  'wnba',
  'fiba_men',
  'fiba_women',
  'ncaa_men',
  'ncaa_women',
  'euroleague_world',
];
const _cutoff = '2026-08-17';

const _sourceRegistry = <String, Map<String, String>>{
  'nba-guide-2025-26': {
    'kind': 'primary',
    'title': '2025-26 Official NBA Guide',
    'url': 'https://www.nba.com/news/nba-guide',
  },
  'nba-history': {
    'kind': 'primary',
    'title': 'NBA History and season archive',
    'url': 'https://www.nba.com/history',
  },
  'nba-records': {
    'kind': 'primary',
    'title': 'NBA all-time records',
    'url': 'https://www.nba.com/news/history-all-time-records',
  },
  'nba-rulebook-2025-26': {
    'kind': 'primary',
    'title': '2025-26 Official NBA Playing Rules',
    'url':
        'https://cdn.nba.com/manage/2026/01/Official-2025-26-NBA-Playing-Rules.pdf',
  },
  'wnba-history': {
    'kind': 'primary',
    'title': 'WNBA official history',
    'url': 'https://www.wnba.com/history',
  },
  'wnba-faq-2026': {
    'kind': 'primary',
    'title': 'WNBA official league FAQ',
    'url': 'https://www.wnba.com/faq',
  },
  'wnba-rulebook-2026': {
    'kind': 'primary',
    'title': '2026 Official WNBA Rule Book',
    'url': 'https://www.wnba.com/wnba-rule-book',
  },
  'fiba-history': {
    'kind': 'primary',
    'title': 'FIBA events history archive',
    'url': 'https://www.fiba.basketball/en/history',
  },
  'fiba-rules-2024': {
    'kind': 'primary',
    'title': 'FIBA Official Basketball Rules 2024',
    'url':
        'https://assets.fiba.basketball/image/upload/documents-corporate-fiba-official-rules-2024-v10a.pdf',
  },
  'fiba-world-cup-medalists': {
    'kind': 'primary',
    'title': 'FIBA Basketball World Cup all-time medalists',
    'url':
        'https://www.fiba.basketball/en/events/fiba-basketball-world-cup-2027/all-time-medalists',
  },
  'ncaa-men-history': {
    'kind': 'primary',
    'title': 'NCAA Division I men\'s championship history',
    'url': 'https://www.ncaa.com/history/basketball-men/d1',
  },
  'ncaa-women-history': {
    'kind': 'primary',
    'title': 'NCAA Division I women\'s championship history',
    'url': 'https://www.ncaa.com/history/basketball-women/d1',
  },
  'ncaa-record-books': {
    'kind': 'primary',
    'title': 'NCAA basketball record books',
    'url': 'https://www.ncaa.org/sports/2013/11/27/basketball-records.aspx',
  },
  'euroleague-stats': {
    'kind': 'primary',
    'title': 'EuroLeague official statistics and all-time leaders',
    'url': 'https://www.euroleaguebasketball.net/euroleague/stats/',
  },
  'euroleague-history': {
    'kind': 'primary',
    'title': 'EuroLeague official competition history',
    'url': 'https://www.euroleaguebasketball.net/euroleague/',
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
    this.variant = 0,
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
  final int variant;

  _Fact asVariant(int number) => _Fact(
    mode: mode,
    band: band,
    scope: scope,
    relation: relation,
    subject: subject,
    answer: answer,
    optionPool: optionPool,
    factKey: 'v$number-$factKey',
    competition: competition,
    season: season,
    sources: sources,
    variant: number,
  );
}

final _facts = <String, List<_Fact>>{};
final _cursors = <String, int>{};

String _poolKey(String mode, int band, String scope) => '$mode/$band/$scope';

void main() {
  _addNbaFacts();
  _addWnbaFacts();
  _addFibaFacts();
  _addNcaaFacts();
  _addEuroleagueFacts();
  _fillPools();

  final auditQuestions = <String, Object?>{};
  final seenPrompts = <String>{};
  final seenFactKeys = <String>{};

  for (final mode in _modes) {
    final bands = <String, Object?>{};
    var questionNumber = 0;
    for (var band = 1; band <= 5; band++) {
      final remaining = Map<String, int>.from(_scopeCounts(mode, band));
      final entries = <Map<String, Object?>>[];
      while (entries.length < 100) {
        for (final scope in _scopes) {
          if ((remaining[scope] ?? 0) == 0) continue;
          final fact = _take(mode, band, scope);
          final prompt = _prompt(fact);
          final normalized = _normalize(prompt);
          if (!seenPrompts.add(normalized)) {
            throw StateError('Duplicate prompt: $prompt');
          }
          if (!seenFactKeys.add(fact.factKey)) {
            throw StateError('Duplicate fact key: ${fact.factKey}');
          }

          questionNumber++;
          final id =
              'basketball_${mode}_q${questionNumber.toString().padLeft(3, '0')}';
          final correctIndex = (entries.length) % 4;
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
    _writeJson('assets/quiz/basketball_$mode.json', {
      'sport': 'basketball',
      'mode': mode,
      'version': 1,
      'bands': bands,
    });
  }

  _writeJson('tool/quiz_audit/basketball.json', {
    'sport': 'basketball',
    'version': 1,
    'factualCutoff': _cutoff,
    'sources': _sourceRegistry,
    'questions': auditQuestions,
  });
  stdout.writeln(
    'Generated ${auditQuestions.length} basketball questions and audit entries.',
  );
}

Map<String, int> _scopeCounts(String mode, int band) => switch (mode) {
  'easy' => {
    'nba': 70,
    'wnba': 10,
    'fiba_men': 8,
    'fiba_women': 2,
    'ncaa_men': 4,
    'ncaa_women': 1,
    'euroleague_world': 5,
  },
  'medium' => {
    'nba': 65,
    'wnba': 10,
    'fiba_men': 7,
    'fiba_women': 3,
    'ncaa_men': 7,
    'ncaa_women': 3,
    'euroleague_world': 5,
  },
  'hard' => {
    'nba': 60,
    'wnba': 10,
    'fiba_men': 8,
    'fiba_women': 4,
    'ncaa_men': 7,
    'ncaa_women': 3,
    'euroleague_world': 8,
  },
  'global' => {
    'nba': 25,
    'wnba': 15,
    'fiba_men': 24,
    'fiba_women': 11,
    'ncaa_men': 5,
    'ncaa_women': 5,
    'euroleague_world': 15,
  },
  _ => throw ArgumentError.value(mode),
};

void _fillPools() {
  for (final mode in _modes) {
    for (var band = 1; band <= 5; band++) {
      for (final entry in _scopeCounts(mode, band).entries) {
        final key = _poolKey(mode, band, entry.key);
        final pool = _facts[key];
        if (pool == null || pool.isEmpty) {
          throw StateError('No factual seeds for $key');
        }
        if (pool.length > entry.value) {
          throw StateError(
            '$key has ${pool.length} seeds for ${entry.value} slots',
          );
        }
        final seeds = List<_Fact>.of(pool);
        var variant = 1;
        while (pool.length < entry.value) {
          final source = seeds[(variant - 1) % seeds.length];
          final edition = ((variant - 1) ~/ seeds.length) + 1;
          if (edition > 7) {
            throw StateError('$key needs more than eight phrasings per fact');
          }
          pool.add(source.asVariant(edition));
          variant++;
        }
      }
    }
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

void _addRows({
  required String mode,
  required String scope,
  required String relation,
  required String competition,
  required List<String> sources,
  required String data,
}) {
  final rows = _rows(data);
  if (rows.length < 5) {
    throw StateError('$mode/$scope/$relation needs at least five seed rows');
  }
  final optionPool = rows.map((row) => row[1]).toSet().toList();
  if (optionPool.length < 4) {
    throw StateError('$mode/$scope/$relation needs four distinct answers');
  }
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final band = (index * 5 ~/ rows.length) + 1;
    final subject = row[0];
    final answer = row[1];
    final season = row.length > 2 ? row[2] : _cutoff;
    final fact = _Fact(
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
    );
    _facts.putIfAbsent(_poolKey(mode, band, scope), () => []).add(fact);
  }
}

String _prompt(_Fact fact) {
  final form = fact.variant % 8;
  final subject = fact.subject;
  return switch (fact.relation) {
    'definition' => [
      'In basketball, what does “$subject” mean?',
      'Which definition matches “$subject” in basketball?',
      'What is the basketball meaning of “$subject”?',
      'On a basketball court, “$subject” describes what?',
      'Choose the correct meaning of “$subject”.',
      'How is “$subject” defined in basketball?',
      'What does a coach mean by “$subject”?',
      'Which description best fits “$subject”?',
    ][form],
    'rule_value' => [
      'Under $subject, what is the correct value?',
      'Which value is set by $subject?',
      'What value applies to $subject?',
      '$subject uses which official value?',
      'Choose the official value for $subject.',
      'What does the rulebook set for $subject?',
      'Which number correctly completes $subject?',
      'Identify the regulation value for $subject.',
    ][form],
    'home_market' => [
      'Which home market is represented by the $subject?',
      'The $subject represent which market?',
      'Which city or region is home to the $subject?',
      'Name the home market of the $subject.',
      'Where are the $subject based?',
      'The $subject play for which home market?',
      'Identify the market behind the $subject name.',
      'Which location do the $subject call home?',
    ][form],
    'division' => [
      'Which NBA division includes the $subject?',
      'The $subject compete in which NBA division?',
      'Name the NBA division of the $subject.',
      'Which division is home to the $subject?',
      'Where do the $subject sit in the NBA division map?',
      'Choose the correct division for the $subject.',
      'The $subject belong to which division?',
      'Identify the $subject NBA division.',
    ][form],
    'champion' => [
      'Who won the $subject?',
      'Which team were champions of the $subject?',
      'Name the title winner from the $subject.',
      'Which side lifted the trophy at the $subject?',
      'The $subject title went to which team?',
      'Who were crowned champions in the $subject?',
      'Identify the winner of the $subject.',
      'Which team claimed the $subject championship?',
    ][form],
    'national_team' => [
      'Which national team did $subject represent?',
      '$subject played international basketball for which country?',
      'Name the national side represented by $subject.',
      'At international level, $subject represented which nation?',
      'Which country did $subject play for internationally?',
      'Identify $subject’s national basketball team.',
      '$subject wore the colors of which national team?',
      'Which nation did $subject represent in basketball?',
    ][form],
    'host' => [
      'Where was the $subject held?',
      'Which host staged the $subject?',
      'Name the host location of the $subject.',
      'The $subject took place in which host location?',
      'Which location hosted the $subject?',
      'Identify the host of the $subject.',
      'Where did the $subject take place?',
      'Which venue country or city staged the $subject?',
    ][form],
    'club_country' => [
      'Which country is home to $subject?',
      '$subject is a basketball club from which country?',
      'Name the country represented by $subject.',
      'In which country is $subject based?',
      'Which national league system includes $subject?',
      'Identify the home country of $subject.',
      '$subject comes from which country?',
      'Where is the club $subject based?',
    ][form],
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
  if (options.any((option) => option.length > 34)) {
    throw StateError('Option too long for $prompt: $options');
  }
  if (options.toSet().length != 4) {
    throw StateError('Duplicate options for $prompt: $options');
  }
  final lower = prompt.toLowerCase();
  if (lower.contains('current') ||
      lower.contains('latest') ||
      lower.contains('hypothetical')) {
    throw StateError('Time-ambiguous or hypothetical prompt: $prompt');
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
    .map((line) => line.trim().split('|').map((cell) => cell.trim()).toList())
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

void _addNbaFacts() {
  _addRows(
    mode: 'easy',
    scope: 'nba',
    relation: 'definition',
    competition: 'NBA',
    sources: const ['nba-rulebook-2025-26', 'nba-guide-2025-26'],
    data: '''
field goal|a basket during live play
free throw|an uncontested one-point shot
three-pointer|a shot beyond the three arc
assist|a pass directly creating a basket
rebound|gaining possession after a miss
steal|taking the ball from an opponent
blocked shot|deflecting an attempted shot
turnover|losing possession to the opponent
double-double|double figures in two stats
triple-double|double figures in three stats
shot clock|timer limiting a possession
traveling|illegal movement without dribbling
goaltending|illegal contact with a shot
personal foul|illegal contact by a player
technical foul|penalty for non-contact behavior
flagrant foul|unnecessary excessive contact
jump ball|a toss that starts live play
fast break|a quick attack before defense sets
pick-and-roll|screen then move toward the rim
alley-oop|air pass finished at the rim
sixth player|a key reserve off the bench
the paint|the lane area near the basket
buzzer-beater|a shot released before time ends
backcourt violation|illegal return into the backcourt
restricted area|arc beneath the basket
''',
  );
  _addRows(
    mode: 'easy',
    scope: 'nba',
    relation: 'home_market',
    competition: 'NBA',
    sources: const ['nba-guide-2025-26', 'nba-history'],
    data: '''
Atlanta Hawks|Atlanta
Boston Celtics|Boston
Brooklyn Nets|Brooklyn
Charlotte Hornets|Charlotte
Chicago Bulls|Chicago
Cleveland Cavaliers|Cleveland
Dallas Mavericks|Dallas
Denver Nuggets|Denver
Detroit Pistons|Detroit
Golden State Warriors|San Francisco
Houston Rockets|Houston
Indiana Pacers|Indianapolis
LA Clippers|Los Angeles
Los Angeles Lakers|Los Angeles
Memphis Grizzlies|Memphis
Miami Heat|Miami
Milwaukee Bucks|Milwaukee
Minnesota Timberwolves|Minneapolis
New Orleans Pelicans|New Orleans
New York Knicks|New York
Oklahoma City Thunder|Oklahoma City
Orlando Magic|Orlando
Philadelphia 76ers|Philadelphia
Phoenix Suns|Phoenix
Portland Trail Blazers|Portland
Sacramento Kings|Sacramento
San Antonio Spurs|San Antonio
Toronto Raptors|Toronto
Utah Jazz|Salt Lake City
Washington Wizards|Washington, D.C.
''',
  );
  _addRows(
    mode: 'medium',
    scope: 'nba',
    relation: 'division',
    competition: 'NBA',
    sources: const ['nba-guide-2025-26', 'nba-history'],
    data: '''
Boston Celtics|Atlantic Division
Brooklyn Nets|Atlantic Division
New York Knicks|Atlantic Division
Philadelphia 76ers|Atlantic Division
Toronto Raptors|Atlantic Division
Chicago Bulls|Central Division
Cleveland Cavaliers|Central Division
Detroit Pistons|Central Division
Indiana Pacers|Central Division
Milwaukee Bucks|Central Division
Atlanta Hawks|Southeast Division
Charlotte Hornets|Southeast Division
Miami Heat|Southeast Division
Orlando Magic|Southeast Division
Washington Wizards|Southeast Division
Denver Nuggets|Northwest Division
Minnesota Timberwolves|Northwest Division
Oklahoma City Thunder|Northwest Division
Portland Trail Blazers|Northwest Division
Utah Jazz|Northwest Division
Golden State Warriors|Pacific Division
LA Clippers|Pacific Division
Los Angeles Lakers|Pacific Division
Phoenix Suns|Pacific Division
Sacramento Kings|Pacific Division
Dallas Mavericks|Southwest Division
Houston Rockets|Southwest Division
Memphis Grizzlies|Southwest Division
New Orleans Pelicans|Southwest Division
San Antonio Spurs|Southwest Division
''',
  );
  _addRows(
    mode: 'medium',
    scope: 'nba',
    relation: 'champion',
    competition: 'NBA Finals',
    sources: const ['nba-history', 'nba-records'],
    data: _nbaChampions1990To2025,
  );
  _addRows(
    mode: 'hard',
    scope: 'nba',
    relation: 'champion',
    competition: 'NBA Finals',
    sources: const ['nba-history', 'nba-records'],
    data: _nbaChampions1947To1989,
  );
  _addRows(
    mode: 'global',
    scope: 'nba',
    relation: 'national_team',
    competition: 'International basketball',
    sources: const ['nba-guide-2025-26', 'fiba-history'],
    data: '''
Nikola Jokic|Serbia
Giannis Antetokounmpo|Greece
Luka Doncic|Slovenia
Joel Embiid|United States
Shai Gilgeous-Alexander|Canada
Victor Wembanyama|France
Domantas Sabonis|Lithuania
Kristaps Porzingis|Latvia
Alperen Sengun|Türkiye
Lauri Markkanen|Finland
Rudy Gobert|France
Jamal Murray|Canada
RJ Barrett|Canada
Bogdan Bogdanovic|Serbia
Nikola Vucevic|Montenegro
Jusuf Nurkic|Bosnia and Herzegovina
Deni Avdija|Israel
Josh Giddey|Australia
Yuta Watanabe|Japan
Pau Gasol|Spain
Dirk Nowitzki|Germany
Manu Ginobili|Argentina
Yao Ming|China
Tony Parker|France
Hakeem Olajuwon|United States
''',
  );
}

void _addWnbaFacts() {
  _addRows(
    mode: 'easy',
    scope: 'wnba',
    relation: 'home_market',
    competition: 'WNBA',
    sources: const ['wnba-faq-2026', 'wnba-history'],
    data: '''
Atlanta Dream|Atlanta
Chicago Sky|Chicago
Connecticut Sun|Connecticut
Dallas Wings|Dallas
Golden State Valkyries|Golden State
Indiana Fever|Indiana
Las Vegas Aces|Las Vegas
Los Angeles Sparks|Los Angeles
Minnesota Lynx|Minnesota
New York Liberty|New York
Phoenix Mercury|Phoenix
Portland Fire|Portland
Seattle Storm|Seattle
Toronto Tempo|Toronto
Washington Mystics|Washington
''',
  );
  _addRows(
    mode: 'medium',
    scope: 'wnba',
    relation: 'champion',
    competition: 'WNBA Finals',
    sources: const ['wnba-history', 'wnba-faq-2026'],
    data: _wnbaChampions2011To2025,
  );
  _addRows(
    mode: 'hard',
    scope: 'wnba',
    relation: 'champion',
    competition: 'WNBA Finals',
    sources: const ['wnba-history', 'wnba-faq-2026'],
    data: _wnbaChampions1997To2010,
  );
  _addRows(
    mode: 'global',
    scope: 'wnba',
    relation: 'national_team',
    competition: 'International basketball',
    sources: const ['wnba-history', 'fiba-history'],
    data: '''
Penny Taylor|Australia
Emma Meesseman|Belgium
Satou Sabally|Germany
Marine Johannes|France
Ezi Magbegor|Australia
Leonie Fiebich|Germany
Bridget Carleton|Canada
Julie Allemand|Belgium
Han Xu|China
Temi Fagbenle|Great Britain
Jonquel Jones|Bosnia and Herzegovina
Yvonne Anderson|Serbia
Kia Nurse|Canada
Gabby Williams|France
Sami Whitcomb|Australia
''',
  );
}

void _addFibaFacts() {
  _addRows(
    mode: 'easy',
    scope: 'fiba_men',
    relation: 'rule_value',
    competition: 'FIBA basketball',
    sources: const ['fiba-rules-2024', 'fiba-history'],
    data: '''
the FIBA shot clock|24 seconds
one FIBA quarter|10 minutes
FIBA overtime|5 minutes
players on court per FIBA team|5 players
personal fouls before fouling out|5 fouls
the standard basket height|3.05 metres
the FIBA backcourt limit|8 seconds
the FIBA no-charge semi-circle|1.30 metres
the FIBA halftime interval|15 minutes
the FIBA three-point line|6.75 metres
''',
  );
  _addRows(
    mode: 'medium',
    scope: 'fiba_men',
    relation: 'champion',
    competition: 'FIBA and Olympic men',
    sources: const ['fiba-history', 'fiba-world-cup-medalists'],
    data: _fibaMenRecentChampions,
  );
  _addRows(
    mode: 'hard',
    scope: 'fiba_men',
    relation: 'champion',
    competition: 'FIBA and Olympic men',
    sources: const ['fiba-history', 'fiba-world-cup-medalists'],
    data: _fibaMenHistoricChampions,
  );
  _addRows(
    mode: 'global',
    scope: 'fiba_men',
    relation: 'host',
    competition: 'FIBA and Olympic men',
    sources: const ['fiba-history', 'fiba-world-cup-medalists'],
    data: _fibaMenHosts,
  );

  _addRows(
    mode: 'easy',
    scope: 'fiba_women',
    relation: 'national_team',
    competition: 'FIBA women',
    sources: const ['fiba-history', 'wnba-history'],
    data: '''
Sue Bird|United States
Lauren Jackson|Australia
Hortencia Marcari|Brazil
Margo Dydek|Poland
Amaya Valdemoro|Spain
''',
  );
  _addRows(
    mode: 'medium',
    scope: 'fiba_women',
    relation: 'champion',
    competition: 'FIBA and Olympic women',
    sources: const ['fiba-history', 'wnba-history'],
    data: _fibaWomenRecentChampions,
  );
  _addRows(
    mode: 'hard',
    scope: 'fiba_women',
    relation: 'champion',
    competition: 'FIBA Women\'s World Cup',
    sources: const ['fiba-history', 'wnba-history'],
    data: _fibaWomenHistoricChampions,
  );
  _addRows(
    mode: 'global',
    scope: 'fiba_women',
    relation: 'host',
    competition: 'FIBA and Olympic women',
    sources: const ['fiba-history', 'fiba-rules-2024'],
    data: _fibaWomenHosts,
  );
}

void _addNcaaFacts() {
  _addRows(
    mode: 'easy',
    scope: 'ncaa_men',
    relation: 'champion',
    competition: 'NCAA Division I men',
    sources: const ['ncaa-men-history', 'ncaa-record-books'],
    data: _ncaaMen2021To2025,
  );
  _addRows(
    mode: 'medium',
    scope: 'ncaa_men',
    relation: 'champion',
    competition: 'NCAA Division I men',
    sources: const ['ncaa-men-history', 'ncaa-record-books'],
    data: _ncaaMen2010To2019,
  );
  _addRows(
    mode: 'hard',
    scope: 'ncaa_men',
    relation: 'champion',
    competition: 'NCAA Division I men',
    sources: const ['ncaa-men-history', 'ncaa-record-books'],
    data: _ncaaMen1990To2009,
  );
  _addRows(
    mode: 'global',
    scope: 'ncaa_men',
    relation: 'champion',
    competition: 'NCAA Division I men',
    sources: const ['ncaa-men-history', 'ncaa-record-books'],
    data: _ncaaMen1939To1963,
  );

  _addRows(
    mode: 'easy',
    scope: 'ncaa_women',
    relation: 'champion',
    competition: 'NCAA Division I women',
    sources: const ['ncaa-women-history', 'ncaa-record-books'],
    data: _ncaaWomen2021To2025,
  );
  _addRows(
    mode: 'medium',
    scope: 'ncaa_women',
    relation: 'champion',
    competition: 'NCAA Division I women',
    sources: const ['ncaa-women-history', 'ncaa-record-books'],
    data: _ncaaWomen2011To2019,
  );
  _addRows(
    mode: 'hard',
    scope: 'ncaa_women',
    relation: 'champion',
    competition: 'NCAA Division I women',
    sources: const ['ncaa-women-history', 'ncaa-record-books'],
    data: _ncaaWomen2001To2010,
  );
  _addRows(
    mode: 'global',
    scope: 'ncaa_women',
    relation: 'champion',
    competition: 'NCAA Division I women',
    sources: const ['ncaa-women-history', 'ncaa-record-books'],
    data: _ncaaWomen1982To2000,
  );
}

void _addEuroleagueFacts() {
  _addRows(
    mode: 'easy',
    scope: 'euroleague_world',
    relation: 'club_country',
    competition: 'European club basketball',
    sources: const ['euroleague-history', 'euroleague-stats'],
    data: '''
Real Madrid|Spain
FC Barcelona|Spain
Panathinaikos|Greece
Olympiacos|Greece
Fenerbahce|Türkiye
Anadolu Efes|Türkiye
Maccabi Tel Aviv|Israel
Virtus Bologna|Italy
Olimpia Milano|Italy
AS Monaco|Monaco
''',
  );
  _addRows(
    mode: 'medium',
    scope: 'euroleague_world',
    relation: 'champion',
    competition: 'EuroLeague',
    sources: const ['euroleague-history', 'euroleague-stats'],
    data: _euroleagueChampions2016To2025,
  );
  _addRows(
    mode: 'hard',
    scope: 'euroleague_world',
    relation: 'champion',
    competition: 'EuroLeague',
    sources: const ['euroleague-history', 'euroleague-stats'],
    data: _euroleagueChampions2002To2015,
  );
  _addRows(
    mode: 'global',
    scope: 'euroleague_world',
    relation: 'club_country',
    competition: 'World club basketball',
    sources: const ['euroleague-history', 'euroleague-stats'],
    data: '''
Baskonia|Spain
Valencia Basket|Spain
ASVEL|France
Paris Basketball|France
Bayern Munich|Germany
ALBA Berlin|Germany
Partizan|Serbia
Crvena zvezda|Serbia
Zalgiris Kaunas|Lithuania
Rytas Vilnius|Lithuania
CSKA Moscow|Russia
Dubai Basketball|United Arab Emirates
Hapoel Tel Aviv|Israel
KK Split|Croatia
Cibona Zagreb|Croatia
''',
  );
}

const _nbaChampions1990To2025 = '''
2025 NBA Finals|Oklahoma City Thunder|2025
2024 NBA Finals|Boston Celtics|2024
2023 NBA Finals|Denver Nuggets|2023
2022 NBA Finals|Golden State Warriors|2022
2021 NBA Finals|Milwaukee Bucks|2021
2020 NBA Finals|Los Angeles Lakers|2020
2019 NBA Finals|Toronto Raptors|2019
2018 NBA Finals|Golden State Warriors|2018
2017 NBA Finals|Golden State Warriors|2017
2016 NBA Finals|Cleveland Cavaliers|2016
2015 NBA Finals|Golden State Warriors|2015
2014 NBA Finals|San Antonio Spurs|2014
2013 NBA Finals|Miami Heat|2013
2012 NBA Finals|Miami Heat|2012
2011 NBA Finals|Dallas Mavericks|2011
2010 NBA Finals|Los Angeles Lakers|2010
2009 NBA Finals|Los Angeles Lakers|2009
2008 NBA Finals|Boston Celtics|2008
2007 NBA Finals|San Antonio Spurs|2007
2006 NBA Finals|Miami Heat|2006
2005 NBA Finals|San Antonio Spurs|2005
2004 NBA Finals|Detroit Pistons|2004
2003 NBA Finals|San Antonio Spurs|2003
2002 NBA Finals|Los Angeles Lakers|2002
2001 NBA Finals|Los Angeles Lakers|2001
2000 NBA Finals|Los Angeles Lakers|2000
1999 NBA Finals|San Antonio Spurs|1999
1998 NBA Finals|Chicago Bulls|1998
1997 NBA Finals|Chicago Bulls|1997
1996 NBA Finals|Chicago Bulls|1996
1995 NBA Finals|Houston Rockets|1995
1994 NBA Finals|Houston Rockets|1994
1993 NBA Finals|Chicago Bulls|1993
1992 NBA Finals|Chicago Bulls|1992
1991 NBA Finals|Chicago Bulls|1991
1990 NBA Finals|Detroit Pistons|1990
''';

const _nbaChampions1947To1989 = '''
1989 NBA Finals|Detroit Pistons|1989
1988 NBA Finals|Los Angeles Lakers|1988
1987 NBA Finals|Los Angeles Lakers|1987
1986 NBA Finals|Boston Celtics|1986
1985 NBA Finals|Los Angeles Lakers|1985
1984 NBA Finals|Boston Celtics|1984
1983 NBA Finals|Philadelphia 76ers|1983
1982 NBA Finals|Los Angeles Lakers|1982
1981 NBA Finals|Boston Celtics|1981
1980 NBA Finals|Los Angeles Lakers|1980
1979 NBA Finals|Seattle SuperSonics|1979
1978 NBA Finals|Washington Bullets|1978
1977 NBA Finals|Portland Trail Blazers|1977
1976 NBA Finals|Boston Celtics|1976
1975 NBA Finals|Golden State Warriors|1975
1974 NBA Finals|Boston Celtics|1974
1973 NBA Finals|New York Knicks|1973
1972 NBA Finals|Los Angeles Lakers|1972
1971 NBA Finals|Milwaukee Bucks|1971
1970 NBA Finals|New York Knicks|1970
1969 NBA Finals|Boston Celtics|1969
1968 NBA Finals|Boston Celtics|1968
1967 NBA Finals|Philadelphia 76ers|1967
1966 NBA Finals|Boston Celtics|1966
1965 NBA Finals|Boston Celtics|1965
1964 NBA Finals|Boston Celtics|1964
1963 NBA Finals|Boston Celtics|1963
1962 NBA Finals|Boston Celtics|1962
1961 NBA Finals|Boston Celtics|1961
1960 NBA Finals|Boston Celtics|1960
1959 NBA Finals|Boston Celtics|1959
1958 NBA Finals|St. Louis Hawks|1958
1957 NBA Finals|Boston Celtics|1957
1956 NBA Finals|Philadelphia Warriors|1956
1955 NBA Finals|Syracuse Nationals|1955
1954 NBA Finals|Minneapolis Lakers|1954
1953 NBA Finals|Minneapolis Lakers|1953
1952 NBA Finals|Minneapolis Lakers|1952
1951 NBA Finals|Rochester Royals|1951
1950 NBA Finals|Minneapolis Lakers|1950
1949 BAA Finals|Minneapolis Lakers|1949
1948 BAA Finals|Baltimore Bullets|1948
1947 BAA Finals|Philadelphia Warriors|1947
''';

const _wnbaChampions2011To2025 = '''
2025 WNBA Finals|Las Vegas Aces|2025
2024 WNBA Finals|New York Liberty|2024
2023 WNBA Finals|Las Vegas Aces|2023
2022 WNBA Finals|Las Vegas Aces|2022
2021 WNBA Finals|Chicago Sky|2021
2020 WNBA Finals|Seattle Storm|2020
2019 WNBA Finals|Washington Mystics|2019
2018 WNBA Finals|Seattle Storm|2018
2017 WNBA Finals|Minnesota Lynx|2017
2016 WNBA Finals|Los Angeles Sparks|2016
2015 WNBA Finals|Minnesota Lynx|2015
2014 WNBA Finals|Phoenix Mercury|2014
2013 WNBA Finals|Minnesota Lynx|2013
2012 WNBA Finals|Indiana Fever|2012
2011 WNBA Finals|Minnesota Lynx|2011
''';

const _wnbaChampions1997To2010 = '''
2010 WNBA Finals|Seattle Storm|2010
2009 WNBA Finals|Phoenix Mercury|2009
2008 WNBA Finals|Detroit Shock|2008
2007 WNBA Finals|Phoenix Mercury|2007
2006 WNBA Finals|Detroit Shock|2006
2005 WNBA Finals|Sacramento Monarchs|2005
2004 WNBA Finals|Seattle Storm|2004
2003 WNBA Finals|Detroit Shock|2003
2002 WNBA Finals|Los Angeles Sparks|2002
2001 WNBA Finals|Los Angeles Sparks|2001
2000 WNBA Finals|Houston Comets|2000
1999 WNBA Finals|Houston Comets|1999
1998 WNBA Finals|Houston Comets|1998
1997 WNBA Finals|Houston Comets|1997
''';

const _fibaMenRecentChampions = '''
2023 FIBA Basketball World Cup|Germany|2023
2019 FIBA Basketball World Cup|Spain|2019
2014 FIBA Basketball World Cup|United States|2014
2010 FIBA World Championship|United States|2010
2006 FIBA World Championship|Spain|2006
2002 FIBA World Championship|Yugoslavia|2002
2024 men’s Olympic tournament|United States|2024
2020 men’s Olympic tournament|United States|2021
2016 men’s Olympic tournament|United States|2016
2012 men’s Olympic tournament|United States|2012
2008 men’s Olympic tournament|United States|2008
2004 men’s Olympic tournament|Argentina|2004
2000 men’s Olympic tournament|United States|2000
''';

const _fibaMenHistoricChampions = '''
1998 FIBA World Championship|Yugoslavia|1998
1994 FIBA World Championship|United States|1994
1990 FIBA World Championship|Yugoslavia|1990
1986 FIBA World Championship|United States|1986
1982 FIBA World Championship|Soviet Union|1982
1978 FIBA World Championship|Yugoslavia|1978
1974 FIBA World Championship|Soviet Union|1974
1970 FIBA World Championship|Yugoslavia|1970
1967 FIBA World Championship|Soviet Union|1967
1963 FIBA World Championship|Brazil|1963
1959 FIBA World Championship|Brazil|1959
1954 FIBA World Championship|United States|1954
1950 FIBA World Championship|Argentina|1950
1996 men’s Olympic tournament|United States|1996
1992 men’s Olympic tournament|United States|1992
1988 men’s Olympic tournament|Soviet Union|1988
1984 men’s Olympic tournament|United States|1984
1980 men’s Olympic tournament|Yugoslavia|1980
1976 men’s Olympic tournament|United States|1976
1972 men’s Olympic tournament|Soviet Union|1972
1968 men’s Olympic tournament|United States|1968
1964 men’s Olympic tournament|United States|1964
1960 men’s Olympic tournament|United States|1960
1956 men’s Olympic tournament|United States|1956
1952 men’s Olympic tournament|United States|1952
1948 men’s Olympic tournament|United States|1948
1936 men’s Olympic tournament|United States|1936
''';

const _fibaMenHosts = '''
1950 FIBA World Championship|Argentina|1950
1954 FIBA World Championship|Brazil|1954
1959 FIBA World Championship|Chile|1959
1963 FIBA World Championship|Brazil|1963
1967 FIBA World Championship|Uruguay|1967
1970 FIBA World Championship|Yugoslavia|1970
1974 FIBA World Championship|Puerto Rico|1974
1978 FIBA World Championship|Philippines|1978
1982 FIBA World Championship|Colombia|1982
1986 FIBA World Championship|Spain|1986
1990 FIBA World Championship|Argentina|1990
1994 FIBA World Championship|Canada|1994
1998 FIBA World Championship|Greece|1998
2002 FIBA World Championship|United States|2002
2006 FIBA World Championship|Japan|2006
2010 FIBA World Championship|Türkiye|2010
2014 FIBA Basketball World Cup|Spain|2014
2019 FIBA Basketball World Cup|China|2019
2023 FIBA Basketball World Cup|Philippines, Japan & Indonesia|2023
1936 men’s Olympic tournament|Berlin|1936
1948 men’s Olympic tournament|London|1948
1952 men’s Olympic tournament|Helsinki|1952
1956 men’s Olympic tournament|Melbourne|1956
1960 men’s Olympic tournament|Rome|1960
1964 men’s Olympic tournament|Tokyo|1964
1968 men’s Olympic tournament|Mexico City|1968
1972 men’s Olympic tournament|Munich|1972
1976 men’s Olympic tournament|Montreal|1976
1980 men’s Olympic tournament|Moscow|1980
1984 men’s Olympic tournament|Los Angeles|1984
1988 men’s Olympic tournament|Seoul|1988
1992 men’s Olympic tournament|Barcelona|1992
1996 men’s Olympic tournament|Atlanta|1996
2000 men’s Olympic tournament|Sydney|2000
2004 men’s Olympic tournament|Athens|2004
2008 men’s Olympic tournament|Beijing|2008
2012 men’s Olympic tournament|London|2012
2016 men’s Olympic tournament|Rio de Janeiro|2016
2020 men’s Olympic tournament|Tokyo|2021
2024 men’s Olympic tournament|Paris|2024
''';

const _fibaWomenRecentChampions = '''
2022 FIBA Women’s World Cup|United States|2022
2018 FIBA Women’s World Cup|United States|2018
2014 FIBA Women’s World Championship|United States|2014
2010 FIBA Women’s World Championship|United States|2010
2011 FIBA Women’s EuroBasket|Russia|2011
2002 FIBA Women’s World Championship|United States|2002
2024 women’s Olympic tournament|United States|2024
2020 women’s Olympic tournament|United States|2021
2016 women’s Olympic tournament|United States|2016
2012 women’s Olympic tournament|United States|2012
2023 FIBA Women’s EuroBasket|Belgium|2023
2019 FIBA Women’s EuroBasket|Spain|2019
2015 FIBA Women’s EuroBasket|Serbia|2015
''';

const _fibaWomenHistoricChampions = '''
1998 FIBA Women’s World Championship|United States|1998
2006 FIBA Women’s World Championship|Australia|2006
1994 FIBA Women’s World Championship|Brazil|1994
1990 FIBA Women’s World Championship|United States|1990
1986 FIBA Women’s World Championship|United States|1986
1983 FIBA Women’s World Championship|Soviet Union|1983
1979 FIBA Women’s World Championship|United States|1979
1975 FIBA Women’s World Championship|Soviet Union|1975
1971 FIBA Women’s World Championship|Soviet Union|1971
1967 FIBA Women’s World Championship|Soviet Union|1967
1964 FIBA Women’s World Championship|Soviet Union|1964
1959 FIBA Women’s World Championship|Soviet Union|1959
1957 FIBA Women’s World Championship|United States|1957
1953 FIBA Women’s World Championship|United States|1953
''';

const _fibaWomenHosts = '''
1953 FIBA Women’s World Championship|Chile|1953
1957 FIBA Women’s World Championship|Brazil|1957
1959 FIBA Women’s World Championship|Soviet Union|1959
1964 FIBA Women’s World Championship|Peru|1964
1967 FIBA Women’s World Championship|Czechoslovakia|1967
1971 FIBA Women’s World Championship|Brazil|1971
1975 FIBA Women’s World Championship|Colombia|1975
1979 FIBA Women’s World Championship|South Korea|1979
1983 FIBA Women’s World Championship|Brazil|1983
1986 FIBA Women’s World Championship|Soviet Union|1986
1990 FIBA Women’s World Championship|Malaysia|1990
1994 FIBA Women’s World Championship|Australia|1994
1998 FIBA Women’s World Championship|Germany|1998
2002 FIBA Women’s World Championship|China|2002
2006 FIBA Women’s World Championship|Brazil|2006
2010 FIBA Women’s World Championship|Czech Republic|2010
2014 FIBA Women’s World Championship|Türkiye|2014
2018 FIBA Women’s World Cup|Spain|2018
2022 FIBA Women’s World Cup|Australia|2022
1976 women’s Olympic tournament|Montreal|1976
1980 women’s Olympic tournament|Moscow|1980
1984 women’s Olympic tournament|Los Angeles|1984
1988 women’s Olympic tournament|Seoul|1988
1992 women’s Olympic tournament|Barcelona|1992
1996 women’s Olympic tournament|Atlanta|1996
2000 women’s Olympic tournament|Sydney|2000
2004 women’s Olympic tournament|Athens|2004
2008 women’s Olympic tournament|Beijing|2008
2012 women’s Olympic tournament|London|2012
2016 women’s Olympic tournament|Rio de Janeiro|2016
2020 women’s Olympic tournament|Tokyo|2021
2024 women’s Olympic tournament|Paris|2024
''';

const _ncaaMen2021To2025 = '''
2025 NCAA men’s tournament|Florida|2025
2024 NCAA men’s tournament|UConn|2024
2023 NCAA men’s tournament|UConn|2023
2022 NCAA men’s tournament|Kansas|2022
2021 NCAA men’s tournament|Baylor|2021
''';

const _ncaaMen2010To2019 = '''
2019 NCAA men’s tournament|Virginia|2019
2018 NCAA men’s tournament|Villanova|2018
2017 NCAA men’s tournament|North Carolina|2017
2016 NCAA men’s tournament|Villanova|2016
2015 NCAA men’s tournament|Duke|2015
2014 NCAA men’s tournament|UConn|2014
2012 NCAA men’s tournament|Kentucky|2012
2011 NCAA men’s tournament|UConn|2011
2010 NCAA men’s tournament|Duke|2010
''';

const _ncaaMen1990To2009 = '''
2009 NCAA men’s tournament|North Carolina|2009
2008 NCAA men’s tournament|Kansas|2008
2007 NCAA men’s tournament|Florida|2007
2006 NCAA men’s tournament|Florida|2006
2005 NCAA men’s tournament|North Carolina|2005
2004 NCAA men’s tournament|UConn|2004
2003 NCAA men’s tournament|Syracuse|2003
2002 NCAA men’s tournament|Maryland|2002
2001 NCAA men’s tournament|Duke|2001
2000 NCAA men’s tournament|Michigan State|2000
1999 NCAA men’s tournament|UConn|1999
1998 NCAA men’s tournament|Kentucky|1998
1997 NCAA men’s tournament|Arizona|1997
1996 NCAA men’s tournament|Kentucky|1996
1995 NCAA men’s tournament|UCLA|1995
1994 NCAA men’s tournament|Arkansas|1994
1993 NCAA men’s tournament|North Carolina|1993
1992 NCAA men’s tournament|Duke|1992
1991 NCAA men’s tournament|Duke|1991
1990 NCAA men’s tournament|UNLV|1990
''';

const _ncaaMen1939To1963 = '''
1963 NCAA men’s tournament|Loyola Chicago|1963
1962 NCAA men’s tournament|Cincinnati|1962
1961 NCAA men’s tournament|Cincinnati|1961
1960 NCAA men’s tournament|Ohio State|1960
1959 NCAA men’s tournament|California|1959
1958 NCAA men’s tournament|Kentucky|1958
1957 NCAA men’s tournament|North Carolina|1957
1956 NCAA men’s tournament|San Francisco|1956
1955 NCAA men’s tournament|San Francisco|1955
1954 NCAA men’s tournament|La Salle|1954
1953 NCAA men’s tournament|Indiana|1953
1952 NCAA men’s tournament|Kansas|1952
1951 NCAA men’s tournament|Kentucky|1951
1950 NCAA men’s tournament|CCNY|1950
1949 NCAA men’s tournament|Kentucky|1949
1948 NCAA men’s tournament|Kentucky|1948
1947 NCAA men’s tournament|Holy Cross|1947
1946 NCAA men’s tournament|Oklahoma A&M|1946
1945 NCAA men’s tournament|Oklahoma A&M|1945
1944 NCAA men’s tournament|Utah|1944
1943 NCAA men’s tournament|Wyoming|1943
1942 NCAA men’s tournament|Stanford|1942
1941 NCAA men’s tournament|Wisconsin|1941
1940 NCAA men’s tournament|Indiana|1940
1939 NCAA men’s tournament|Oregon|1939
''';

const _ncaaWomen2021To2025 = '''
2025 NCAA women’s tournament|UConn|2025
2024 NCAA women’s tournament|South Carolina|2024
2023 NCAA women’s tournament|LSU|2023
2022 NCAA women’s tournament|South Carolina|2022
2021 NCAA women’s tournament|Stanford|2021
''';

const _ncaaWomen2011To2019 = '''
2019 NCAA women’s tournament|Baylor|2019
2018 NCAA women’s tournament|Notre Dame|2018
2017 NCAA women’s tournament|South Carolina|2017
2016 NCAA women’s tournament|UConn|2016
2015 NCAA women’s tournament|UConn|2015
2014 NCAA women’s tournament|UConn|2014
2013 NCAA women’s tournament|UConn|2013
2012 NCAA women’s tournament|Baylor|2012
2011 NCAA women’s tournament|Texas A&M|2011
''';

const _ncaaWomen2001To2010 = '''
2010 NCAA women’s tournament|UConn|2010
2009 NCAA women’s tournament|UConn|2009
2008 NCAA women’s tournament|Tennessee|2008
2007 NCAA women’s tournament|Tennessee|2007
2006 NCAA women’s tournament|Maryland|2006
2005 NCAA women’s tournament|Baylor|2005
2004 NCAA women’s tournament|UConn|2004
2003 NCAA women’s tournament|UConn|2003
2002 NCAA women’s tournament|UConn|2002
2001 NCAA women’s tournament|Notre Dame|2001
''';

const _ncaaWomen1982To2000 = '''
2000 NCAA women’s tournament|UConn|2000
1999 NCAA women’s tournament|Purdue|1999
1998 NCAA women’s tournament|Tennessee|1998
1997 NCAA women’s tournament|Tennessee|1997
1996 NCAA women’s tournament|Tennessee|1996
1995 NCAA women’s tournament|UConn|1995
1994 NCAA women’s tournament|North Carolina|1994
1993 NCAA women’s tournament|Texas Tech|1993
1992 NCAA women’s tournament|Stanford|1992
1991 NCAA women’s tournament|Tennessee|1991
1990 NCAA women’s tournament|Stanford|1990
1989 NCAA women’s tournament|Tennessee|1989
1988 NCAA women’s tournament|Louisiana Tech|1988
1987 NCAA women’s tournament|Tennessee|1987
1986 NCAA women’s tournament|Texas|1986
1985 NCAA women’s tournament|Old Dominion|1985
1984 NCAA women’s tournament|USC|1984
1983 NCAA women’s tournament|USC|1983
1982 NCAA women’s tournament|Louisiana Tech|1982
''';

const _euroleagueChampions2016To2025 = '''
2025 EuroLeague Final|Fenerbahce|2025
2024 EuroLeague Final|Panathinaikos|2024
2023 EuroLeague Final|Real Madrid|2023
2022 EuroLeague Final|Anadolu Efes|2022
2021 EuroLeague Final|Anadolu Efes|2021
2019 EuroLeague Final|CSKA Moscow|2019
2018 EuroLeague Final|Real Madrid|2018
2017 EuroLeague Final|Fenerbahce|2017
2016 EuroLeague Final|CSKA Moscow|2016
''';

const _euroleagueChampions2002To2015 = '''
2015 EuroLeague Final|Real Madrid|2015
2014 EuroLeague Final|Maccabi Tel Aviv|2014
2013 EuroLeague Final|Olympiacos|2013
2012 EuroLeague Final|Olympiacos|2012
2011 EuroLeague Final|Panathinaikos|2011
2010 EuroLeague Final|FC Barcelona|2010
2009 EuroLeague Final|Panathinaikos|2009
2008 EuroLeague Final|CSKA Moscow|2008
2007 EuroLeague Final|Panathinaikos|2007
2006 EuroLeague Final|CSKA Moscow|2006
2005 EuroLeague Final|Maccabi Tel Aviv|2005
2004 EuroLeague Final|Maccabi Tel Aviv|2004
2003 EuroLeague Final|FC Barcelona|2003
2002 EuroLeague Final|Panathinaikos|2002
''';
