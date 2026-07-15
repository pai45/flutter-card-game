import 'package:final_over/domain/models.dart';

sealed class GameCommand {
  const GameCommand();

  const factory GameCommand.start() = StartCommand;
  const factory GameCommand.selectElevation(Elevation elevation) =
      SelectElevationCommand;
  const factory GameCommand.selectDirection(ShotDirection direction) =
      SelectDirectionCommand;
  const factory GameCommand.swing(ShotDirection direction, {double? charge}) =
      SwingCommand;
  const factory GameCommand.activatePowerShot() = ActivatePowerShotCommand;
  const factory GameCommand.startRun() = StartRunCommand;
  const factory GameCommand.holdBall() = HoldBallCommand;
  const factory GameCommand.turnBack() = TurnBackCommand;
  const factory GameCommand.pause() = PauseCommand;
  const factory GameCommand.resume() = ResumeCommand;
  const factory GameCommand.restart({int? seed, int? target}) = RestartCommand;
  const factory GameCommand.appBackgrounded() = AppBackgroundedCommand;
  const factory GameCommand.quitToHome() = QuitToHomeCommand;
}

final class StartCommand extends GameCommand {
  const StartCommand();
}

final class SelectElevationCommand extends GameCommand {
  const SelectElevationCommand(this.elevation);
  final Elevation elevation;
}

final class SelectDirectionCommand extends GameCommand {
  const SelectDirectionCommand(this.direction);
  final ShotDirection direction;
}

final class SwingCommand extends GameCommand {
  const SwingCommand(this.direction, {this.charge});
  final ShotDirection direction;

  /// Backlift at the moment of release, 0..1. See [SwingIntent.charge].
  final double? charge;
}

final class ActivatePowerShotCommand extends GameCommand {
  const ActivatePowerShotCommand();
}

final class StartRunCommand extends GameCommand {
  const StartRunCommand();
}

final class HoldBallCommand extends GameCommand {
  const HoldBallCommand();
}

final class TurnBackCommand extends GameCommand {
  const TurnBackCommand();
}

final class PauseCommand extends GameCommand {
  const PauseCommand();
}

final class ResumeCommand extends GameCommand {
  const ResumeCommand();
}

final class RestartCommand extends GameCommand {
  const RestartCommand({this.seed, this.target});
  final int? seed;
  final int? target;
}

final class AppBackgroundedCommand extends GameCommand {
  const AppBackgroundedCommand();
}

final class QuitToHomeCommand extends GameCommand {
  const QuitToHomeCommand();
}
