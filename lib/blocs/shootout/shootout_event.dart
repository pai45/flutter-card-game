import '../../config/enums.dart';

sealed class ShootoutEvent {}

/// Leaves the random-opponent reveal and shows both squads.
class ShootoutOpponentRevealCompleted extends ShootoutEvent {}

/// Leaves the lineup intro and begins the kick loop.
class ShootoutStarted extends ShootoutEvent {}

class ShootoutDirectionSelected extends ShootoutEvent {
  ShootoutDirectionSelected(this.direction);
  final PenaltyDirection direction;
}

class ShootoutKickConfirmed extends ShootoutEvent {}

class ShootoutNextKick extends ShootoutEvent {}

/// Fired from the winner banner to move on to the summary screen.
class ShootoutSummaryShown extends ShootoutEvent {}
