// User-approved illustrative championship markets for local product demos only.
// Probabilities are sample values, not forecasts or a live market feed.
import 'package:flutter/material.dart';
import '../models/picks.dart';
import '../models/sport_match.dart';

final demoChampionshipMarkets = <PickMarket>[
  PickMarket(
    id: "demo_ucl_2027_champion",
    question: "Who wins the UCL 2026/27 title?",
    type: PickMarketType.future,
    sport: Sport.football,
    leagueId: "ucl",
    leagueLabel: "UCL · DEMO",
    status: PickMarketStatus.upcoming,
    volumeOz: 0,
    closesAt: DateTime.utc(2027, 6, 1, 18),
    resultNote: 'Illustrative demo championship; percentages are sample data.',
    outcomes: const [
      PickOutcome(
        id: "rma",
        label: "Real Madrid",
        probabilityPercent: 36,
        color: Color(0xfffebe10),
      ),
      PickOutcome(
        id: "mci",
        label: "Manchester City",
        probabilityPercent: 34,
        color: Color(0xff6cabdd),
      ),
      PickOutcome(
        id: "bay",
        label: "Bayern Munich",
        probabilityPercent: 30,
        color: Color(0xffdc052d),
      ),
    ],
  ),
  PickMarket(
    id: "demo_nba_2027_champion",
    question: "Who wins the NBA 2027 championship?",
    type: PickMarketType.future,
    sport: Sport.basketball,
    leagueId: "nba",
    leagueLabel: "NBA · DEMO",
    status: PickMarketStatus.upcoming,
    volumeOz: 0,
    closesAt: DateTime.utc(2027, 6, 30, 18),
    resultNote: 'Illustrative demo championship; percentages are sample data.',
    outcomes: const [
      PickOutcome(
        id: "bos",
        label: "Boston Celtics",
        probabilityPercent: 35,
        color: Color(0xff007a33),
      ),
      PickOutcome(
        id: "okc",
        label: "Oklahoma City Thunder",
        probabilityPercent: 34,
        color: Color(0xff007ac1),
      ),
      PickOutcome(
        id: "lal",
        label: "Los Angeles Lakers",
        probabilityPercent: 31,
        color: Color(0xfffdb927),
      ),
    ],
  ),
  PickMarket(
    id: "demo_f1_2027_drivers_champion",
    question: "Who wins the 2027 drivers’ championship?",
    type: PickMarketType.future,
    sport: Sport.motorsport,
    leagueId: "f1",
    leagueLabel: "F1 · DEMO",
    status: PickMarketStatus.upcoming,
    volumeOz: 0,
    closesAt: DateTime.utc(2027, 12, 1, 18),
    resultNote: 'Illustrative demo championship; percentages are sample data.',
    outcomes: const [
      PickOutcome(
        id: "ver",
        label: "Max Verstappen",
        probabilityPercent: 38,
        color: Color(0xff3671c6),
      ),
      PickOutcome(
        id: "nor",
        label: "Lando Norris",
        probabilityPercent: 34,
        color: Color(0xffff8000),
      ),
      PickOutcome(
        id: "lec",
        label: "Charles Leclerc",
        probabilityPercent: 28,
        color: Color(0xffe8002d),
      ),
    ],
  ),
];
