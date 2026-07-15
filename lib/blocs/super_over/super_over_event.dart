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
    this.jersey = CricketJersey.nightCyan,
    this.difficulty = SuperOverDifficulty.pro,
    this.settings = const SuperOverSettings(),
    this.config,
    this.tutorial = false,
  });

  final List<PlayerCard> battingOrder;
  final SuperOverMode mode;
  final int playerLevel;
  final CricketJersey jersey;
  final SuperOverDifficulty difficulty;
  final SuperOverSettings settings;
  final SuperOverMatchConfig? config;
  final bool tutorial;
}

class SuperOverSnapshotRestored extends SuperOverEvent {
  const SuperOverSnapshotRestored({
    required this.snapshot,
    required this.battingOrder,
  });

  final SuperOverMatchSnapshot snapshot;
  final List<PlayerCard> battingOrder;
}

class SuperOverFlowChanged extends SuperOverEvent {
  const SuperOverFlowChanged(this.phase);
  final SuperOverFlowPhase phase;
}

class SuperOverPhaseChanged extends SuperOverEvent {
  const SuperOverPhaseChanged(this.phase);
  final SuperOverPhase phase;
}

class SuperOverPlayPhaseChanged extends SuperOverEvent {
  const SuperOverPlayPhaseChanged(this.phase);
  final SuperOverPlayPhase phase;
}

class SuperOverInputArmed extends SuperOverEvent {
  const SuperOverInputArmed();
}

class SuperOverIntentLocked extends SuperOverEvent {
  const SuperOverIntentLocked();
}

class SuperOverSwingLocked extends SuperOverEvent {
  const SuperOverSwingLocked();
}

class SuperOverShotResolved extends SuperOverEvent {
  const SuperOverShotResolved({
    this.intent,
    this.timingErrorMs,
    this.leftHanded = false,
    this.noInput = false,
  });

  final ShotIntent? intent;
  final int? timingErrorMs;
  final bool leftHanded;
  final bool noInput;
}

class SuperOverSectorSelected extends SuperOverEvent {
  const SuperOverSectorSelected(this.sector);
  final ShotSector sector;
}

class SuperOverShotStyleSelected extends SuperOverEvent {
  const SuperOverShotStyleSelected(this.style);
  final ShotStyle style;
}

class SuperOverDeliveryResolved extends SuperOverEvent {
  const SuperOverDeliveryResolved(this.outcome);
  final ShotOutcome outcome;
}

class SuperOverNextBallRequested extends SuperOverEvent {
  const SuperOverNextBallRequested();
}

class SuperOverPaused extends SuperOverEvent {
  const SuperOverPaused();
}

class SuperOverResumed extends SuperOverEvent {
  const SuperOverResumed();
}

class SuperOverSettingsChanged extends SuperOverEvent {
  const SuperOverSettingsChanged(this.settings);
  final SuperOverSettings settings;
}

class SuperOverReset extends SuperOverEvent {
  const SuperOverReset({this.toLanding = true});
  final bool toLanding;
}

class SuperOverJerseySelected extends SuperOverEvent {
  const SuperOverJerseySelected(this.jersey);
  final CricketJersey jersey;
}
