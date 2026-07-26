import 'package:final_over/final_over.dart';

import '../config/enums.dart';
import '../games/basketball/basketball_engine.dart';
import '../games/grand_prix/grand_prix_game.dart';
import '../games/tennis/tennis_engine.dart';
import '../models/football_chess.dart';
import 'sound_effects.dart';

SoundEffect? finalOverSoundForEvent(
  GameplayEventType event, {
  TimingGrade? timing,
  bool six = false,
  bool finalBallPressure = false,
}) => switch (event) {
  GameplayEventType.deliveryPrepared => SoundEffect.cricketFootstep,
  GameplayEventType.ballReleased => SoundEffect.cricketRelease,
  GameplayEventType.contactResolved => switch (timing) {
    TimingGrade.perfect => SoundEffect.cricketPerfect,
    TimingGrade.good => SoundEffect.cricketGreat,
    TimingGrade.early || TimingGrade.late => SoundEffect.cricketGood,
    TimingGrade.poor => SoundEffect.cricketEdge,
    TimingGrade.miss => SoundEffect.cricketKeeper,
    null => null,
  },
  GameplayEventType.boundary =>
    six ? SoundEffect.cricketSix : SoundEffect.cricketBoundary,
  GameplayEventType.wicket => SoundEffect.cricketStumps,
  GameplayEventType.runOut => SoundEffect.cricketRunOut,
  GameplayEventType.catchTaken => SoundEffect.cricketCatch,
  GameplayEventType.catchDropped => SoundEffect.cricketDrop,
  GameplayEventType.powerShotActivated => SoundEffect.cricketPower,
  GameplayEventType.runStarted ||
  GameplayEventType.runnerTurnedBack => SoundEffect.cricketRun,
  GameplayEventType.runCompleted => SoundEffect.uiConfirm,
  GameplayEventType.ballPickedUp => SoundEffect.cricketKeeper,
  GameplayEventType.throwStarted => SoundEffect.cricketThrow,
  GameplayEventType.cameraTransitionStarted => SoundEffect.cricketRoll,
  GameplayEventType.extraAwarded => SoundEffect.cricketExtra,
  GameplayEventType.deliveryCompleted =>
    finalBallPressure ? SoundEffect.cricketCrowdPressure : null,
  GameplayEventType.matchStarted ||
  GameplayEventType.swingAccepted ||
  GameplayEventType.paused ||
  GameplayEventType.resumed ||
  GameplayEventType.matchEnded ||
  GameplayEventType.quitToHome => null,
};

SoundEffect tennisSoundForEvent(TennisEventType event) => switch (event) {
  TennisEventType.serveStarted => SoundEffect.tennisServe,
  TennisEventType.contact => SoundEffect.tennisContact,
  TennisEventType.perfectContact => SoundEffect.tennisPerfect,
  TennisEventType.bounce => SoundEffect.tennisBounce,
  TennisEventType.net => SoundEffect.tennisNet,
  TennisEventType.let => SoundEffect.tennisLet,
  TennisEventType.fault => SoundEffect.tennisFault,
  TennisEventType.doubleFault => SoundEffect.tennisDoubleFault,
  TennisEventType.ace => SoundEffect.tennisAce,
  TennisEventType.out => SoundEffect.tennisOut,
  TennisEventType.winner => SoundEffect.tennisWinner,
  TennisEventType.pointEnded => SoundEffect.tennisPoint,
  TennisEventType.gameEnded => SoundEffect.tennisGame,
  TennisEventType.endChange => SoundEffect.tennisEndChange,
  TennisEventType.tieBreakStarted => SoundEffect.tennisTiebreak,
  TennisEventType.setEnded => SoundEffect.tennisSet,
  TennisEventType.rallyMilestone => SoundEffect.cheering,
  TennisEventType.practiceScore => SoundEffect.tennisPoint,
  TennisEventType.lessonComplete => SoundEffect.tennisLesson,
};

SoundEffect? basketballSoundForEvent(BasketballEventType event) =>
    switch (event) {
      BasketballEventType.basketMade => SoundEffect.bbSwish,
      BasketballEventType.shotMissed => SoundEffect.bbRimRattle,
      BasketballEventType.steal => SoundEffect.bbSteal,
      BasketballEventType.block => SoundEffect.bbBlock,
      BasketballEventType.rebound => SoundEffect.bbRebound,
      BasketballEventType.shotClockViolation => SoundEffect.bbShotClock,
      BasketballEventType.heatStarted => SoundEffect.bbCrowdRoar,
      BasketballEventType.heatEnded => SoundEffect.bbHeatEnd,
      BasketballEventType.ankleBreaker ||
      BasketballEventType.spinMove ||
      BasketballEventType.crossover => SoundEffect.bbSneakerSqueak,
      BasketballEventType.poster => SoundEffect.bbPoster,
      BasketballEventType.stagger => SoundEffect.bbBackboard,
      BasketballEventType.perfectRelease => SoundEffect.bbPerfectRelease,
      BasketballEventType.halfEnded => SoundEffect.bbBuzzer,
      BasketballEventType.overtimeStarted => SoundEffect.riser,
      BasketballEventType.substitution => SoundEffect.bbSubstitution,
      BasketballEventType.dunk => SoundEffect.bbDunkSlam,
      BasketballEventType.shotReleased => SoundEffect.bbRelease,
      BasketballEventType.buzzerBeater => SoundEffect.bbBuzzer,
      BasketballEventType.matchEnded => null,
    };

SoundEffect pitchDuelSoundForOutcome(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => SoundEffect.goal,
  RoundOutcome.saved => SoundEffect.save,
  RoundOutcome.blocked => SoundEffect.block,
  RoundOutcome.missed => SoundEffect.miss,
  RoundOutcome.foul => SoundEffect.foul,
  RoundOutcome.redCard => SoundEffect.redCard,
};

SoundEffect chessActionSound(BoardActionType action) => switch (action) {
  BoardActionType.move => SoundEffect.chessMove,
  BoardActionType.dribble => SoundEffect.chessDribble,
  BoardActionType.pass => SoundEffect.chessPass,
  BoardActionType.shoot => SoundEffect.chessShoot,
  BoardActionType.press => SoundEffect.chessPress,
  BoardActionType.tackle => SoundEffect.chessTackle,
  BoardActionType.slide => SoundEffect.chessSlide,
};

SoundEffect? chessEventSound(BoardEvent event) => switch (event) {
  BoardEvent.advanced => SoundEffect.chessAdvanced,
  BoardEvent.goal => SoundEffect.goal,
  BoardEvent.save => SoundEffect.save,
  BoardEvent.blocked => SoundEffect.block,
  BoardEvent.turnover => SoundEffect.chessTurnover,
  BoardEvent.none => null,
};

SoundEffect shootoutCommitSound(ShootoutTurnRole role) =>
    role == ShootoutTurnRole.shooting
    ? SoundEffect.penaltyKick
    : SoundEffect.penaltyDive;

SoundEffect shootoutImpactSound({required bool goal}) =>
    goal ? SoundEffect.penaltyGoal : SoundEffect.penaltySave;

SoundEffect grandPrixEventSound(GrandPrixAudioEvent event) => switch (event) {
  GrandPrixAudioEvent.tireScrub => SoundEffect.gpTireScrub,
  GrandPrixAudioEvent.wallContact => SoundEffect.gpWallImpact,
  GrandPrixAudioEvent.carContact => SoundEffect.gpCarImpact,
};
