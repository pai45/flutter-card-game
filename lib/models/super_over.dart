import 'dart:math';

enum TimingTier { perfect, great, good, edgePoor, miss }

enum DeliveryType { pace, spin, yorker }

enum ShotOutcome { six, four, three, two, one, dot, caught, bowled }

enum ShotSector { off, v, leg }

enum SuperOverMode { scoreAttack, chase }

enum CricketJersey { mumbai, chennai, bangalore, kolkata, delhi, rajasthan, punjab, hyderabad, lucknow, gujarat }

enum SuperOverPhase {
  ready,
  targetReveal,
  ballSetup,
  runUp,
  ballInFlight,
  swinging,
  outcome,
  result,
  paused,
}

class SuperOverShotResult {
  const SuperOverShotResult({
    required this.timingErrorMs,
    required this.normalizedError,
    required this.tier,
    required this.sector,
    required this.power,
    required this.outcome,
  });

  final int timingErrorMs;
  final double normalizedError;
  final TimingTier tier;
  final ShotSector sector;
  final int power;
  final ShotOutcome outcome;
}

class SuperOverFielderSpot {
  const SuperOverFielderSpot({
    required this.sector,
    required this.angle,
    required this.radial,
    this.closeCatcher = false,
  });

  final ShotSector sector;

  /// Radians from the striker: straight is -pi / 2, off is left, leg is right.
  final double angle;

  /// Distance from striker, normalized to the top-down oval.
  final double radial;

  final bool closeCatcher;
}

class SuperOverResolution {
  static final Random _random = Random();

  static const int baseTimingWindowMs = 360;

  static const List<SuperOverFielderSpot> _offFieldTemplate = [
    SuperOverFielderSpot(
      sector: ShotSector.off,
      angle: -2.72,
      radial: 0.30,
      closeCatcher: true,
    ),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.34, radial: 0.48),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.05, radial: 0.66),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.56, radial: 0.82),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.20, radial: 0.96),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.86, radial: 0.94),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -1.98, radial: 0.42),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.44, radial: 0.62),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.10, radial: 0.84),
  ];

  static const List<SuperOverFielderSpot> _vFieldTemplate = [
    SuperOverFielderSpot(
      sector: ShotSector.v,
      angle: -pi / 2,
      radial: 0.26,
      closeCatcher: true,
    ),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.83, radial: 0.45),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.31, radial: 0.45),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.82, radial: 0.78),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.32, radial: 0.78),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -pi / 2, radial: 0.98),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.68, radial: 0.62),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.44, radial: 0.62),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -pi / 2, radial: 0.54),
  ];

  static const List<SuperOverFielderSpot> _legFieldTemplate = [
    SuperOverFielderSpot(
      sector: ShotSector.leg,
      angle: -0.42,
      radial: 0.34,
      closeCatcher: true,
    ),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.78, radial: 0.50),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -1.08, radial: 0.66),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.68, radial: 0.86),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.22, radial: 0.72),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -1.12, radial: 0.92),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.54, radial: 0.58),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.92, radial: 0.74),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.28, radial: 0.92),
  ];

  /// Calculates the target rating based on player level.
  static int targetRatingForLevel(int level) {
    return min(95, 66 + level * 2);
  }

  /// First-pass chase target bands tuned for the one-tap arcade scoring rate.
  static (int min, int max) targetBandForLevel(int level) {
    if (level <= 3) return (8, 12);
    if (level <= 7) return (11, 16);
    if (level <= 12) return (14, 19);
    if (level <= 18) return (16, 21);
    return (18, 23);
  }

  static int targetForLevel(int level, {Random? random}) {
    final rng = random ?? _random;
    final band = targetBandForLevel(level);
    return band.$1 + rng.nextInt(band.$2 - band.$1 + 1);
  }

  /// Calculates the window scale multiplier for a given card rating.
  static double windowScale(int rating) {
    return (1.0 + (rating - 75) * 0.012).clamp(0.85, 1.30);
  }

  /// Adjusts the base window size by the delivery type multiplier.
  static double deliveryMultiplier(DeliveryType type) {
    return switch (type) {
      DeliveryType.yorker => 0.78,
      DeliveryType.pace => 0.92,
      DeliveryType.spin => 1.10,
    };
  }

  static int effectiveTimingWindowMs(
    int rating,
    DeliveryType delivery, {
    bool onFire = false,
  }) {
    final scale =
        windowScale(rating) *
        deliveryMultiplier(delivery) *
        (onFire ? 1.08 : 1.0);
    return (baseTimingWindowMs * scale).round();
  }

  static double normalizedTimingError({
    required int timingErrorMs,
    required int effectiveWindowMs,
  }) {
    if (effectiveWindowMs <= 0) return timingErrorMs.sign.toDouble();
    return timingErrorMs / effectiveWindowMs;
  }

  static TimingTier timingTierForNormalizedError(double normalizedError) {
    final absError = normalizedError.abs();
    if (absError <= 0.14) return TimingTier.perfect;
    if (absError <= 0.32) return TimingTier.great;
    if (absError <= 0.58) return TimingTier.good;
    if (absError <= 0.90) return TimingTier.edgePoor;
    return TimingTier.miss;
  }

  static ShotSector sectorForTiming(
    double normalizedError, {
    bool leftHanded = false,
  }) {
    if (normalizedError < -0.18) {
      return leftHanded ? ShotSector.off : ShotSector.leg;
    }
    if (normalizedError > 0.18) {
      return leftHanded ? ShotSector.leg : ShotSector.off;
    }
    return ShotSector.v;
  }

  static int sectorIndex(ShotSector sector) {
    return switch (sector) {
      ShotSector.off => 0,
      ShotSector.v => 1,
      ShotSector.leg => 2,
    };
  }

  static ShotSector sectorFromIndex(int index) {
    return switch (index) {
      0 => ShotSector.off,
      2 => ShotSector.leg,
      _ => ShotSector.v,
    };
  }

  static double shotAngleForSector(ShotSector sector) {
    return switch (sector) {
      ShotSector.off => -2.32,
      ShotSector.v => -pi / 2,
      ShotSector.leg => -0.82,
    };
  }

  static List<SuperOverFielderSpot> fielderSpotsForSectors(
    List<int> fieldSectors,
  ) {
    final counts = [
      fieldSectors.elementAtOrNull(0) ?? 0,
      fieldSectors.elementAtOrNull(1) ?? 0,
      fieldSectors.elementAtOrNull(2) ?? 0,
    ];
    final spots = <SuperOverFielderSpot>[
      ..._offFieldTemplate.take(
        counts[0].clamp(0, _offFieldTemplate.length).toInt(),
      ),
      ..._vFieldTemplate.take(
        counts[1].clamp(0, _vFieldTemplate.length).toInt(),
      ),
      ..._legFieldTemplate.take(
        counts[2].clamp(0, _legFieldTemplate.length).toInt(),
      ),
    ];
    return spots;
  }

  static int shotPower({
    required TimingTier tier,
    required int rating,
    required DeliveryType delivery,
    bool onFire = false,
    Random? random,
  }) {
    final rng = random ?? _random;
    final tierPower = switch (tier) {
      TimingTier.perfect => 100,
      TimingTier.great => 78,
      TimingTier.good => 55,
      TimingTier.edgePoor => 25,
      TimingTier.miss => 0,
    };
    final ratingPower = ((rating - 70) * 0.7).clamp(0, 18).round();
    final deliveryPower = switch (delivery) {
      DeliveryType.pace when tier != TimingTier.miss => 5,
      DeliveryType.yorker when tier != TimingTier.perfect => -8,
      _ => 0,
    };
    final momentumPower = onFire ? 12 : 0;
    final variance = tier == TimingTier.miss ? 0 : rng.nextInt(7) - 3;
    return max(
      0,
      tierPower + ratingPower + deliveryPower + momentumPower + variance,
    );
  }

  static SuperOverShotResult resolveShot({
    required int timingErrorMs,
    required int rating,
    required DeliveryType delivery,
    required List<int> fieldSectors,
    bool onFire = false,
    bool leftHanded = false,
    Random? random,
  }) {
    final window = effectiveTimingWindowMs(rating, delivery, onFire: onFire);
    final normalized = normalizedTimingError(
      timingErrorMs: timingErrorMs,
      effectiveWindowMs: window,
    );
    final tier = timingTierForNormalizedError(normalized);
    final sector = sectorForTiming(normalized, leftHanded: leftHanded);
    final power = shotPower(
      tier: tier,
      rating: rating,
      delivery: delivery,
      onFire: onFire,
      random: random,
    );
    final outcome = resolveOutcome(
      tier,
      sector: sector,
      power: power,
      fieldSectors: fieldSectors,
      sectorFielders: fieldSectors.elementAtOrNull(sectorIndex(sector)) ?? 2,
      delivery: delivery,
      onFire: onFire,
      random: random,
    );

    return SuperOverShotResult(
      timingErrorMs: timingErrorMs,
      normalizedError: normalized,
      tier: tier,
      sector: sector,
      power: power,
      outcome: outcome,
    );
  }

  static ShotOutcome resolveOutcome(
    TimingTier tier, {
    ShotSector? sector,
    int? power,
    List<int>? fieldSectors,
    int sectorFielders = 2,
    DeliveryType delivery = DeliveryType.pace,
    bool onFire = false,
    Random? random,
  }) {
    final rng = random ?? _random;
    final weights = <ShotOutcome, double>{};

    switch (tier) {
      case TimingTier.perfect:
        weights[ShotOutcome.six] = 65;
        weights[ShotOutcome.four] = 35;
      case TimingTier.great:
        weights[ShotOutcome.four] = 45;
        weights[ShotOutcome.three] = 25;
        weights[ShotOutcome.two] = 25;
        weights[ShotOutcome.one] = 5;
      case TimingTier.good:
        weights[ShotOutcome.four] = 15;
        weights[ShotOutcome.two] = 35;
        weights[ShotOutcome.one] = 35;
        weights[ShotOutcome.dot] = 15;
      case TimingTier.edgePoor:
        weights[ShotOutcome.caught] = 18;
        weights[ShotOutcome.dot] = 35;
        weights[ShotOutcome.one] = 32;
        weights[ShotOutcome.two] = 15;
      case TimingTier.miss:
        weights[ShotOutcome.bowled] = delivery == DeliveryType.yorker ? 88 : 80;
        weights[ShotOutcome.dot] = 100 - weights[ShotOutcome.bowled]!;
    }

    final openGap = sectorFielders <= 1;
    final packed = sectorFielders >= 4;
    if (openGap) {
      _scale(weights, ShotOutcome.caught, 0.55);
      _shiftBoundaryAndDot(weights, boundaryDelta: 10, dotDelta: -10);
    } else if (packed) {
      _scale(weights, ShotOutcome.caught, 1.15);
      _shiftBoundaryAndDot(weights, boundaryDelta: -10, dotDelta: 7);
    }

    if (onFire) {
      _scale(weights, ShotOutcome.caught, 0.85);
      _shiftBoundaryAndDot(weights, boundaryDelta: 5, dotDelta: -5);
    }

    _normalize(weights);
    final total = weights.values.fold<double>(0, (s, n) => s + n);
    var roll = rng.nextDouble() * total;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll <= 0) {
        return _applyCatchingField(
          entry.key,
          tier: tier,
          sector: sector,
          power: power,
          fieldSectors: fieldSectors,
          onFire: onFire,
          random: rng,
        );
      }
    }
    return _applyCatchingField(
      weights.keys.last,
      tier: tier,
      sector: sector,
      power: power,
      fieldSectors: fieldSectors,
      onFire: onFire,
      random: rng,
    );
  }

  static ShotOutcome _applyCatchingField(
    ShotOutcome outcome, {
    required TimingTier tier,
    ShotSector? sector,
    int? power,
    List<int>? fieldSectors,
    required bool onFire,
    required Random random,
  }) {
    if (outcome == ShotOutcome.bowled || outcome == ShotOutcome.caught) {
      return outcome;
    }
    if (sector == null || power == null || fieldSectors == null) return outcome;
    if (!_isCatchableTier(tier)) return outcome;
    if (outcome == ShotOutcome.six) return outcome;
    if (outcome == ShotOutcome.dot && tier != TimingTier.edgePoor) {
      return outcome;
    }

    final range = _rangeForOutcome(outcome, power: power);
    final angle = shotAngleForSector(sector);
    final end = Point(cos(angle) * range, sin(angle) * range);
    const start = Point<double>(0, 0);

    final catchRadius = switch (tier) {
      TimingTier.perfect => 0.0,
      TimingTier.great => 0.028,
      TimingTier.good => 0.045,
      TimingTier.edgePoor => 0.082,
      TimingTier.miss => 0.0,
    };
    final adjustedRadius = catchRadius * (onFire ? 0.74 : 1.0);
    if (adjustedRadius <= 0) return outcome;

    var bestChance = 0.0;
    final sectorFielders =
        fieldSectors.elementAtOrNull(sectorIndex(sector)) ?? 0;
    final fieldPressure = max(0, sectorFielders - 3) * 0.018;
    for (final spot in fielderSpotsForSectors(fieldSectors)) {
      if (spot.sector != sector && tier != TimingTier.edgePoor) continue;
      final fielder = Point(
        cos(spot.angle) * spot.radial,
        sin(spot.angle) * spot.radial,
      );
      final radius = adjustedRadius + (spot.closeCatcher ? 0.012 : 0.0);
      if (fielder.distanceTo(start) > range + radius) continue;
      final distance = _distanceToSegment(fielder, start, end);
      if (distance > radius) continue;

      final proximity = (1 - distance / radius).clamp(0.0, 1.0);
      final baseChance = switch (tier) {
        TimingTier.perfect => 0.0,
        TimingTier.great => 0.025,
        TimingTier.good => 0.070,
        TimingTier.edgePoor => 0.220,
        TimingTier.miss => 0.0,
      };
      var chance =
          baseChance +
          proximity * 0.075 +
          fieldPressure +
          (spot.closeCatcher ? 0.025 : 0.0);
      if (outcome == ShotOutcome.four) chance *= 0.45;
      if (onFire) chance *= 0.70;
      bestChance = max(bestChance, chance.clamp(0.0, 0.42));
    }
    return random.nextDouble() < bestChance ? ShotOutcome.caught : outcome;
  }

  static bool _isCatchableTier(TimingTier tier) {
    return switch (tier) {
      TimingTier.great || TimingTier.good || TimingTier.edgePoor => true,
      TimingTier.perfect || TimingTier.miss => false,
    };
  }

  static double _rangeForOutcome(ShotOutcome outcome, {required int power}) {
    final base = switch (outcome) {
      ShotOutcome.six => 1.08,
      ShotOutcome.four => 0.96,
      ShotOutcome.three => 0.80,
      ShotOutcome.two => 0.64,
      ShotOutcome.one => 0.48,
      ShotOutcome.dot => 0.28,
      ShotOutcome.caught => 0.68,
      ShotOutcome.bowled => 0.0,
    };
    if (outcome == ShotOutcome.six || outcome == ShotOutcome.four) {
      return base;
    }
    return (base + (power - 55).clamp(-24, 36) * 0.003).clamp(0.20, 0.92);
  }

  static double _distanceToSegment(
    Point<double> p,
    Point<double> a,
    Point<double> b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSq = dx * dx + dy * dy;
    if (lengthSq == 0) return p.distanceTo(a);
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq).clamp(
      0.0,
      1.0,
    );
    final projection = Point(a.x + dx * t, a.y + dy * t);
    return p.distanceTo(projection);
  }

  static void _scale(
    Map<ShotOutcome, double> weights,
    ShotOutcome outcome,
    double factor,
  ) {
    if (weights.containsKey(outcome)) {
      weights[outcome] = weights[outcome]! * factor;
    }
  }

  static void _shiftBoundaryAndDot(
    Map<ShotOutcome, double> weights, {
    required double boundaryDelta,
    required double dotDelta,
  }) {
    final boundaryOutcomes = [ShotOutcome.six, ShotOutcome.four];
    final boundaryTotal = boundaryOutcomes.fold<double>(
      0,
      (sum, outcome) => sum + (weights[outcome] ?? 0),
    );
    if (boundaryTotal > 0) {
      for (final outcome in boundaryOutcomes) {
        final current = weights[outcome];
        if (current == null) continue;
        weights[outcome] = max(
          0,
          current + boundaryDelta * (current / boundaryTotal),
        );
      }
    }
    if (weights.containsKey(ShotOutcome.dot)) {
      weights[ShotOutcome.dot] = max(0, weights[ShotOutcome.dot]! + dotDelta);
    }
  }

  static void _normalize(Map<ShotOutcome, double> weights) {
    weights.removeWhere((_, value) => value <= 0);
    final total = weights.values.fold<double>(0, (sum, n) => sum + n);
    if (total <= 0) {
      weights
        ..clear()
        ..[ShotOutcome.dot] = 1;
    }
  }

  static int runsForOutcome(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => 6,
      ShotOutcome.four => 4,
      ShotOutcome.three => 3,
      ShotOutcome.two => 2,
      ShotOutcome.one => 1,
      ShotOutcome.dot => 0,
      ShotOutcome.caught => 0,
      ShotOutcome.bowled => 0,
    };
  }
}

CricketJersey cricketJerseyFromName(String? name) =>
    CricketJersey.values.firstWhere(
      (j) => j.name == name,
      orElse: () => CricketJersey.mumbai,
    );
