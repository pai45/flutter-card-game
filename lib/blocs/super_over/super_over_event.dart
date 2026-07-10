import '../../models/cards.dart';
import '../../models/super_over.dart';

abstract class SuperOverEvent {
  const SuperOverEvent();
}

class SuperOverStarted extends SuperOverEvent {
  const SuperOverStarted({
    required this.battingOrder,
    required this.mode,
    required this.playerLevel,
  });

  final List<PlayerCard> battingOrder;
  final SuperOverMode mode;
  final int playerLevel;
}

class SuperOverPhaseChanged extends SuperOverEvent {
  const SuperOverPhaseChanged(this.phase);

  final SuperOverPhase phase;
}

class SuperOverInputArmed extends SuperOverEvent {
  const SuperOverInputArmed();
}

class SuperOverSwingLocked extends SuperOverEvent {
  const SuperOverSwingLocked();
}

class SuperOverShotResolved extends SuperOverEvent {
  const SuperOverShotResolved({
    required this.timingErrorMs,
    this.leftHanded = false,
  });

  final int timingErrorMs;
  final bool leftHanded;
}

class SuperOverDeliveryResolved extends SuperOverEvent {
  const SuperOverDeliveryResolved(this.outcome);

  final ShotOutcome outcome;
}

class SuperOverNextBallRequested extends SuperOverEvent {
  const SuperOverNextBallRequested();
}

class SuperOverReset extends SuperOverEvent {
  const SuperOverReset();
}

class SuperOverJerseySelected extends SuperOverEvent {
  const SuperOverJerseySelected(this.jersey);
  final CricketJersey jersey;
}
