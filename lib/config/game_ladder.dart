import 'package:flutter/material.dart';

import '../models/sport_match.dart';

/// Every playable GAMES-tab mode, across all sports.
///
/// Names are persisted (unlock progress, reveal queue), so append new values
/// and never rename existing ones.
enum ArcadeGame {
  pitchDuel(Sport.football, 'PITCH DUEL', Icons.style),
  penaltyShootout(Sport.football, 'PENALTY SHOOTOUT', Icons.sports_soccer),
  footballQuiz(Sport.football, 'FOOTBALL QUIZ', Icons.quiz, isQuiz: true),
  footballGuessPlayer(Sport.football, 'GUESS THE PLAYER', Icons.person_search),
  footballBingo(Sport.football, 'FOOTBALL BINGO', Icons.grid_on),
  footballChess(Sport.football, '5V5 FOOTBALL CHESS', Icons.grid_view),
  finalOver(Sport.cricket, 'FINAL OVER', Icons.sports_cricket),
  cricketQuiz(Sport.cricket, 'CRICKET QUIZ', Icons.quiz, isQuiz: true),
  cricketGuessPlayer(Sport.cricket, 'GUESS THE PLAYER', Icons.person_search),
  hoopDuel(Sport.basketball, 'HOOP DUEL', Icons.sports_basketball),
  basketballQuiz(Sport.basketball, 'BASKETBALL QUIZ', Icons.quiz, isQuiz: true),
  basketballGuessPlayer(
    Sport.basketball,
    'GUESS THE PLAYER',
    Icons.person_search,
  ),
  grandPrixDash(Sport.motorsport, 'GRAND PRIX DASH', Icons.sports_motorsports),
  motorsportQuiz(Sport.motorsport, 'MOTORSPORT QUIZ', Icons.quiz, isQuiz: true),
  guessDriver(Sport.motorsport, 'GUESS THE DRIVER', Icons.person_search),
  tennisRally(Sport.tennis, 'TENNIS RALLY', Icons.sports_tennis),
  tennisQuiz(Sport.tennis, 'TENNIS QUIZ', Icons.quiz, isQuiz: true),
  guessWinner(Sport.tennis, 'GUESS THE WINNER', Icons.emoji_events);

  const ArcadeGame(this.sport, this.title, this.icon, {this.isQuiz = false});

  final Sport sport;
  final String title;
  final IconData icon;
  final bool isQuiz;

  /// 0-based position on its sport's Beginner's Quest ladder.
  int get ladderIndex => sportGameLadder[sport]!.indexOf(this);
}

/// Beginner's Quest order per sport: game N+1 unlocks once game N has been
/// finished. Quick, low-friction modes come first; the deepest mode is last.
const sportGameLadder = <Sport, List<ArcadeGame>>{
  Sport.football: [
    ArcadeGame.pitchDuel,
    ArcadeGame.penaltyShootout,
    ArcadeGame.footballQuiz,
    ArcadeGame.footballGuessPlayer,
    ArcadeGame.footballBingo,
    ArcadeGame.footballChess,
  ],
  Sport.cricket: [
    ArcadeGame.finalOver,
    ArcadeGame.cricketQuiz,
    ArcadeGame.cricketGuessPlayer,
  ],
  Sport.basketball: [
    ArcadeGame.hoopDuel,
    ArcadeGame.basketballQuiz,
    ArcadeGame.basketballGuessPlayer,
  ],
  Sport.motorsport: [
    ArcadeGame.grandPrixDash,
    ArcadeGame.motorsportQuiz,
    ArcadeGame.guessDriver,
  ],
  Sport.tennis: [
    ArcadeGame.tennisRally,
    ArcadeGame.tennisQuiz,
    ArcadeGame.guessWinner,
  ],
};

ArcadeGame quizGameFor(Sport sport) =>
    sportGameLadder[sport]!.firstWhere((game) => game.isQuiz);

/// Oz to unlock a sport beyond the home sport.
const sportUnlockCostOz = 50;

/// XP for each Beginner's Quest step cleared.
const beginnerQuestStepXp = 40;

/// Oz paid out when a sport's whole Beginner's Quest is cleared — exactly one
/// sport unlock, so finishing a chain funds the next sport.
const beginnerQuestCompleteOz = 50;
