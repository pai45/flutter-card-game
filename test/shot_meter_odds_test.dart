import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goalChanceForDiff', () {
    test('matches the engine resolution thresholds at each boundary', () {
      // These probabilities are the single source of truth shared by the Shot
      // Meter overlay and GameBloc._resolveRound. If the resolution table
      // changes, both must move together.
      expect(goalChanceForDiff(20), 0.75);
      expect(goalChanceForDiff(10), 0.60);
      expect(goalChanceForDiff(0), 0.45);
      expect(goalChanceForDiff(-10), 0.10);
      expect(goalChanceForDiff(-20), 0.05);
    });

    test('treats the threshold edges the same way the engine does', () {
      // The engine uses strict > comparisons; verify the boundary values land
      // in the lower bucket (e.g. exactly +15 is NOT the >15 bucket).
      expect(goalChanceForDiff(15), 0.60);
      expect(goalChanceForDiff(5), 0.45);
      expect(goalChanceForDiff(-5), 0.10);
      expect(goalChanceForDiff(-15), 0.05);
    });

    test('is monotonically non-decreasing in the power advantage', () {
      final samples = [
        for (var d = -30.0; d <= 30.0; d += 2.5) goalChanceForDiff(d),
      ];
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }
    });
  });
}
