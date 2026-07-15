/// Named random streams prevent unrelated decisions from perturbing each other.
enum RandomStream {
  delivery,
  contact,
  catchOutcome,
  drop,
  throwOutcome,
  objective,
}

/// SplitMix64 with explicitly masked unsigned 64-bit arithmetic.
///
/// Dart VM bitwise `int` operations are signed, so the internal state uses
/// [BigInt] to preserve all 64 bits on every supported Dart runtime. Public
/// integer results use the conventional signed two's-complement view of those
/// same bits. This keeps match seeds stable without relying on platform quirks.
final class DeterministicRandom {
  DeterministicRandom(int seed) : _state = BigInt.from(seed) & _mask64;

  static final BigInt _mask64 = BigInt.parse('ffffffffffffffff', radix: 16);
  static final BigInt _twoTo64 = BigInt.one << 64;
  static final BigInt _twoTo63 = BigInt.one << 63;
  static final BigInt _increment = BigInt.parse('9e3779b97f4a7c15', radix: 16);
  static final BigInt _mix1 = BigInt.parse('bf58476d1ce4e5b9', radix: 16);
  static final BigInt _mix2 = BigInt.parse('94d049bb133111eb', radix: 16);
  static const double _twoTo53 = 9007199254740992.0;

  BigInt _state;

  BigInt _nextBits() {
    _state = (_state + _increment) & _mask64;
    return _mixBits(_state);
  }

  /// Returns the signed two's-complement view of the next 64 random bits.
  int nextUint64() => _toSignedInt(_nextBits());

  double nextDouble() {
    final top53 = _nextBits() >> 11;
    return top53.toInt() / _twoTo53;
  }

  bool nextBool([double probability = 0.5]) {
    if (probability <= 0) return false;
    if (probability >= 1) return true;
    return nextDouble() < probability;
  }

  int nextInt(int maximum) {
    if (maximum <= 0) {
      throw ArgumentError.value(maximum, 'maximum', 'Must be positive');
    }
    final bound = BigInt.from(maximum);
    final threshold = _twoTo64 % bound;
    while (true) {
      final value = _nextBits();
      if (value >= threshold) return (value % bound).toInt();
    }
  }

  double range(double minimum, double maximum) {
    if (maximum < minimum) {
      throw ArgumentError('maximum must not be smaller than minimum');
    }
    return minimum + (maximum - minimum) * nextDouble();
  }

  T choose<T>(List<T> values) {
    if (values.isEmpty) throw ArgumentError('Cannot choose from an empty list');
    return values[nextInt(values.length)];
  }

  static int mix64(int value) =>
      _toSignedInt(_mixBits(BigInt.from(value) & _mask64));

  static BigInt _mixBits(BigInt value) {
    var z = value & _mask64;
    z = ((z ^ (z >> 30)) * _mix1) & _mask64;
    z = ((z ^ (z >> 27)) * _mix2) & _mask64;
    return (z ^ (z >> 31)) & _mask64;
  }

  static int _toSignedInt(BigInt bits) =>
      (bits >= _twoTo63 ? bits - _twoTo64 : bits).toInt();
}

final class SeedStreams {
  const SeedStreams._();

  static final _streamSalts = <BigInt>[
    BigInt.parse('243f6a8885a308d3', radix: 16),
    BigInt.parse('13198a2e03707344', radix: 16),
    BigInt.parse('a4093822299f31d0', radix: 16),
    BigInt.parse('082efa98ec4e6c89', radix: 16),
    BigInt.parse('452821e638d01377', radix: 16),
    BigInt.parse('be5466cf34e90c6c', radix: 16),
  ];
  static final BigInt _ordinalSalt = -BigInt.parse(
    '61c8864680b583eb',
    radix: 16,
  );

  /// Derives a unique stream seed from the match and physical delivery.
  static int seedFor(int matchSeed, int deliveryOrdinal, RandomStream stream) {
    final match = DeterministicRandom._mixBits(
      BigInt.from(matchSeed) & DeterministicRandom._mask64,
    );
    final ordinal = DeterministicRandom._mixBits(
      BigInt.from(deliveryOrdinal) * _ordinalSalt,
    );
    return DeterministicRandom._toSignedInt(
      DeterministicRandom._mixBits(match ^ ordinal ^ _streamSalts[stream.index]),
    );
  }

  static DeterministicRandom forStream(
    int matchSeed,
    int deliveryOrdinal,
    RandomStream stream,
  ) => DeterministicRandom(seedFor(matchSeed, deliveryOrdinal, stream));
}
