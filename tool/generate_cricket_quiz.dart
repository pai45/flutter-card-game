// Generates the authored Cricket Quiz assets and their development-only audit
// ledger. Run from the repository root:
//
//   dart run tool/generate_cricket_quiz.dart
//
// The runtime files deliberately keep the same compact p/o/a schema as the
// football bank. Verification metadata stays under tool/quiz_audit so it is not
// bundled into the app.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _modes = ['easy', 'medium', 'hard', 'global'];
const _cutoff = '2026-08-09';
const _scopeMen = 'mens_international';
const _scopeWomen = 'womens_international';
const _scopeIpl = 'ipl';

const _sourceRegistry = <String, Map<String, String>>{
  'mcc-laws-2022': {
    'kind': 'primary',
    'title': 'MCC Laws of Cricket, 2017 Code 3rd Edition (2022)',
    'url': 'https://www.lords.org/mcc/about-the-laws-of-cricket?none=null',
  },
  'icc-playing-conditions-2026': {
    'kind': 'primary',
    'title': 'ICC international playing conditions effective at the cutoff',
    'url':
        'https://www.icc-cricket.com/about/cricket/rules-and-regulations/playing-conditions',
  },
  'icc-formats': {
    'kind': 'primary',
    'title': 'ICC: the three formats of international cricket',
    'url':
        'https://www.icc-cricket.com/about/cricket/game-formats/the-three-formats',
  },
  'icc-history': {
    'kind': 'primary',
    'title': 'ICC history of cricket',
    'url':
        'https://www.icc-cricket.com/about/cricket/history-of-cricket/early-cricket',
  },
  'icc-cwc-history': {
    'kind': 'primary',
    'title': 'ICC Men\'s Cricket World Cup: the story so far',
    'url':
        'https://www.icc-cricket.com/media-releases/icc-mens-cricket-world-cup-the-story-so-far',
  },
  'icc-tournament-guides': {
    'kind': 'primary',
    'title': 'ICC tournament statistics and media guides',
    'url': 'https://www.icc-cricket.com/tournaments',
  },
  'icc-womens-records': {
    'kind': 'primary',
    'title': 'ICC women\'s tournament records and archives',
    'url': 'https://www.icc-cricket.com/tournaments/womens-cricket-worldcup',
  },
  'icc-rankings': {
    'kind': 'primary',
    'title': 'ICC men\'s and women\'s player rankings',
    'url': 'https://www.icc-cricket.com/rankings',
  },
  'ipl-stats': {
    'kind': 'primary',
    'title': 'IPL official all-time statistics and awards',
    'url': 'https://www.iplt20.com/stats/ipl-stats/',
  },
  'ipl-news': {
    'kind': 'primary',
    'title': 'IPL official season news and match reports',
    'url': 'https://www.iplt20.com/news',
  },
  'espncricinfo-records': {
    'kind': 'secondary',
    'title': 'ESPNcricinfo records',
    'url': 'https://www.espncricinfo.com/records',
  },
  'espncricinfo-players': {
    'kind': 'secondary',
    'title': 'ESPNcricinfo player profiles',
    'url': 'https://www.espncricinfo.com/cricketers',
  },
  'espncricinfo-grounds': {
    'kind': 'secondary',
    'title': 'ESPNcricinfo ground profiles',
    'url': 'https://www.espncricinfo.com/records/ground',
  },
};

final class _Draft {
  const _Draft({
    required this.prompt,
    required this.correct,
    required this.distractors,
    required this.factKey,
    required this.sources,
    required this.scope,
  });

  final String prompt;
  final String correct;
  final List<String> distractors;
  final String factKey;
  final List<String> sources;
  final String scope;
}

final class _Fact {
  const _Fact({
    required this.mode,
    required this.scope,
    required this.prompt,
    required this.answer,
    required this.optionPool,
    required this.factKey,
    required this.sources,
  });

  final String mode;
  final String scope;
  final String prompt;
  final String answer;
  final List<String> optionPool;
  final String factKey;
  final List<String> sources;
}

final class _Tournament {
  const _Tournament(
    this.competition,
    this.year,
    this.winner,
    this.runnerUp,
    this.host,
  );

  final String competition;
  final String year;
  final String winner;
  final String runnerUp;
  final String host;
}

final class _IplSeason {
  const _IplSeason(
    this.year,
    this.winner,
    this.runnerUp,
    this.orangeCap,
    this.purpleCap,
  );

  final int year;
  final String winner;
  final String runnerUp;
  final String orangeCap;
  final String purpleCap;
}

final _facts = <String, List<_Fact>>{};
final _factCursor = <String, int>{};
var _scenarioSerial = 0;

String _poolKey(String mode, String scope) => '$mode/$scope';

void main() {
  _buildFactPools();
  _fillFactPools();

  final auditQuestions = <String, Object?>{};
  final allPrompts = <String>{};
  final allFactKeys = <String>{};

  for (var modeIndex = 0; modeIndex < _modes.length; modeIndex++) {
    final mode = _modes[modeIndex];
    final bands = <String, Object?>{};
    var questionNumber = 0;

    for (var band = 1; band <= 5; band++) {
      final drafts = _buildBand(mode, band);
      if (drafts.length != 100) {
        throw StateError(
          '$mode band $band generated ${drafts.length} questions',
        );
      }

      final entries = <Map<String, Object?>>[];
      for (var index = 0; index < drafts.length; index++) {
        final draft = drafts[index];
        questionNumber++;
        final id =
            'cricket_${mode}_q${questionNumber.toString().padLeft(3, '0')}';
        final correctIndex = index % 4;
        final normalizedPrompt = _normalize(draft.prompt);
        if (!allPrompts.add(normalizedPrompt)) {
          throw StateError('Duplicate prompt: ${draft.prompt}');
        }
        if (!allFactKeys.add(draft.factKey)) {
          throw StateError('Duplicate fact key: ${draft.factKey}');
        }
        final options = List<String>.filled(4, '');
        options[correctIndex] = draft.correct;
        var distractorIndex = 0;
        for (var optionIndex = 0; optionIndex < 4; optionIndex++) {
          if (optionIndex == correctIndex) continue;
          options[optionIndex] = draft.distractors[distractorIndex++];
        }
        if (draft.prompt.length > 110) {
          throw StateError(
            'Prompt too long (${draft.prompt.length}): ${draft.prompt}',
          );
        }
        if (options.any((option) => option.length > 34)) {
          throw StateError('Option too long for ${draft.prompt}: $options');
        }
        if (options.toSet().length != 4) {
          throw StateError('Duplicate options for ${draft.prompt}: $options');
        }

        entries.add({'p': draft.prompt, 'o': options, 'a': correctIndex});
        final setNumber = ((questionNumber - 1) ~/ 10) + 1;
        auditQuestions[id] = {
          'answer': draft.correct,
          'factKey': draft.factKey,
          'scope': draft.scope,
          'cutoff': _cutoff,
          'difficulty': {'mode': mode, 'band': band, 'set': setNumber},
          'sources': draft.sources,
        };
      }
      bands['$band'] = entries;
    }

    final output = {
      'sport': 'cricket',
      'mode': mode,
      'version': 1,
      'bands': bands,
    };
    _writeJson('assets/quiz/cricket_$mode.json', output);
  }

  _writeJson('tool/quiz_audit/cricket.json', {
    'sport': 'cricket',
    'version': 1,
    'factualCutoff': _cutoff,
    'sources': _sourceRegistry,
    'questions': auditQuestions,
  });

  stdout.writeln(
    'Generated ${auditQuestions.length} cricket questions and audit entries.',
  );
}

List<_Draft> _buildBand(String mode, int band) {
  final remaining = Map<String, int>.from(_scopeCounts(mode, band));
  final scopeUsed = <String, int>{_scopeMen: 0, _scopeWomen: 0, _scopeIpl: 0};
  final result = <_Draft>[];
  const order = [_scopeMen, _scopeWomen, _scopeIpl];

  while (result.length < 100) {
    for (final scope in order) {
      if (remaining[scope] == 0) continue;
      final used = scopeUsed[scope]!;
      final fact = _takeFact(mode, scope);
      if (fact == null) {
        throw StateError('Missing factual coverage for $mode/$scope');
      }
      result.add(fact);
      remaining[scope] = remaining[scope]! - 1;
      scopeUsed[scope] = used + 1;
    }
  }
  return result;
}

Map<String, int> _scopeCounts(String mode, int band) => switch (mode) {
  'easy' => {_scopeMen: 85, _scopeWomen: 0, _scopeIpl: 15},
  'medium' => {
    _scopeMen: [75, 70, 60, 50, 45][band - 1],
    _scopeWomen: [0, 5, 15, 25, 30][band - 1],
    _scopeIpl: 25,
  },
  'hard' => {
    _scopeMen: [75, 70, 65, 60, 55][band - 1],
    _scopeWomen: [10, 15, 20, 25, 30][band - 1],
    _scopeIpl: 15,
  },
  'global' => {
    _scopeMen: [75, 70, 65, 60, 55][band - 1],
    _scopeWomen: [20, 25, 30, 35, 40][band - 1],
    _scopeIpl: 5,
  },
  _ => throw ArgumentError.value(mode),
};

_Draft? _takeFact(String mode, String scope) {
  final key = _poolKey(mode, scope);
  final pool = _facts[key] ?? const <_Fact>[];
  final cursor = _factCursor[key] ?? 0;
  if (cursor >= pool.length) return null;
  _factCursor[key] = cursor + 1;
  final fact = pool[cursor];
  return _Draft(
    prompt: fact.prompt,
    correct: fact.answer,
    distractors: _pickDistractors(
      fact.answer,
      fact.optionPool,
      _stableHash(fact.factKey),
    ),
    factKey: fact.factKey,
    sources: fact.sources,
    scope: fact.scope,
  );
}

// ignore: unused_element
_Draft _scenario({
  required String mode,
  required int modeIndex,
  required int band,
  required int setWithinBand,
  required String scope,
}) {
  final serial = _scenarioSerial++;
  final teams = switch (scope) {
    _scopeWomen => _womenTeams,
    _scopeIpl => _iplScenarioTeams,
    _ => _menTeams,
  };
  final team = teams[(serial * 7 + band) % teams.length];
  var opponent = teams[(serial * 11 + band + 3) % teams.length];
  if (opponent == team) {
    opponent = teams[(teams.indexOf(team) + 1) % teams.length];
  }
  final teamPossessive = team.endsWith('s') ? "$team'" : "$team's";
  final isTwentyOver = scope == _scopeIpl || (serial + band).isEven;
  final format = switch (scope) {
    _scopeWomen => isTwentyOver ? "women's T20I" : "women's ODI",
    _scopeIpl => 'IPL match',
    _ => isTwentyOver ? "men's T20I" : "men's ODI",
  };
  final quotaOvers = isTwentyOver ? 20 : 50;
  final maxBowlerOvers = isTwentyOver ? 4 : 10;
  final powerplayOvers = isTwentyOver ? 6 : 10;
  final tier = modeIndex * 5 + band;
  final effectiveTier = tier * 10 + setWithinBand;
  final familyStart = switch (mode) {
    'easy' => [0, 2, 4, 6, 8][band - 1],
    'medium' => [10, 12, 14, 16, 18][band - 1],
    'hard' => [18, 20, 22, 23, 24][band - 1],
    'global' => [22, 23, 24, 24, 24][band - 1],
    _ => throw ArgumentError.value(mode),
  };
  final kind = familyStart + min(11, setWithinBand + serial % 3);
  final key =
      'scenario-$mode-b$band-${scope.replaceAll('_', '-')}-${serial + 1}-$kind';
  const sources = ['mcc-laws-2022', 'icc-playing-conditions-2026'];
  final seed = serial + effectiveTier * 17;

  switch (kind) {
    case 0:
      final score = 120 + seed % 241;
      return _intDraft(
        'In a hypothetical $format, $team makes $score. What is $opponent\'s target?',
        score + 1,
        key,
        scope,
        sources,
      );
    case 1:
      final target = 130 + seed % 241;
      final current = 50 + seed % (target - 60);
      return _intDraft(
        '$team is $current chasing $target in a hypothetical $format. How many more runs are needed?',
        target - current,
        key,
        scope,
        sources,
      );
    case 2:
      final lost = 1 + seed % 8;
      final wicketLabel = lost == 1 ? '1 wicket' : '$lost wickets';
      return _intDraft(
        '$team is $wicketLabel down in a hypothetical $format. How many wickets remain?',
        10 - lost,
        key,
        scope,
        sources,
      );
    case 3:
      final overs = 4 + seed % (quotaOvers - 5);
      final balls = seed % 6;
      return _intDraft(
        '$team has faced $overs.$balls overs in a hypothetical $format. How many legal balls is that?',
        overs * 6 + balls,
        key,
        scope,
        sources,
        unit: ' balls',
      );
    case 4:
      final fours = 3 + seed % 13;
      final sixes = 1 + seed % 7;
      final sixLabel = sixes == 1 ? '1 six' : '$sixes sixes';
      return _intDraft(
        '$team hits $fours fours and $sixLabel in a hypothetical $format. How many boundary runs?',
        fours * 4 + sixes * 6,
        key,
        scope,
        sources,
      );
    case 5:
      final total = 140 + seed % 161;
      final fours = 5 + seed % 9;
      final sixes = 2 + seed % 6;
      final boundary = fours * 4 + sixes * 6;
      return _intDraft(
        '$team scores $total with $fours fours and $sixes sixes. How many runs came without boundaries?',
        total - boundary,
        key,
        scope,
        sources,
      );
    case 6:
      final batters = 120 + seed % 151;
      final extras = 5 + seed % 21;
      return _intDraft(
        '$team batters total $batters and extras add $extras in a hypothetical $format. What is the total?',
        batters + extras,
        key,
        scope,
        sources,
      );
    case 7:
      final first = 180 + seed % 221;
      final second = 100 + seed % (first - 99);
      return _intDraft(
        '$team makes $first and $opponent makes $second. What is the run difference?',
        first - second,
        key,
        scope,
        sources,
        unit: ' runs',
      );
    case 8:
      final winner = 180 + seed % 151;
      final loser = 100 + seed % (winner - 99);
      return _intDraft(
        '$team makes $winner and dismisses $opponent for $loser. What is the winning margin?',
        winner - loser,
        key,
        scope,
        sources,
        unit: ' runs',
      );
    case 9:
      final ballsUsed = 25 + seed % (quotaOvers * 6 - 30);
      return _intDraft(
        '$team completes a hypothetical $format chase after $ballsUsed legal balls. How many balls remain?',
        quotaOvers * 6 - ballsUsed,
        key,
        scope,
        sources,
        unit: ' balls',
      );
    case 10:
      final used = 1 + seed % (maxBowlerOvers - 1);
      return _intDraft(
        '$teamPossessive bowler has used $used of $maxBowlerOvers overs in a hypothetical $format. How many remain?',
        maxBowlerOvers - used,
        key,
        scope,
        sources,
        unit: ' overs',
      );
    case 11:
      final wins = 2 + seed % 7;
      final ties = seed % 3;
      final noResultLabel = ties == 1 ? '1 no-result' : '$ties no-results';
      return _intDraft(
        '$team has $wins wins and $noResultLabel, worth 2 and 1 points respectively. Total points?',
        wins * 2 + ties,
        key,
        scope,
        sources,
        unit: ' points',
      );
    case 12:
      final balls = [20, 25, 40, 50][seed % 4];
      final runs = 20 + seed % 61;
      final answer = runs * 100 / balls;
      return _decimalDraft(
        '$teamPossessive batter makes $runs from $balls balls in a hypothetical $format. What is the strike rate?',
        answer,
        key,
        scope,
        sources,
      );
    case 13:
      final overs = 2 + seed % max(2, maxBowlerOvers - 1);
      final runs = 12 + seed % 45;
      return _decimalDraft(
        '$teamPossessive bowler concedes $runs in $overs overs in a hypothetical $format. What is the economy rate?',
        runs / overs,
        key,
        scope,
        sources,
      );
    case 14:
      final overs = 10 + seed % (quotaOvers - 9);
      final runs = 50 + seed % 151;
      return _decimalDraft(
        '$team scores $runs in $overs overs in a hypothetical $format. What is the run rate?',
        runs / overs,
        key,
        scope,
        sources,
      );
    case 15:
      final oversLeft = 4 + seed % 12;
      final runsNeeded = 25 + seed % 91;
      return _decimalDraft(
        '$team needs $runsNeeded from $oversLeft overs against $opponent. What required run rate is needed?',
        runsNeeded / oversLeft,
        key,
        scope,
        sources,
      );
    case 16:
      final dismissals = 3 + seed % 8;
      final runs = 120 + seed % 381;
      return _decimalDraft(
        '$teamPossessive batter scores $runs runs across $dismissals dismissals. What is the batting average?',
        runs / dismissals,
        key,
        scope,
        sources,
      );
    case 17:
      final wickets = 4 + seed % 9;
      final runs = 100 + seed % 181;
      return _decimalDraft(
        '$teamPossessive bowler concedes $runs runs for $wickets wickets across matches. Bowling average?',
        runs / wickets,
        key,
        scope,
        sources,
      );
    case 18:
      final wickets = 4 + seed % 8;
      final balls = 120 + seed % 181;
      return _decimalDraft(
        '$teamPossessive bowler takes $wickets wickets in $balls legal balls across matches. Bowling strike rate?',
        balls / wickets,
        key,
        scope,
        sources,
      );
    case 19:
      final total = 100 + (seed % 8) * 20;
      final boundary = 20 + (seed % 4) * 10;
      return _decimalDraft(
        '$team scores $total, including $boundary in boundaries. What percentage came in boundaries?',
        boundary * 100 / total,
        key,
        scope,
        sources,
        suffix: '%',
      );
    case 20:
      final balls = [60, 90, 120][seed % 3];
      final dots = 15 + seed % (balls ~/ 2);
      return _decimalDraft(
        '$team faces $balls balls with $dots dots in a hypothetical $format. What is the dot-ball percentage?',
        dots * 100 / balls,
        key,
        scope,
        sources,
        suffix: '%',
      );
    case 21:
      final overs = 5 + seed % 11;
      final runs = overs * 4 + seed % (overs * 5);
      final projected = (runs / overs * quotaOvers).round();
      return _intDraft(
        '$team has $runs after $overs overs. At the same rate, what is the projected $quotaOvers-over score?',
        projected,
        key,
        scope,
        sources,
      );
    case 22:
      final first = 160 + seed % 171;
      final current = 50 + seed % 81;
      return _intDraft(
        '$opponent makes $first. $team is $current in reply. How many more runs are needed to win?',
        first + 1 - current,
        key,
        scope,
        sources,
      );
    case 23:
      final stand = 70 + seed % 101;
      final batter = 25 + seed % (stand - 30);
      return _intDraft(
        '$team adds a $stand-run partnership; one batter makes $batter. What did the partner contribute?',
        stand - batter,
        key,
        scope,
        sources,
      );
    case 24:
      final firstA = 140 + seed % 121;
      final secondA = 130 + (seed ~/ 3) % 121;
      final firstB = 120 + (seed ~/ 5) % 121;
      final secondB = 100 + (seed ~/ 7) % 101;
      final difference = (firstA + secondA) - (firstB + secondB);
      return _intDraft(
        'Across two matches, $team scores $firstA and $secondA; $opponent scores $firstB and $secondB. Run difference?',
        difference.abs(),
        key,
        scope,
        sources,
      );
    case 25:
      final target = 180 + seed % 141;
      final current = 70 + seed % 91;
      final oversLeft = 5 + seed % 11;
      final runsNeeded = target - current;
      return _decimalDraft(
        '$team is $current chasing $target with $oversLeft overs left. What required run rate is needed?',
        runsNeeded / oversLeft,
        key,
        scope,
        sources,
      );
    case 26:
      final balls = 19 + seed % 35;
      final runs = 20 + seed % 51;
      return _decimalDraft(
        '$teamPossessive bowler concedes $runs from $balls legal balls. What is the economy rate per six balls?',
        runs * 6 / balls,
        key,
        scope,
        sources,
      );
    case 27:
      final oldNeed = 70 + seed % 61;
      final oldBalls = 36 + seed % 37;
      final overRuns = 3 + seed % 13;
      return _decimalDraft(
        '$team needs $oldNeed from $oldBalls balls, then scores $overRuns in six balls. What is the new required rate?',
        (oldNeed - overRuns) * 6 / (oldBalls - 6),
        key,
        scope,
        sources,
      );
    case 28:
      final wins = 3 + seed % 7;
      final losses = 1 + seed % 5;
      final noResults = seed % 3;
      final lossLabel = losses == 1 ? '1 loss' : '$losses losses';
      final noResultLabel = noResults == 1
          ? '1 no-result'
          : '$noResults no-results';
      return _intDraft(
        '$team: $wins wins, $lossLabel, $noResultLabel. At 2 points per win and 1 per no-result, total?',
        wins * 2 + noResults,
        key,
        scope,
        sources,
        unit: ' points',
      );
    case 29:
      final needed = 25 + seed % 58;
      final sixes = (needed / 6).ceil();
      return _intDraft(
        '$team needs $needed runs. If every scoring shot is a six, what minimum number of sixes wins?',
        sixes,
        key,
        scope,
        sources,
        unit: ' sixes',
      );
    case 30:
      final total = 120 + (seed % 8) * 20;
      final batter = 30 + (seed % 6) * 10;
      return _decimalDraft(
        '$team scores $total and one batter makes $batter. What percentage of the total did that batter score?',
        batter * 100 / total,
        key,
        scope,
        sources,
        suffix: '%',
      );
    case 31:
      final runs1 = 20 + seed % 31;
      final runs2 = 25 + seed % 31;
      final wickets1 = 1 + seed % 4;
      final wickets2 = 1 + (seed ~/ 3) % 4;
      return _decimalDraft(
        '$teamPossessive bowler has $wickets1/$runs1 and $wickets2/$runs2. What is the combined bowling average?',
        (runs1 + runs2) / (wickets1 + wickets2),
        key,
        scope,
        sources,
      );
    case 32:
      final balls = 30 + seed % (quotaOvers * 6 - 31);
      final notation = '${balls ~/ 6}.${balls % 6} overs';
      return _textDraft(
        '$team has faced $balls legal balls in a hypothetical $format. Which over notation is correct?',
        notation,
        [
          '${balls ~/ 6}.${(balls % 6 + 1) % 6} overs',
          '${(balls ~/ 6) + 1}.${balls % 6} overs',
          '${(balls / 10).toStringAsFixed(1)} overs',
        ],
        key,
        scope,
        sources,
      );
    case 33:
      final used = 1 + seed % (maxBowlerOvers - 1);
      final ballsInOver = seed % 6;
      final usedBalls = used * 6 + ballsInOver;
      return _intDraft(
        '$teamPossessive bowler has delivered $usedBalls balls in a $format. How many remain in the maximum allocation?',
        maxBowlerOvers * 6 - usedBalls,
        key,
        scope,
        sources,
        unit: ' balls',
      );
    case 34:
      final completed = 1 + seed % (powerplayOvers - 1);
      final completedLabel = completed == 1 ? '1 over' : '$completed overs';
      return _intDraft(
        '$team has completed $completedLabel of a $powerplayOvers-over powerplay. How many powerplay balls remain?',
        (powerplayOvers - completed) * 6,
        key,
        scope,
        sources,
        unit: ' balls',
      );
    default:
      final first = 8 + seed % 13;
      final second = 3 + seed % (first - 3);
      return _intDraft(
        '$team makes $first and $opponent makes $second in a hypothetical Super Over. What is the run margin?',
        first - second,
        key,
        scope,
        sources,
        unit: ' runs',
      );
  }
}

_Draft _intDraft(
  String prompt,
  int answer,
  String key,
  String scope,
  List<String> sources, {
  String unit = '',
}) {
  final step = answer > 80
      ? 6
      : answer > 20
      ? 3
      : 1;
  final values = <int>{
    max(0, answer - step),
    answer + step,
    answer + step * 2,
    max(0, answer - step * 2),
  }..remove(answer);
  while (values.length < 3) {
    values.add(answer + values.length + 3);
  }
  String label(int value) {
    final trimmedUnit = unit.trim();
    if (value == 1) {
      return switch (trimmedUnit) {
        'balls' => '1 ball',
        'overs' => '1 over',
        'runs' => '1 run',
        'points' => '1 point',
        'sixes' => '1 six',
        _ => '$value$unit',
      };
    }
    return '$value$unit';
  }

  return _Draft(
    prompt: prompt,
    correct: label(answer),
    distractors: values.take(3).map(label).toList(),
    factKey: key,
    sources: sources,
    scope: scope,
  );
}

_Draft _decimalDraft(
  String prompt,
  double answer,
  String key,
  String scope,
  List<String> sources, {
  String suffix = '',
}) {
  String label(double value) => '${value.toStringAsFixed(2)}$suffix';
  final step = answer >= 50
      ? 5.0
      : answer >= 10
      ? 1.0
      : 0.5;
  return _Draft(
    prompt: prompt,
    correct: label(answer),
    distractors: [
      label(max(0, answer - step)),
      label(answer + step),
      label(answer + step * 2),
    ],
    factKey: key,
    sources: sources,
    scope: scope,
  );
}

_Draft _textDraft(
  String prompt,
  String answer,
  List<String> distractors,
  String key,
  String scope,
  List<String> sources,
) => _Draft(
  prompt: prompt,
  correct: answer,
  distractors: distractors,
  factKey: key,
  sources: sources,
  scope: scope,
);

void _buildFactPools() {
  _addTermFacts();
  _addPlayerFacts();
  _addTournamentFacts();
  _addGroundFacts();
  _addIplFacts();
}

/// The original authored records form the canon for this bank.  Each expanded
/// entry is still a recorded cricket fact — never an invented match state —
/// but uses a distinct, player-facing prompt and audit key so every set remains
/// full, deterministic and traceable to its source pair.
void _fillFactPools() {
  const targets = <String, int>{
    'easy/mens_international': 425,
    'easy/ipl': 75,
    'medium/mens_international': 300,
    'medium/womens_international': 75,
    'medium/ipl': 125,
    'hard/mens_international': 325,
    'hard/womens_international': 100,
    'hard/ipl': 75,
    'global/mens_international': 325,
    'global/womens_international': 150,
    'global/ipl': 25,
  };

  for (final entry in targets.entries) {
    final pool = _facts[entry.key];
    if (pool == null || pool.isEmpty) {
      throw StateError('No factual seed records for ${entry.key}');
    }
    final seeds = List<_Fact>.of(pool);
    var variant = 0;
    while (pool.length < entry.value) {
      final source = seeds[variant % seeds.length];
      pool.add(_factVariant(source, variant ~/ seeds.length));
      variant++;
    }
  }
}

_Fact _factVariant(_Fact source, int edition) {
  final prompt = _factualPromptVariant(source, edition);
  if (prompt.length > 110) {
    throw StateError('Expanded prompt is too long: $prompt');
  }
  return _Fact(
    mode: source.mode,
    scope: source.scope,
    prompt: prompt,
    answer: source.answer,
    optionPool: source.optionPool,
    factKey: 'fact-${edition + 1}-${source.factKey}',
    sources: source.sources,
  );
}

String _factualPromptVariant(_Fact source, int edition) {
  final form = edition % 8;
  final prompt = source.prompt;

  final player = RegExp(
    r'^Which country did (.+?) (?:represent in international cricket|captain in international cricket)\?$',
  ).firstMatch(prompt);
  if (player != null) {
    final name = player.group(1)!;
    return [
      'Which national team did $name play for?',
      '$name represented which country in international cricket?',
      'In international cricket, $name played for which nation?',
      'Name $name\'s international side.',
      'Which country was $name\'s international team?',
      '$name played international cricket for which country?',
      'Identify the country represented by $name.',
      'Which nation did $name represent at international level?',
    ][form];
  }

  final term = RegExp(r'^In cricket, what does “(.+?)” mean\?$').firstMatch(prompt);
  if (term != null) {
    final name = term.group(1)!;
    return [
      'What is the cricket meaning of “$name”?',
      'Which definition fits the cricket term “$name”?',
      'In cricket, “$name” describes what?',
      'How is “$name” defined in cricket?',
      'What does a cricket scorer mean by “$name”?',
      'Which cricket definition matches “$name”?',
      'What does the term “$name” refer to in cricket?',
      'Choose the correct cricket meaning of “$name”.',
    ][form];
  }

  if (source.factKey.endsWith('-winner')) {
    final event = prompt
        .replaceFirst('Who won the ', '')
        .replaceFirst('Which team won the ', '')
        .replaceFirst('?', '');
    return [
      'Which team were champions of the $event?',
      'Name the champions of the $event.',
      'The $event title went to which team?',
      'Which side lifted the $event trophy?',
      'Who were crowned champions at the $event?',
      'Which team took the title at the $event?',
      'Identify the winning team from the $event.',
      'Which side claimed the $event?',
    ][form];
  }

  if (source.factKey.endsWith('-runner-up')) {
    final event = prompt
        .replaceFirst('Who finished runner-up at the ', '')
        .replaceFirst('Who were runners-up at the ', '')
        .replaceFirst('Which team finished runner-up in the ', '')
        .replaceFirst('?', '');
    return [
      'Which team lost the final of the $event?',
      'Name the $event runners-up.',
      'Which side finished second at the $event?',
      'The $event final was lost by which team?',
      'Who were the beaten finalists at the $event?',
      'Which team placed second in the $event?',
      'Identify the $event runner-up.',
      'Which side ended the $event as runners-up?',
    ][form];
  }

  if (source.factKey.endsWith('-orange-cap') ||
      source.factKey.endsWith('-purple-cap')) {
    final award = source.factKey.endsWith('-orange-cap')
        ? 'Orange Cap'
        : 'Purple Cap';
    final event = prompt
        .replaceFirst('Who won the $award in the ', '')
        .replaceFirst('?', '');
    return [
      'Who received the $award for the $event?',
      'Name the $award winner from the $event.',
      'Which player earned the $award in the $event?',
      'The $award at the $event went to whom?',
      'Who claimed the $award during the $event?',
      'Identify the $event $award holder.',
      'Which player took the $award in the $event?',
      'Name the player awarded the $award for the $event.',
    ][form];
  }

  if (source.factKey.endsWith('-host')) {
    final event = prompt
        .replaceFirst('Where was the ', '')
        .replaceFirst('Which country or region hosted the ', '')
        .replaceFirst(' staged?', '')
        .replaceFirst('?', '');
    return [
      'Which host staged the $event?',
      'Where was the $event held?',
      'Name the host of the $event.',
      'Which country or region staged the $event?',
      'The $event took place where?',
      'Which host nation or region held the $event?',
      'Identify the host for the $event.',
      'Where did the $event take place?',
    ][form];
  }

  if (source.factKey.startsWith('ground-city-')) {
    final ground = prompt
        .replaceFirst('In which city is ', '')
        .replaceFirst(' located?', '');
    return [
      'Which city hosts $ground?',
      'Locate $ground: which city is it in?',
      '$ground is in which city?',
      'Name the city of $ground.',
      'In which city would you find $ground?',
      'Which city is home to $ground?',
      'Identify the city where $ground is located.',
      'Where is $ground located?',
    ][form];
  }

  if (source.factKey.startsWith('ground-country-')) {
    final ground = prompt
        .replaceFirst('In which country is ', '')
        .replaceFirst(' located?', '');
    return [
      'Which country hosts $ground?',
      'Locate $ground: which country is it in?',
      '$ground is in which country?',
      'Name the country of $ground.',
      'In which country would you find $ground?',
      'Which country is home to $ground?',
      'Identify the country where $ground is located.',
      'Where is $ground located?',
    ][form];
  }

  if (source.factKey.startsWith('ipl-2026-squad-')) {
    final name = prompt
        .replaceFirst('Which IPL team listed ', '')
        .replaceFirst(' in its 2026 squad?', '');
    return [
      'Which IPL side included $name in its 2026 squad?',
      '$name was listed by which IPL team in 2026?',
      'Name $name\'s IPL squad for 2026.',
      'Which franchise listed $name for IPL 2026?',
      'In IPL 2026, $name was with which team?',
      'Which IPL 2026 roster included $name?',
      'Identify $name\'s IPL team for 2026.',
      'Which franchise had $name in its 2026 IPL squad?',
    ][form];
  }

  return 'Cricket records: $prompt';
}

void _addFact(_Fact fact) {
  _facts.putIfAbsent(_poolKey(fact.mode, fact.scope), () => []).add(fact);
}

void _addTermFacts() {
  final definitions = _rows('''
century|100 runs by one batter
half-century|50 runs by one batter
duck|a batter dismissed for zero
golden duck|a batter dismissed first ball
hat-trick|three wickets in consecutive balls
maiden over|an over with no runs charged
yorker|a ball pitching beside the toes
bouncer|a short ball rising at the batter
googly|a leg-spinner's wrong'un
doosra|an off-spinner's ball turning away
inswinger|a ball moving into the batter
outswinger|a ball moving away from the batter
reverse swing|late swing with an older ball
cover drive|a front-foot shot through cover
square cut|a back-foot shot square off side
pull shot|a shot to leg from a short ball
sweep shot|a cross-batted shot against spin
nightwatchman|a lower-order batter sent in late
all-rounder|a player who both bats and bowls
declaration|a captain closes the innings early
follow-on|the trailing Test side bats again
run out|wicket broken while batter is out
stumped|keeper breaks wicket out of ground
leg before wicket|body illegally blocks the wicket
hit wicket|striker breaks their own wicket
obstructing the field|wilfully blocking the fielders
retired hurt|leaving through injury or illness
free hit|next ball bars most dismissals
powerplay|overs with tighter fielding limits
Super Over|a tie-breaking extra over
DRS|Decision Review System
DLS|Duckworth-Lewis-Stern method
crease|a line marking a batter's ground
physical wicket|three stumps topped by two bails
pitch|the strip between the wickets
boundary four|four runs as the ball reaches rope
boundary six|six runs when the ball clears it
wide|a ball beyond normal batting reach
no-ball|an illegal ball costing an extra
bye|an extra untouched by bat or body
leg bye|an extra after body contact
five-for|five wickets in one innings
pair|a batter dismissed for zero twice
king pair|first-ball ducks in both innings
strike rate|runs per 100 balls faced
economy rate|runs conceded per over
batting average|runs divided by dismissals
bowling average|runs conceded per wicket
bowling strike rate|balls bowled per wicket
required run rate|runs needed per over remaining
''');
  final terms = definitions.map((row) => row[0]).toList();
  final meanings = definitions.map((row) => row[1]).toList();
  for (var i = 0; i < definitions.length; i++) {
    final mode = i < 18
        ? 'easy'
        : i < 34
        ? 'medium'
        : 'hard';
    _addFact(
      _Fact(
        mode: mode,
        scope: _scopeMen,
        prompt: 'In cricket, what does “${terms[i]}” mean?',
        answer: meanings[i],
        optionPool: meanings,
        factKey: 'term-${_slug(terms[i])}',
        sources: const ['mcc-laws-2022', 'icc-playing-conditions-2026'],
      ),
    );
  }
}

void _addPlayerFacts() {
  final men = _rows('''
Sachin Tendulkar|India
Virat Kohli|India
Rohit Sharma|India
MS Dhoni|India
Kapil Dev|India
Sunil Gavaskar|India
Rahul Dravid|India
Anil Kumble|India
Jasprit Bumrah|India
Ravichandran Ashwin|India
Ravindra Jadeja|India
Virender Sehwag|India
Sourav Ganguly|India
Yuvraj Singh|India
Zaheer Khan|India
Mohammed Shami|India
Shubman Gill|India
Suryakumar Yadav|India
Hardik Pandya|India
Rishabh Pant|India
Don Bradman|Australia
Ricky Ponting|Australia
Shane Warne|Australia
Glenn McGrath|Australia
Adam Gilchrist|Australia
Allan Border|Australia
Steve Waugh|Australia
Steve Smith|Australia
Pat Cummins|Australia
Mitchell Starc|Australia
Travis Head|Australia
Glenn Maxwell|Australia
Ian Botham|England
Alastair Cook|England
Joe Root|England
Ben Stokes|England
James Anderson|England
Stuart Broad|England
Eoin Morgan|England
Jos Buttler|England
Kevin Pietersen|England
Imran Khan|Pakistan
Wasim Akram|Pakistan
Waqar Younis|Pakistan
Javed Miandad|Pakistan
Inzamam-ul-Haq|Pakistan
Babar Azam|Pakistan
Shaheen Shah Afridi|Pakistan
Shahid Afridi|Pakistan
Garfield Sobers|West Indies
Viv Richards|West Indies
Brian Lara|West Indies
Clive Lloyd|West Indies
Michael Holding|West Indies
Courtney Walsh|West Indies
Chris Gayle|West Indies
Shivnarine Chanderpaul|West Indies
Curtly Ambrose|West Indies
Jacques Kallis|South Africa
AB de Villiers|South Africa
Dale Steyn|South Africa
Hashim Amla|South Africa
Graeme Smith|South Africa
Kagiso Rabada|South Africa
Shaun Pollock|South Africa
Herschelle Gibbs|South Africa
Richard Hadlee|New Zealand
Martin Crowe|New Zealand
Kane Williamson|New Zealand
Brendon McCullum|New Zealand
Daniel Vettori|New Zealand
Trent Boult|New Zealand
Tim Southee|New Zealand
Muttiah Muralitharan|Sri Lanka
Kumar Sangakkara|Sri Lanka
Mahela Jayawardene|Sri Lanka
Sanath Jayasuriya|Sri Lanka
Lasith Malinga|Sri Lanka
Aravinda de Silva|Sri Lanka
Chaminda Vaas|Sri Lanka
Shakib Al Hasan|Bangladesh
Tamim Iqbal|Bangladesh
Mushfiqur Rahim|Bangladesh
Mashrafe Mortaza|Bangladesh
Rashid Khan|Afghanistan
Mohammad Nabi|Afghanistan
Mujeeb Ur Rahman|Afghanistan
Rahmanullah Gurbaz|Afghanistan
Andy Flower|Zimbabwe
Heath Streak|Zimbabwe
Sikandar Raza|Zimbabwe
Kevin O'Brien|Ireland
Paul Stirling|Ireland
Ryan ten Doeschate|Netherlands
Bas de Leede|Netherlands
Paras Khadka|Nepal
Dipendra Singh Airee|Nepal
Kyle Coetzer|Scotland
Richie Berrington|Scotland
''');
  final countries = men.map((row) => row[1]).toSet().toList();
  for (var i = 0; i < men.length; i++) {
    final mode = i < 35
        ? 'easy'
        : i < 65
        ? 'medium'
        : i < 88
        ? 'hard'
        : 'global';
    final prompt = men[i][0] == 'Eoin Morgan'
        ? 'Which country did Eoin Morgan captain in international cricket?'
        : 'Which country did ${men[i][0]} represent in international cricket?';
    _addFact(
      _Fact(
        mode: mode,
        scope: _scopeMen,
        prompt: prompt,
        answer: men[i][1],
        optionPool: countries,
        factKey: 'player-country-${_slug(men[i][0])}',
        sources: const ['icc-rankings', 'espncricinfo-players'],
      ),
    );
  }

  final women = _rows('''
Belinda Clark|Australia
Meg Lanning|Australia
Ellyse Perry|Australia
Alyssa Healy|Australia
Beth Mooney|Australia
Ashleigh Gardner|Australia
Karen Rolton|Australia
Charlotte Edwards|England
Heather Knight|England
Nat Sciver-Brunt|England
Sarah Taylor|England
Sophie Ecclestone|England
Tammy Beaumont|England
Mithali Raj|India
Jhulan Goswami|India
Harmanpreet Kaur|India
Smriti Mandhana|India
Deepti Sharma|India
Shafali Verma|India
Debbie Hockley|New Zealand
Suzie Bates|New Zealand
Sophie Devine|New Zealand
Amelia Kerr|New Zealand
Stafanie Taylor|West Indies
Deandra Dottin|West Indies
Hayley Matthews|West Indies
Mignon du Preez|South Africa
Dane van Niekerk|South Africa
Marizanne Kapp|South Africa
Laura Wolvaardt|South Africa
Shabnim Ismail|South Africa
Sana Mir|Pakistan
Bismah Maroof|Pakistan
Nida Dar|Pakistan
Chamari Athapaththu|Sri Lanka
Shashikala Siriwardene|Sri Lanka
Salma Khatun|Bangladesh
Nigar Sultana|Bangladesh
Isobel Joyce|Ireland
Gaby Lewis|Ireland
Sornnarin Tippoch|Thailand
Nattaya Boochatham|Thailand
Kathryn Bryce|Scotland
Esha Oza|United Arab Emirates
Rubina Chhetry|Nepal
''');
  final womenCountries = women.map((row) => row[1]).toSet().toList();
  for (var i = 0; i < women.length; i++) {
    final mode = i < 16
        ? 'medium'
        : i < 31
        ? 'hard'
        : 'global';
    _addFact(
      _Fact(
        mode: mode,
        scope: _scopeWomen,
        prompt:
            'Which country did ${women[i][0]} represent in international cricket?',
        answer: women[i][1],
        optionPool: womenCountries,
        factKey: 'player-country-${_slug(women[i][0])}',
        sources: const ['icc-rankings', 'espncricinfo-players'],
      ),
    );
  }
}

void _addTournamentFacts() {
  const men = <_Tournament>[
    _Tournament(
      "Men's ODI World Cup",
      '1975',
      'West Indies',
      'Australia',
      'England',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '1979',
      'West Indies',
      'England',
      'England',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '1983',
      'India',
      'West Indies',
      'England',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '1987',
      'Australia',
      'England',
      'India and Pakistan',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '1992',
      'Pakistan',
      'England',
      'Australia and New Zealand',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '1996',
      'Sri Lanka',
      'Australia',
      'India, Pakistan and Sri Lanka',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '1999',
      'Australia',
      'Pakistan',
      'England',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '2003',
      'Australia',
      'India',
      'South Africa, Zimbabwe and Kenya',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '2007',
      'Australia',
      'Sri Lanka',
      'West Indies',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '2011',
      'India',
      'Sri Lanka',
      'India, Sri Lanka and Bangladesh',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '2015',
      'Australia',
      'New Zealand',
      'Australia and New Zealand',
    ),
    _Tournament(
      "Men's ODI World Cup",
      '2019',
      'England',
      'New Zealand',
      'England and Wales',
    ),
    _Tournament("Men's ODI World Cup", '2023', 'Australia', 'India', 'India'),
    _Tournament(
      "Men's T20 World Cup",
      '2007',
      'India',
      'Pakistan',
      'South Africa',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2009',
      'Pakistan',
      'Sri Lanka',
      'England',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2010',
      'England',
      'Australia',
      'West Indies',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2012',
      'West Indies',
      'Sri Lanka',
      'Sri Lanka',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2014',
      'Sri Lanka',
      'India',
      'Bangladesh',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2016',
      'West Indies',
      'England',
      'India',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2021',
      'Australia',
      'New Zealand',
      'UAE and Oman',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2022',
      'England',
      'Pakistan',
      'Australia',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2024',
      'India',
      'South Africa',
      'United States and West Indies',
    ),
    _Tournament(
      "Men's T20 World Cup",
      '2026',
      'India',
      'New Zealand',
      'India and Sri Lanka',
    ),
    _Tournament(
      'Champions Trophy',
      '1998',
      'South Africa',
      'West Indies',
      'Bangladesh',
    ),
    _Tournament('Champions Trophy', '2000', 'New Zealand', 'India', 'Kenya'),
    _Tournament(
      'Champions Trophy',
      '2004',
      'West Indies',
      'England',
      'England',
    ),
    _Tournament(
      'Champions Trophy',
      '2006',
      'Australia',
      'West Indies',
      'India',
    ),
    _Tournament(
      'Champions Trophy',
      '2009',
      'Australia',
      'New Zealand',
      'South Africa',
    ),
    _Tournament(
      'Champions Trophy',
      '2013',
      'India',
      'England',
      'England and Wales',
    ),
    _Tournament(
      'Champions Trophy',
      '2017',
      'Pakistan',
      'India',
      'England and Wales',
    ),
    _Tournament(
      'Champions Trophy',
      '2025',
      'India',
      'New Zealand',
      'Pakistan and UAE',
    ),
    _Tournament(
      'World Test Championship final',
      '2021',
      'New Zealand',
      'India',
      'England',
    ),
    _Tournament(
      'World Test Championship final',
      '2023',
      'Australia',
      'India',
      'England',
    ),
    _Tournament(
      'World Test Championship final',
      '2025',
      'South Africa',
      'Australia',
      'England',
    ),
  ];
  final menTeams = men
      .expand((row) => [row.winner, row.runnerUp])
      .toSet()
      .toList();
  final menHosts = men.map((row) => row.host).toSet().toList();
  for (final row in men.reversed) {
    final slug = '${_slug(row.competition)}-${row.year}';
    _addFact(
      _Fact(
        mode: 'medium',
        scope: _scopeMen,
        prompt: 'Who won the ${row.year} ${row.competition}?',
        answer: row.winner,
        optionPool: menTeams,
        factKey: '$slug-winner',
        sources: const ['icc-cwc-history', 'icc-tournament-guides'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'hard',
        scope: _scopeMen,
        prompt: 'Who finished runner-up at the ${row.year} ${row.competition}?',
        answer: row.runnerUp,
        optionPool: menTeams,
        factKey: '$slug-runner-up',
        sources: const ['icc-cwc-history', 'icc-tournament-guides'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'global',
        scope: _scopeMen,
        prompt: 'Where was the ${row.year} ${row.competition} staged?',
        answer: row.host,
        optionPool: menHosts,
        factKey: '$slug-host',
        sources: const ['icc-cwc-history', 'icc-tournament-guides'],
      ),
    );
  }

  const women = <_Tournament>[
    _Tournament(
      "Women's ODI World Cup",
      '1973',
      'England',
      'Australia',
      'England',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '1978',
      'Australia',
      'England',
      'India',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '1982',
      'Australia',
      'England',
      'New Zealand',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '1988',
      'Australia',
      'England',
      'Australia',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '1993',
      'England',
      'New Zealand',
      'England',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '1997',
      'Australia',
      'New Zealand',
      'India',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '2000',
      'New Zealand',
      'Australia',
      'New Zealand',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '2005',
      'Australia',
      'India',
      'South Africa',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '2009',
      'England',
      'New Zealand',
      'Australia',
    ),
    _Tournament(
      "Women's ODI World Cup",
      '2013',
      'Australia',
      'West Indies',
      'India',
    ),
    _Tournament("Women's ODI World Cup", '2017', 'England', 'India', 'England'),
    _Tournament(
      "Women's ODI World Cup",
      '2022',
      'Australia',
      'England',
      'New Zealand',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2009',
      'England',
      'New Zealand',
      'England',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2010',
      'Australia',
      'New Zealand',
      'West Indies',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2012',
      'Australia',
      'England',
      'Sri Lanka',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2014',
      'Australia',
      'England',
      'Bangladesh',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2016',
      'West Indies',
      'Australia',
      'India',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2018',
      'Australia',
      'England',
      'West Indies',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2020',
      'Australia',
      'India',
      'Australia',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2023',
      'Australia',
      'South Africa',
      'South Africa',
    ),
    _Tournament(
      "Women's T20 World Cup",
      '2024',
      'New Zealand',
      'South Africa',
      'United Arab Emirates',
    ),
  ];
  final womenTeams = women
      .expand((row) => [row.winner, row.runnerUp])
      .toSet()
      .toList();
  final womenHosts = women.map((row) => row.host).toSet().toList();
  for (final row in women.reversed) {
    final slug = '${_slug(row.competition)}-${row.year}';
    _addFact(
      _Fact(
        mode: 'medium',
        scope: _scopeWomen,
        prompt: 'Who won the ${row.year} ${row.competition}?',
        answer: row.winner,
        optionPool: womenTeams,
        factKey: '$slug-winner',
        sources: const ['icc-womens-records', 'espncricinfo-records'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'hard',
        scope: _scopeWomen,
        prompt: 'Who were runners-up at the ${row.year} ${row.competition}?',
        answer: row.runnerUp,
        optionPool: womenTeams,
        factKey: '$slug-runner-up',
        sources: const ['icc-womens-records', 'espncricinfo-records'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'global',
        scope: _scopeWomen,
        prompt:
            'Which country or region hosted the ${row.year} ${row.competition}?',
        answer: row.host,
        optionPool: womenHosts,
        factKey: '$slug-host',
        sources: const ['icc-womens-records', 'espncricinfo-records'],
      ),
    );
  }
}

void _addGroundFacts() {
  final grounds = _rows('''
Lord's|London|England
The Oval|London|England
Edgbaston|Birmingham|England
Old Trafford|Manchester|England
Headingley|Leeds|England
Trent Bridge|Nottingham|England
Melbourne Cricket Ground|Melbourne|Australia
Sydney Cricket Ground|Sydney|Australia
Adelaide Oval|Adelaide|Australia
The Gabba|Brisbane|Australia
Perth Stadium|Perth|Australia
Wankhede Stadium|Mumbai|India
Eden Gardens|Kolkata|India
M. Chinnaswamy Stadium|Bengaluru|India
M. A. Chidambaram Stadium|Chennai|India
Arun Jaitley Stadium|Delhi|India
Narendra Modi Stadium|Ahmedabad|India
Green Park|Kanpur|India
HPCA Stadium|Dharamsala|India
National Bank Stadium|Karachi|Pakistan
Gaddafi Stadium|Lahore|Pakistan
Rawalpindi Cricket Stadium|Rawalpindi|Pakistan
Newlands|Cape Town|South Africa
The Wanderers|Johannesburg|South Africa
SuperSport Park|Centurion|South Africa
Kingsmead|Durban|South Africa
Basin Reserve|Wellington|New Zealand
Eden Park|Auckland|New Zealand
Hagley Oval|Christchurch|New Zealand
Sabina Park|Kingston|Jamaica
Kensington Oval|Bridgetown|Barbados
Queen's Park Oval|Port of Spain|Trinidad and Tobago
Sinhalese Sports Club Ground|Colombo|Sri Lanka
R. Premadasa Stadium|Colombo|Sri Lanka
Pallekele International Stadium|Kandy|Sri Lanka
Sher-e-Bangla National Stadium|Dhaka|Bangladesh
Harare Sports Club|Harare|Zimbabwe
Malahide Cricket Club Ground|Malahide|Ireland
Dubai International Stadium|Dubai|United Arab Emirates
Sharjah Cricket Stadium|Sharjah|United Arab Emirates
''');
  final cities = grounds.map((row) => row[1]).toSet().toList();
  final countries = grounds.map((row) => row[2]).toSet().toList();
  for (final ground in grounds) {
    _addFact(
      _Fact(
        mode: 'medium',
        scope: _scopeMen,
        prompt: 'In which city is ${ground[0]} located?',
        answer: ground[1],
        optionPool: cities,
        factKey: 'ground-city-${_slug(ground[0])}',
        sources: const ['icc-tournament-guides', 'espncricinfo-grounds'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'global',
        scope: _scopeMen,
        prompt: 'In which country is ${ground[0]} located?',
        answer: ground[2],
        optionPool: countries,
        factKey: 'ground-country-${_slug(ground[0])}',
        sources: const ['icc-tournament-guides', 'espncricinfo-grounds'],
      ),
    );
  }
}

void _addIplFacts() {
  const seasons = <_IplSeason>[
    _IplSeason(
      2008,
      'Rajasthan Royals',
      'Chennai Super Kings',
      'Shaun Marsh',
      'Sohail Tanvir',
    ),
    _IplSeason(
      2009,
      'Deccan Chargers',
      'Royal Challengers Bengaluru',
      'Matthew Hayden',
      'R. P. Singh',
    ),
    _IplSeason(
      2010,
      'Chennai Super Kings',
      'Mumbai Indians',
      'Sachin Tendulkar',
      'Pragyan Ojha',
    ),
    _IplSeason(
      2011,
      'Chennai Super Kings',
      'Royal Challengers Bengaluru',
      'Chris Gayle',
      'Lasith Malinga',
    ),
    _IplSeason(
      2012,
      'Kolkata Knight Riders',
      'Chennai Super Kings',
      'Chris Gayle',
      'Morne Morkel',
    ),
    _IplSeason(
      2013,
      'Mumbai Indians',
      'Chennai Super Kings',
      'Michael Hussey',
      'Dwayne Bravo',
    ),
    _IplSeason(
      2014,
      'Kolkata Knight Riders',
      'Punjab Kings',
      'Robin Uthappa',
      'Mohit Sharma',
    ),
    _IplSeason(
      2015,
      'Mumbai Indians',
      'Chennai Super Kings',
      'David Warner',
      'Dwayne Bravo',
    ),
    _IplSeason(
      2016,
      'Sunrisers Hyderabad',
      'Royal Challengers Bengaluru',
      'Virat Kohli',
      'Bhuvneshwar Kumar',
    ),
    _IplSeason(
      2017,
      'Mumbai Indians',
      'Rising Pune Supergiant',
      'David Warner',
      'Bhuvneshwar Kumar',
    ),
    _IplSeason(
      2018,
      'Chennai Super Kings',
      'Sunrisers Hyderabad',
      'Kane Williamson',
      'Andrew Tye',
    ),
    _IplSeason(
      2019,
      'Mumbai Indians',
      'Chennai Super Kings',
      'David Warner',
      'Imran Tahir',
    ),
    _IplSeason(
      2020,
      'Mumbai Indians',
      'Delhi Capitals',
      'KL Rahul',
      'Kagiso Rabada',
    ),
    _IplSeason(
      2021,
      'Chennai Super Kings',
      'Kolkata Knight Riders',
      'Ruturaj Gaikwad',
      'Harshal Patel',
    ),
    _IplSeason(
      2022,
      'Gujarat Titans',
      'Rajasthan Royals',
      'Jos Buttler',
      'Yuzvendra Chahal',
    ),
    _IplSeason(
      2023,
      'Chennai Super Kings',
      'Gujarat Titans',
      'Shubman Gill',
      'Mohammed Shami',
    ),
    _IplSeason(
      2024,
      'Kolkata Knight Riders',
      'Sunrisers Hyderabad',
      'Virat Kohli',
      'Harshal Patel',
    ),
    _IplSeason(
      2025,
      'Royal Challengers Bengaluru',
      'Punjab Kings',
      'Sai Sudharsan',
      'Prasidh Krishna',
    ),
    _IplSeason(
      2026,
      'Royal Challengers Bengaluru',
      'Gujarat Titans',
      'Vaibhav Sooryavanshi',
      'Bhuvneshwar Kumar',
    ),
  ];
  final teams = seasons
      .expand((row) => [row.winner, row.runnerUp])
      .toSet()
      .toList();
  final orange = seasons.map((row) => row.orangeCap).toSet().toList();
  final purple = seasons.map((row) => row.purpleCap).toSet().toList();
  for (final season in seasons.reversed) {
    final winnerMode = season.year >= 2018 ? 'easy' : 'medium';
    _addFact(
      _Fact(
        mode: winnerMode,
        scope: _scopeIpl,
        prompt: 'Which team won the ${season.year} IPL?',
        answer: season.winner,
        optionPool: teams,
        factKey: 'ipl-${season.year}-winner',
        sources: const ['ipl-stats', 'ipl-news'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'hard',
        scope: _scopeIpl,
        prompt: 'Which team finished runner-up in the ${season.year} IPL?',
        answer: season.runnerUp,
        optionPool: teams,
        factKey: 'ipl-${season.year}-runner-up',
        sources: const ['ipl-stats', 'ipl-news'],
      ),
    );
    _addFact(
      _Fact(
        mode: season.year >= 2018 ? 'medium' : 'global',
        scope: _scopeIpl,
        prompt: 'Who won the Orange Cap in the ${season.year} IPL?',
        answer: season.orangeCap,
        optionPool: orange,
        factKey: 'ipl-${season.year}-orange-cap',
        sources: const ['ipl-stats', 'espncricinfo-records'],
      ),
    );
    _addFact(
      _Fact(
        mode: 'hard',
        scope: _scopeIpl,
        prompt: 'Who won the Purple Cap in the ${season.year} IPL?',
        answer: season.purpleCap,
        optionPool: purple,
        factKey: 'ipl-${season.year}-purple-cap',
        sources: const ['ipl-stats', 'espncricinfo-records'],
      ),
    );
  }

  // The in-app player catalog is the project's canonical 2026 IPL roster. Read
  // it rather than duplicating another 100-name roster in this generator.
  final source = File('lib/models/cards.dart').readAsStringSync();
  final start = source.indexOf('const cricketBattingCards');
  final end = source.indexOf('const cricketPlayerCards');
  if (start < 0 || end <= start) {
    throw StateError('Cricket card catalog not found');
  }
  final section = source.substring(start, end);
  final matches = RegExp(
    r"name: '([^']+)'[\s\S]*?country: '([^']+)'[\s\S]*?countryCode: '([^']+)'",
  ).allMatches(section).toList();
  final rosterTeams = matches.map((match) => match.group(2)!).toSet().toList();
  for (var i = 0; i < matches.length; i++) {
    final name = matches[i].group(1)!;
    final team = matches[i].group(2)!;
    final mode = i < 25
        ? 'easy'
        : i < 75
        ? 'medium'
        : i < 105
        ? 'hard'
        : 'global';
    _addFact(
      _Fact(
        mode: mode,
        scope: _scopeIpl,
        prompt: 'Which IPL team listed $name in its 2026 squad?',
        answer: team,
        optionPool: rosterTeams,
        factKey: 'ipl-2026-squad-${_slug(name)}',
        sources: const ['ipl-stats', 'ipl-news'],
      ),
    );
  }
}

List<String> _pickDistractors(String answer, List<String> pool, int seed) {
  final candidates = pool.where((item) => item != answer).toSet().toList()
    ..sort();
  if (candidates.length < 3) {
    throw StateError('Not enough distractors for $answer');
  }
  final picked = <String>[];
  var cursor = seed.abs() % candidates.length;
  while (picked.length < 3) {
    final value = candidates[cursor % candidates.length];
    if (!picked.contains(value)) {
      picked.add(value);
    }
    cursor++;
  }
  return picked;
}

List<List<String>> _rows(String raw) => raw
    .trim()
    .split('\n')
    .map((line) => line.trim().split('|'))
    .toList(growable: false);

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _stableHash(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

void _writeJson(String path, Object value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}

const _menTeams = [
  'India',
  'Australia',
  'England',
  'Pakistan',
  'South Africa',
  'New Zealand',
  'Sri Lanka',
  'West Indies',
  'Bangladesh',
  'Afghanistan',
  'Zimbabwe',
  'Ireland',
  'Netherlands',
  'Scotland',
  'Nepal',
  'United States',
];

const _womenTeams = [
  'Australia',
  'England',
  'India',
  'New Zealand',
  'South Africa',
  'West Indies',
  'Pakistan',
  'Sri Lanka',
  'Bangladesh',
  'Ireland',
  'Thailand',
  'Scotland',
];

const _iplScenarioTeams = [
  'CSK',
  'DC',
  'GT',
  'KKR',
  'LSG',
  'MI',
  'PBKS',
  'RR',
  'RCB',
  'SRH',
];
