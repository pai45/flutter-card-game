import 'dart:io';

import 'package:final_over/domain/domain.dart';

import 'simulate_matches.dart' as simulation;

enum _Tier { rookie, pro, elite }

extension on _Tier {
  GameplayTuning get tuning => switch (this) {
    _Tier.rookie => GameplayTuning.rookie,
    _Tier.pro => GameplayTuning.pro,
    _Tier.elite => GameplayTuning.elite,
  };

  List<int> get targets => switch (this) {
    _Tier.rookie => const [8, 10],
    _Tier.pro => const [10, 12, 14],
    _Tier.elite => const [16, 18, 20],
  };

  (double, double, double, double) get gates => switch (this) {
    _Tier.rookie => (0.75, 0.85, 0.65, 0.75),
    _Tier.pro => (0.55, 0.65, 0.55, 0.65),
    _Tier.elite => (0.30, 0.45, 0.45, 0.55),
  };
}

Future<void> main(List<String> arguments) async {
  var matchesPerTarget = 1000;
  var seedStart = 1;
  var enforceGates = true;
  for (final argument in arguments) {
    if (argument.startsWith('--matches-per-target=')) {
      matchesPerTarget = int.parse(
        argument.substring('--matches-per-target='.length),
      );
    } else if (argument.startsWith('--seed-start=')) {
      seedStart = int.parse(argument.substring('--seed-start='.length));
    } else if (argument == '--no-gate') {
      enforceGates = false;
    } else if (argument == '--help' || argument == '-h') {
      stdout.writeln(
        'Usage: dart run tool/simulate_tiers.dart '
        '[--matches-per-target=1000] [--seed-start=1] [--no-gate]',
      );
      return;
    } else {
      stderr.writeln('Unknown argument: $argument');
      exitCode = 64;
      return;
    }
  }
  if (matchesPerTarget <= 0) {
    throw ArgumentError.value(matchesPerTarget, 'matchesPerTarget');
  }

  stdout.writeln('Final Over tier balance');
  stdout.writeln('Matches per target: $matchesPerTarget');
  var passed = true;
  for (final tier in _Tier.values) {
    var matches = 0;
    var wins = 0;
    var legalBalls = 0;
    var scoringLegalBalls = 0;
    stdout.writeln('\n${tier.name.toUpperCase()}');
    for (final target in tier.targets) {
      final report = await simulation.simulateMatches(
        matches: matchesPerTarget,
        target: target,
        seedStart: seedStart + tier.index * 100000 + target * 10000,
        tuning: tier.tuning,
      );
      matches += report.matches;
      wins += report.wins;
      legalBalls += report.legalBalls;
      scoringLegalBalls += report.scoringLegalBalls;
      stdout.writeln(
        '  target $target: win ${_percent(report.winRate)}, '
        'score ${report.averageScore.toStringAsFixed(2)}, '
        'scoring balls ${_percent(report.scoringLegalBallRate)}',
      );
    }

    final winRate = wins / matches;
    final scoringRate = scoringLegalBalls / legalBalls;
    final (minimumWin, maximumWin, minimumScoring, maximumScoring) = tier.gates;
    final tierPassed =
        winRate >= minimumWin &&
        winRate <= maximumWin &&
        scoringRate >= minimumScoring &&
        scoringRate <= maximumScoring;
    passed = passed && tierPassed;
    stdout.writeln(
      '  total: win ${_percent(winRate)}, '
      'scoring balls ${_percent(scoringRate)} '
      '${tierPassed ? 'PASS' : 'OUTSIDE TARGET'}',
    );
  }

  if (enforceGates && !passed) exitCode = 1;
}

String _percent(double value) => '${(value * 100).toStringAsFixed(2)}%';
