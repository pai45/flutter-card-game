import 'package:card_game/config/sport_modules.dart';
import 'package:card_game/data/followable_leagues.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sport storage falls back safely for existing installs', () {
    expect(sportFromStorage(null), Sport.football);
    expect(sportFromStorage(''), Sport.football);
    expect(sportFromStorage('unknown'), Sport.football);
    expect(sportFromStorage('cricket'), Sport.cricket);
    expect(sportFromStorage('f1'), Sport.f1);
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
}
