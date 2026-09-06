import 'package:card_game/models/football_match_data.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/football_match_package_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the per-player match layer against the real bundled asset.
///
/// These assert the numbers the feed actually returned when the layer was
/// generated (ESPN event 401879318, probed 2026-09-06), not merely that the
/// JSON parsed — a thinner asset is the failure mode worth catching, and it
/// parses perfectly well.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SportMatch match;
  late List<MatchPlayer> everyone;

  setUpAll(() async {
    match = await const FootballMatchPackageService().loadBundled();
    everyone = [
      ...match.homeLineup!.startingXI,
      ...match.homeLineup!.substitutes,
      ...match.awayLineup!.startingXI,
      ...match.awayLineup!.substitutes,
    ];
  });

  test('every player in the package carries a match stat sheet', () {
    expect(everyone, hasLength(40));
    for (final player in everyone) {
      expect(
        player.matchStats,
        isNotNull,
        reason: '${player.name} has no matchStats',
      );
      expect(player.matchStats!.values, isNotEmpty);
    }
  });

  test('tracked touches match the feed', () {
    final withTouches = everyone.where((p) => p.matchStats!.hasTracking);
    expect(withTouches, hasLength(31));

    final total = everyone.fold<int>(
      0,
      (sum, p) => sum + p.matchStats!.touchCount,
    );
    expect(total, 1521);
  });

  test('every starter is tracked, every unused substitute is not', () {
    final starters = [
      ...match.homeLineup!.startingXI,
      ...match.awayLineup!.startingXI,
    ];
    expect(starters, hasLength(22));
    for (final player in starters) {
      expect(
        player.matchStats!.touchCount,
        greaterThanOrEqualTo(35),
        reason: '${player.name} looks untracked',
      );
      expect(player.matchStats!.played, isTrue);
    }

    final unused = everyone.where((p) => !p.matchStats!.played).toList();
    expect(unused, hasLength(9));
    for (final player in unused) {
      expect(player.matchStats!.touchCount, 0);
      expect(player.matchStats!.minutesPlayed, isNull);
      expect(player.matchStats!.roleLabel, 'UNUSED');
    }
  });

  // The raw feed overflows its own frame (x up to 101.8, y down to -1.6) on
  // events that leave the pitch. Anything outside 0..1 would paint off the
  // heatmap, so this is the regression lock on the parser's clamp.
  test('every touch is normalised inside the pitch', () {
    for (final player in everyone) {
      for (final (x, y) in player.matchStats!.touches()) {
        expect(x, inInclusiveRange(0.0, 1.0));
        expect(y, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  test('halves partition the whole match', () {
    for (final player in everyone) {
      final stats = player.matchStats!;
      expect(
        stats.touches(period: 1).length + stats.touches(period: 2).length,
        stats.touchCount,
      );
    }
  });

  // If ESPN adds a 16th stat this fails, rather than the card silently
  // rendering a machine-cased key.
  test('every stat the asset ships has curated label copy', () {
    final catalogued = {for (final d in kFootballPlayerStatCatalog) d.key};
    final shipped = {
      for (final player in everyone) ...player.matchStats!.values.keys,
    };
    expect(shipped, hasLength(15));
    expect(shipped.difference(catalogued), isEmpty);
  });

  test('goals on the stat sheet agree with the scorers already in the asset', () {
    final scored = everyone.fold<int>(
      0,
      (sum, p) => sum + p.matchStats!.intStat('totalGoals'),
    );
    // The asset's own scorer list is hand-authored and independent of the
    // generated layer, so this crosses two sources.
    final ownGoals = everyone.fold<int>(
      0,
      (sum, p) => sum + p.matchStats!.intStat('ownGoals'),
    );
    expect(scored + ownGoals, match.footballDetails!.scorers.length);
  });

  test('derived metrics stay inside their own definitions', () {
    for (final player in everyone) {
      final stats = player.matchStats!;
      expect(stats.finalThirdTouches, lessThanOrEqualTo(stats.touchCount));
      expect(stats.boxTouches, lessThanOrEqualTo(stats.finalThirdTouches));
      final territory = stats.territory;
      if (stats.hasTracking) {
        expect(territory, inInclusiveRange(0.0, 1.0));
        expect(stats.averagePosition, isNotNull);
      } else {
        expect(territory, isNull);
        expect(stats.averagePosition, isNull);
      }
    }
  });

  test('substitution minutes are read off the plays feed', () {
    final subbedOff = everyone.where((p) => p.matchStats!.subOutMinute != null);
    final broughtOn = everyone.where((p) => p.matchStats!.subInMinute != null);
    // Nine substitution plays, each naming one player on and one off.
    expect(subbedOff, hasLength(9));
    expect(broughtOn, hasLength(9));
    for (final player in [...subbedOff, ...broughtOn]) {
      final stats = player.matchStats!;
      expect((stats.subInMinute ?? stats.subOutMinute)!, inInclusiveRange(1, 90));
      expect(stats.minutesPlayed, greaterThan(0));
    }
  });
}
