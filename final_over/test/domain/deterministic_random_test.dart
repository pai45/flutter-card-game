import 'package:final_over/domain/deterministic_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeterministicRandom', () {
    test('seed zero matches the fixed SplitMix64 golden sequence', () {
      final random = DeterministicRandom(0);
      expect(List.generate(5, (_) => random.nextUint64()), const [
        -0x1ddf57c684e23251,
        0x6e789e6aa1b965f4,
        0x06c45d188009454f,
        -0x077447578db37e14,
        0x1b39896a51a8749b,
      ]);
    });

    test('same seed has the same sequence', () {
      final first = DeterministicRandom(42);
      final second = DeterministicRandom(42);

      final a = List.generate(32, (_) => first.nextUint64());
      final b = List.generate(32, (_) => second.nextUint64());

      expect(a, b);
      expect(a.toSet(), hasLength(32));
    });

    test('different named streams do not overlap', () {
      final values = {
        for (final stream in RandomStream.values)
          SeedStreams.seedFor(987654321, 4, stream),
      };
      expect(values, hasLength(RandomStream.values.length));
    });

    test('physical delivery ordinal changes every derived stream', () {
      for (final stream in RandomStream.values) {
        expect(
          SeedStreams.seedFor(77, 1, stream),
          isNot(SeedStreams.seedFor(77, 2, stream)),
        );
      }
    });

    test('bounded methods respect their ranges', () {
      final random = DeterministicRandom(11);
      for (var i = 0; i < 1000; i++) {
        expect(random.nextInt(7), inInclusiveRange(0, 6));
        expect(random.range(-0.2, 0.3), inInclusiveRange(-0.2, 0.3));
      }
    });

    test('derived delivery stream remains statistically uniform', () {
      var firstBelowTwo = 0;
      var secondBelowFive = 0;
      for (var seed = 0; seed < 10000; seed++) {
        final random = SeedStreams.forStream(seed, 2, RandomStream.delivery);
        if (random.nextDouble() < 0.02) firstBelowTwo++;
        if (random.nextDouble() < 0.05) secondBelowFive++;
      }
      expect(firstBelowTwo / 10000, inInclusiveRange(0.015, 0.025));
      expect(secondBelowFive / 10000, inInclusiveRange(0.04, 0.06));
    });
  });
}
