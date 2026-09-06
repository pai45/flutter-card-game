import 'package:card_game/config/sport_modules.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/data/followable_leagues.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sport storage falls back safely for existing installs', () {
    expect(sportFromStorage(null), Sport.football);
    expect(sportFromStorage(''), Sport.football);
    expect(sportFromStorage('unknown'), Sport.football);
    expect(sportFromStorage('cricket'), Sport.cricket);
    expect(sportFromStorage('f1'), Sport.motorsport);
    expect(sportFromStorage('basketball'), Sport.basketball);
  });

  test('every onboarding sport has module metadata and followable leagues', () {
    for (final sport in Sport.values) {
      final module = sportModuleFor(sport);
      expect(module.sport, sport);
      expect(module.label, isNotEmpty);
      expect(module.availableModules, isNotEmpty);
      expect(followableLeaguesForSport(sport), isNotEmpty);
    }
  });

  test('sports expose the canonical identity palette in tab order', () {
    expect(sportModuleFor(Sport.football).accent, Cyber.cyan);
    expect(sportModuleFor(Sport.cricket).accent, AppTheme.whiteColor);
    expect(sportModuleFor(Sport.basketball).accent, Cyber.gold);
    expect(sportModuleFor(Sport.tennis).accent, Cyber.lime);
    expect(sportModuleFor(Sport.motorsport).accent, Cyber.f1Red);
    expect(sportTabColors, const [
      Cyber.cyan,
      AppTheme.whiteColor,
      Cyber.gold,
      Cyber.lime,
      Cyber.f1Red,
    ]);
  });
}
