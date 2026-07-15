enum GameplayEventType {
  matchStarted,
  deliveryPrepared,
  ballReleased,
  swingAccepted,
  powerShotActivated,
  extraAwarded,
  contactResolved,
  cameraTransitionStarted,
  runStarted,
  runCompleted,
  runnerTurnedBack,
  catchTaken,
  catchDropped,
  ballPickedUp,
  throwStarted,
  runOut,
  boundary,
  wicket,
  deliveryCompleted,
  paused,
  resumed,
  matchEnded,
  quitToHome,
}

/// A rendering-friendly event. Payload values are primitives or domain values.
final class GameplayEvent {
  GameplayEvent({
    required this.type,
    required this.simulationMicros,
    Map<String, Object?> payload = const {},
  }) : payload = Map.unmodifiable(payload);

  final GameplayEventType type;
  final int simulationMicros;
  final Map<String, Object?> payload;
}
