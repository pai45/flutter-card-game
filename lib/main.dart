import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PitchDuelApp());
}

enum AppSection { home, deck, howToPlay, match, game, shop }

enum DeckPickerLane { attacker, defender, action }

enum CardTier { bronze, silver, gold, platinum }

enum PlayerRole { attacker, defender, goalkeeper }

enum ActionCategory { attack, defense, special }

enum MatchPhase {
  idle,
  toss,
  tossResult,
  scenario,
  play,
  roundResult,
  matchEnd,
  penalty,
  finalResult,
}

enum RoundOutcome { goal, saved, blocked, missed, foul, redCard }

class Cyber {
  static const bg = Color(0xff05070d);
  static const bg2 = Color(0xff0a0e1a);
  static const panel = Color(0xff0e1424);
  static const panel2 = Color(0xff131b2e);
  static const cyan = Color(0xff5cdfff);
  static const magenta = Color(0xffff3df7);
  static const lime = Color(0xffb6ff3d);
  static const amber = Color(0xffffb13d);
  static const red = Color(0xffff2e63);
  static const violet = Color(0xff8a5cff);
  static const line = Color(0x665cdfff);
  static const muted = Color(0xff8fa3b8);

  static LinearGradient panelGradient([Color? glow]) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [(glow ?? cyan).withValues(alpha: 0.16), panel, panel2],
    stops: const [0, 0.42, 1],
  );
}

class PlayerCard {
  const PlayerCard({
    required this.id,
    required this.name,
    required this.shortName,
    required this.country,
    required this.countryCode,
    required this.position,
    required this.role,
    required this.rating,
    required this.trait,
    required this.tier,
    required this.icon,
  });

  final String id;
  final String name;
  final String shortName;
  final String country;
  final String countryCode;
  final String position;
  final PlayerRole role;
  final int rating;
  final String trait;
  final CardTier tier;
  final IconData icon;

  bool get isGoalkeeper => role == PlayerRole.goalkeeper;
}

class ActionCard {
  const ActionCard({
    required this.id,
    required this.title,
    required this.category,
    required this.effect,
    required this.power,
    required this.risky,
    required this.icon,
  });

  final String id;
  final String title;
  final ActionCategory category;
  final String effect;
  final int power;
  final bool risky;
  final IconData icon;
}

class ScenarioCard {
  const ScenarioCard({
    required this.id,
    required this.title,
    required this.description,
    required this.attackBonus,
    required this.defenseBonus,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int attackBonus;
  final int defenseBonus;
  final IconData icon;
}

class AppInfoItem {
  const AppInfoItem({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
}

class MatchHistoryRound {
  const MatchHistoryRound({
    required this.round,
    required this.scenarioTitle,
    required this.outcomeLabel,
    required this.playerAttacking,
  });

  final int round;
  final String scenarioTitle;
  final String outcomeLabel;
  final bool playerAttacking;

  Map<String, dynamic> toJson() => {
    'round': round,
    'scenarioTitle': scenarioTitle,
    'outcomeLabel': outcomeLabel,
    'playerAttacking': playerAttacking,
  };

  static MatchHistoryRound fromJson(Map<String, dynamic> json) =>
      MatchHistoryRound(
        round: json['round'] as int,
        scenarioTitle: json['scenarioTitle'] as String,
        outcomeLabel: json['outcomeLabel'] as String,
        playerAttacking: json['playerAttacking'] as bool,
      );
}

class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.deckName,
    required this.timestampIso,
    required this.resultLabel,
    required this.playerScore,
    required this.opponentScore,
    required this.penaltyPlayerScore,
    required this.penaltyOpponentScore,
    required this.rounds,
  });

  final String id;
  final String deckName;
  final String timestampIso;
  final String resultLabel;
  final int playerScore;
  final int opponentScore;
  final int? penaltyPlayerScore;
  final int? penaltyOpponentScore;
  final List<MatchHistoryRound> rounds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'deckName': deckName,
    'timestampIso': timestampIso,
    'resultLabel': resultLabel,
    'playerScore': playerScore,
    'opponentScore': opponentScore,
    'penaltyPlayerScore': penaltyPlayerScore,
    'penaltyOpponentScore': penaltyOpponentScore,
    'rounds': rounds.map((round) => round.toJson()).toList(),
  };

  static MatchHistoryEntry fromJson(Map<String, dynamic> json) =>
      MatchHistoryEntry(
        id: json['id'] as String,
        deckName: json['deckName'] as String,
        timestampIso: json['timestampIso'] as String,
        resultLabel: json['resultLabel'] as String,
        playerScore: json['playerScore'] as int,
        opponentScore: json['opponentScore'] as int,
        penaltyPlayerScore: json['penaltyPlayerScore'] as int?,
        penaltyOpponentScore: json['penaltyOpponentScore'] as int?,
        rounds: (json['rounds'] as List)
            .map(
              (item) =>
                  MatchHistoryRound.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
}

class RoundResult {
  const RoundResult({
    required this.round,
    required this.scenario,
    required this.playerAttacking,
    required this.attackerCard,
    required this.defenderCard,
    required this.attackAction,
    required this.defenseAction,
    required this.outcome,
    required this.attackPower,
    required this.defensePower,
  });

  final int round;
  final ScenarioCard scenario;
  final bool playerAttacking;
  final PlayerCard attackerCard;
  final PlayerCard defenderCard;
  final ActionCard attackAction;
  final ActionCard defenseAction;
  final RoundOutcome outcome;
  final double attackPower;
  final double defensePower;
}

class PenaltyKick {
  const PenaltyKick({
    required this.byPlayer,
    required this.scored,
    required this.label,
  });

  final bool byPlayer;
  final bool scored;
  final String label;
}

class StoredDeckSlot {
  const StoredDeckSlot({
    required this.id,
    required this.name,
    required this.attackers,
    required this.defenders,
    required this.actions,
  });

  final String id;
  final String name;
  final List<String> attackers;
  final List<String> defenders;
  final List<String> actions;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'attackers': attackers,
    'defenders': defenders,
    'actions': actions,
  };

  static StoredDeckSlot fromJson(Map<String, dynamic> json) => StoredDeckSlot(
    id: json['id'] as String,
    name: json['name'] as String,
    attackers: List<String>.from(json['attackers'] as List),
    defenders: List<String>.from(json['defenders'] as List),
    actions: List<String>.from(json['actions'] as List),
  );
}

const attackers = [
  // === ARGENTINA ===
  PlayerCard(id: 'arg-lionel-messi', name: 'Lionel Messi', shortName: 'LEO 10', country: 'Argentina', countryCode: 'ARG', position: 'RW/CAM', role: PlayerRole.attacker, rating: 92, trait: 'Creator Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'arg-lautaro-martinez', name: 'Lautaro Martínez', shortName: 'LAUTARO', country: 'Argentina', countryCode: 'ARG', position: 'ST', role: PlayerRole.attacker, rating: 90, trait: 'Box Striker', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'arg-julian-alvarez', name: 'Julián Álvarez', shortName: 'ALVAREZ', country: 'Argentina', countryCode: 'ARG', position: 'ST/SS', role: PlayerRole.attacker, rating: 90, trait: 'Pressing Forward', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'arg-rodrigo-de-paul', name: 'Rodrigo De Paul', shortName: 'DE PAUL', country: 'Argentina', countryCode: 'ARG', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Engine Midfielder', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'arg-enzo-fernandez', name: 'Enzo Fernández', shortName: 'ENZO', country: 'Argentina', countryCode: 'ARG', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'arg-alexis-mac-allister', name: 'Alexis Mac Allister', shortName: 'ALEXIS', country: 'Argentina', countryCode: 'ARG', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Chance Creator', tier: CardTier.silver, icon: Icons.sync_alt),
  // === BRAZIL ===
  PlayerCard(id: 'bra-vinicius-junior', name: 'Vinícius Júnior', shortName: 'VINICIUS JR', country: 'Brazil', countryCode: 'BRA', position: 'LW', role: PlayerRole.attacker, rating: 92, trait: 'Explosive Winger', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'bra-neymar', name: 'Neymar', shortName: 'NEYMAR', country: 'Brazil', countryCode: 'BRA', position: 'LW/SS', role: PlayerRole.attacker, rating: 92, trait: 'Flair Forward', tier: CardTier.platinum, icon: Icons.auto_awesome),
  PlayerCard(id: 'bra-raphinha', name: 'Raphinha', shortName: 'RAPHINHA', country: 'Brazil', countryCode: 'BRA', position: 'RW', role: PlayerRole.attacker, rating: 90, trait: 'Direct Runner', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'bra-bruno-guimaraes', name: 'Bruno Guimarães', shortName: 'BRUNO G.', country: 'Brazil', countryCode: 'BRA', position: 'CM', role: PlayerRole.attacker, rating: 90, trait: 'Press Breaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'bra-matheus-cunha', name: 'Matheus Cunha', shortName: 'CUNHA', country: 'Brazil', countryCode: 'BRA', position: 'ST/SS', role: PlayerRole.attacker, rating: 88, trait: 'Link-Up Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  // === FRANCE ===
  PlayerCard(id: 'fra-kylian-mbappe', name: 'Kylian Mbappé', shortName: 'MBAPPE', country: 'France', countryCode: 'FRA', position: 'ST/LW', role: PlayerRole.attacker, rating: 92, trait: 'Clinical Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'fra-ousmane-dembele', name: 'Ousmane Dembélé', shortName: 'DEMBELE', country: 'France', countryCode: 'FRA', position: 'RW', role: PlayerRole.attacker, rating: 90, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'fra-michael-olise', name: 'Michael Olise', shortName: 'OLISE', country: 'France', countryCode: 'FRA', position: 'CAM/RW', role: PlayerRole.attacker, rating: 90, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  // === ENGLAND ===
  PlayerCard(id: 'eng-harry-kane', name: 'Harry Kane', shortName: 'KANE', country: 'England', countryCode: 'ENG', position: 'ST', role: PlayerRole.attacker, rating: 92, trait: 'Clinical Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'eng-jude-bellingham', name: 'Jude Bellingham', shortName: 'BELLINGHAM', country: 'England', countryCode: 'ENG', position: 'CAM/CM', role: PlayerRole.attacker, rating: 92, trait: 'Box-to-Box Star', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'eng-bukayo-saka', name: 'Bukayo Saka', shortName: 'SAKA', country: 'England', countryCode: 'ENG', position: 'RW', role: PlayerRole.attacker, rating: 90, trait: 'Wide Creator', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'eng-phil-foden', name: 'Phil Foden', shortName: 'FODEN', country: 'England', countryCode: 'ENG', position: 'CAM/LW', role: PlayerRole.attacker, rating: 90, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'eng-marcus-rashford', name: 'Marcus Rashford', shortName: 'RASHFORD', country: 'England', countryCode: 'ENG', position: 'LW/ST', role: PlayerRole.attacker, rating: 88, trait: 'Inside Forward', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'eng-cole-palmer', name: 'Cole Palmer', shortName: 'PALMER', country: 'England', countryCode: 'ENG', position: 'CAM/RW', role: PlayerRole.attacker, rating: 88, trait: 'Technical Creator', tier: CardTier.silver, icon: Icons.psychology),
  // === PORTUGAL ===
  PlayerCard(id: 'por-cristiano-ronaldo', name: 'Cristiano Ronaldo', shortName: 'RONALDO', country: 'Portugal', countryCode: 'POR', position: 'ST', role: PlayerRole.attacker, rating: 92, trait: 'Iconic Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'por-rafael-leao', name: 'Rafael Leão', shortName: 'LEAO', country: 'Portugal', countryCode: 'POR', position: 'LW', role: PlayerRole.attacker, rating: 90, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'por-bruno-fernandes', name: 'Bruno Fernandes', shortName: 'B. FERNANDES', country: 'Portugal', countryCode: 'POR', position: 'CAM', role: PlayerRole.attacker, rating: 90, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'por-bernardo-silva', name: 'Bernardo Silva', shortName: 'B. SILVA', country: 'Portugal', countryCode: 'POR', position: 'RW/CAM', role: PlayerRole.attacker, rating: 90, trait: 'Technical Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'por-vitinha', name: 'Vitinha', shortName: 'VITINHA', country: 'Portugal', countryCode: 'POR', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  // === SPAIN ===
  PlayerCard(id: 'esp-lamine-yamal', name: 'Lamine Yamal', shortName: 'YAMAL', country: 'Spain', countryCode: 'ESP', position: 'RW', role: PlayerRole.attacker, rating: 90, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'esp-nico-williams', name: 'Nico Williams', shortName: 'NICO', country: 'Spain', countryCode: 'ESP', position: 'LW', role: PlayerRole.attacker, rating: 90, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'esp-pedri-gonzalez', name: 'Pedri González', shortName: 'PEDRI', country: 'Spain', countryCode: 'ESP', position: 'CM/CAM', role: PlayerRole.attacker, rating: 90, trait: 'Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'esp-mikel-oyarzabal', name: 'Mikel Oyarzabal', shortName: 'OYARZABAL', country: 'Spain', countryCode: 'ESP', position: 'ST/SS', role: PlayerRole.attacker, rating: 88, trait: 'Support Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  // === GERMANY ===
  PlayerCard(id: 'ger-jamal-musiala', name: 'Jamal Musiala', shortName: 'MUSIALA', country: 'Germany', countryCode: 'GER', position: 'CAM/LW', role: PlayerRole.attacker, rating: 90, trait: 'Agile Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'ger-florian-wirtz', name: 'Florian Wirtz', shortName: 'WIRTZ', country: 'Germany', countryCode: 'GER', position: 'CAM', role: PlayerRole.attacker, rating: 90, trait: 'Chance Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'ger-kai-havertz', name: 'Kai Havertz', shortName: 'HAVERTZ', country: 'Germany', countryCode: 'GER', position: 'ST/CAM', role: PlayerRole.attacker, rating: 88, trait: 'Link-Up Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'ger-leroy-sane', name: 'Leroy Sané', shortName: 'SANE', country: 'Germany', countryCode: 'GER', position: 'RW/LW', role: PlayerRole.attacker, rating: 88, trait: 'Explosive Winger', tier: CardTier.silver, icon: Icons.directions_run),
  // === NETHERLANDS ===
  PlayerCard(id: 'ned-frenkie-de-jong', name: 'Frenkie de Jong', shortName: 'F. DE JONG', country: 'Netherlands', countryCode: 'NED', position: 'CM', role: PlayerRole.attacker, rating: 90, trait: 'Tempo Controller', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'ned-cody-gakpo', name: 'Cody Gakpo', shortName: 'GAKPO', country: 'Netherlands', countryCode: 'NED', position: 'LW/ST', role: PlayerRole.attacker, rating: 90, trait: 'Inside Forward', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'ned-xavi-simons', name: 'Xavi Simons', shortName: 'SIMONS', country: 'Netherlands', countryCode: 'NED', position: 'CAM/RW', role: PlayerRole.attacker, rating: 88, trait: 'Flair Playmaker', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'ned-memphis-depay', name: 'Memphis Depay', shortName: 'DEPAY', country: 'Netherlands', countryCode: 'NED', position: 'ST/SS', role: PlayerRole.attacker, rating: 88, trait: 'Creator Finisher', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'ned-ryan-gravenberch', name: 'Ryan Gravenberch', shortName: 'GRAVENBERCH', country: 'Netherlands', countryCode: 'NED', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Press Breaker', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'ned-tijjani-reijnders', name: 'Tijjani Reijnders', shortName: 'REIJNDERS', country: 'Netherlands', countryCode: 'NED', position: 'CM/CAM', role: PlayerRole.attacker, rating: 88, trait: 'Late Runner', tier: CardTier.silver, icon: Icons.sync_alt),
  // === BELGIUM ===
  PlayerCard(id: 'bel-kevin-de-bruyne', name: 'Kevin De Bruyne', shortName: 'DE BRUYNE', country: 'Belgium', countryCode: 'BEL', position: 'CAM/CM', role: PlayerRole.attacker, rating: 92, trait: 'Master Creator', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'bel-romelu-lukaku', name: 'Romelu Lukaku', shortName: 'LUKAKU', country: 'Belgium', countryCode: 'BEL', position: 'ST', role: PlayerRole.attacker, rating: 90, trait: 'Power Striker', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'bel-jeremy-doku', name: 'Jérémy Doku', shortName: 'DOKU', country: 'Belgium', countryCode: 'BEL', position: 'LW/RW', role: PlayerRole.attacker, rating: 88, trait: 'Explosive Winger', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'bel-leandro-trossard', name: 'Leandro Trossard', shortName: 'TROSSARD', country: 'Belgium', countryCode: 'BEL', position: 'LW/SS', role: PlayerRole.attacker, rating: 88, trait: 'Technical Forward', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'bel-youri-tielemans', name: 'Youri Tielemans', shortName: 'TIELEMANS', country: 'Belgium', countryCode: 'BEL', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  // === CROATIA ===
  PlayerCard(id: 'cro-luka-modric', name: 'Luka Modrić', shortName: 'MODRIC', country: 'Croatia', countryCode: 'CRO', position: 'CM', role: PlayerRole.attacker, rating: 92, trait: 'Tempo Maestro', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'cro-mateo-kovacic', name: 'Mateo Kovačić', shortName: 'KOVACIC', country: 'Croatia', countryCode: 'CRO', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Press Breaker', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'cro-ivan-perisic', name: 'Ivan Perišić', shortName: 'PERISIC', country: 'Croatia', countryCode: 'CRO', position: 'LW/LWB', role: PlayerRole.attacker, rating: 88, trait: 'Big-Game Winger', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'cro-andrej-kramaric', name: 'Andrej Kramarić', shortName: 'KRAMARIC', country: 'Croatia', countryCode: 'CRO', position: 'ST/SS', role: PlayerRole.attacker, rating: 88, trait: 'Support Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'cro-lovro-majer', name: 'Lovro Majer', shortName: 'MAJER', country: 'Croatia', countryCode: 'CRO', position: 'CAM', role: PlayerRole.attacker, rating: 86, trait: 'Creative Playmaker', tier: CardTier.bronze, icon: Icons.psychology),
  PlayerCard(id: 'cro-ante-budimir', name: 'Ante Budimir', shortName: 'BUDIMIR', country: 'Croatia', countryCode: 'CRO', position: 'ST', role: PlayerRole.attacker, rating: 86, trait: 'Box Striker', tier: CardTier.bronze, icon: Icons.sports_soccer),
  // === URUGUAY ===
  PlayerCard(id: 'uru-federico-valverde', name: 'Federico Valverde', shortName: 'VALVERDE', country: 'Uruguay', countryCode: 'URU', position: 'CM/RW', role: PlayerRole.attacker, rating: 92, trait: 'Engine Midfielder', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'uru-darwin-nunez', name: 'Darwin Núñez', shortName: 'NUNEZ', country: 'Uruguay', countryCode: 'URU', position: 'ST', role: PlayerRole.attacker, rating: 90, trait: 'Power Forward', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'uru-rodrigo-bentancur', name: 'Rodrigo Bentancur', shortName: 'BENTANCUR', country: 'Uruguay', countryCode: 'URU', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'uru-giorgian-de-arrascaeta', name: 'Giorgian De Arrascaeta', shortName: 'ARRASCAETA', country: 'Uruguay', countryCode: 'URU', position: 'CAM', role: PlayerRole.attacker, rating: 88, trait: 'Final Pass Specialist', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'uru-facundo-pellistri', name: 'Facundo Pellistri', shortName: 'PELLISTRI', country: 'Uruguay', countryCode: 'URU', position: 'RW', role: PlayerRole.attacker, rating: 86, trait: 'Direct Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'uru-maximiliano-araujo', name: 'Maximiliano Araújo', shortName: 'M. ARAUJO', country: 'Uruguay', countryCode: 'URU', position: 'LW/LB', role: PlayerRole.attacker, rating: 86, trait: 'Wide Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  // === COLOMBIA ===
  PlayerCard(id: 'col-luis-diaz', name: 'Luis Díaz', shortName: 'LUIS DIAZ', country: 'Colombia', countryCode: 'COL', position: 'LW', role: PlayerRole.attacker, rating: 90, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'col-james-rodriguez', name: 'James Rodríguez', shortName: 'JAMES', country: 'Colombia', countryCode: 'COL', position: 'CAM', role: PlayerRole.attacker, rating: 90, trait: 'Master Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'col-jhon-arias', name: 'Jhon Arias', shortName: 'ARIAS', country: 'Colombia', countryCode: 'COL', position: 'RW/CAM', role: PlayerRole.attacker, rating: 88, trait: 'Wide Creator', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'col-jhon-duran', name: 'Jhon Durán', shortName: 'DURAN', country: 'Colombia', countryCode: 'COL', position: 'ST', role: PlayerRole.attacker, rating: 88, trait: 'Power Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'col-luis-sinisterra', name: 'Luis Sinisterra', shortName: 'SINISTERRA', country: 'Colombia', countryCode: 'COL', position: 'LW', role: PlayerRole.attacker, rating: 88, trait: 'Inside Forward', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'col-richard-rios', name: 'Richard Ríos', shortName: 'RIOS', country: 'Colombia', countryCode: 'COL', position: 'CM', role: PlayerRole.attacker, rating: 86, trait: 'Press Breaker', tier: CardTier.bronze, icon: Icons.sync_alt),
  // === USA ===
  PlayerCard(id: 'usa-christian-pulisic', name: 'Christian Pulisic', shortName: 'PULISIC', country: 'USA', countryCode: 'USA', position: 'LW/RW', role: PlayerRole.attacker, rating: 90, trait: 'Captain Creator', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'usa-weston-mckennie', name: 'Weston McKennie', shortName: 'MCKENNIE', country: 'USA', countryCode: 'USA', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Box-to-Box', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'usa-folarin-balogun', name: 'Folarin Balogun', shortName: 'BALOGUN', country: 'USA', countryCode: 'USA', position: 'ST', role: PlayerRole.attacker, rating: 88, trait: 'Clinical Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'usa-tim-weah', name: 'Tim Weah', shortName: 'WEAH', country: 'USA', countryCode: 'USA', position: 'RW/RWB', role: PlayerRole.attacker, rating: 86, trait: 'Direct Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'usa-gio-reyna', name: 'Gio Reyna', shortName: 'REYNA', country: 'USA', countryCode: 'USA', position: 'CAM/RW', role: PlayerRole.attacker, rating: 86, trait: 'Flair Playmaker', tier: CardTier.bronze, icon: Icons.psychology),
  PlayerCard(id: 'usa-yunus-musah', name: 'Yunus Musah', shortName: 'MUSAH', country: 'USA', countryCode: 'USA', position: 'CM', role: PlayerRole.attacker, rating: 86, trait: 'Press Breaker', tier: CardTier.bronze, icon: Icons.sync_alt),
  // === MEXICO ===
  PlayerCard(id: 'mex-santiago-gimenez', name: 'Santiago Giménez', shortName: 'SANTI', country: 'Mexico', countryCode: 'MEX', position: 'ST', role: PlayerRole.attacker, rating: 88, trait: 'Clinical Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'mex-raul-jimenez', name: 'Raúl Jiménez', shortName: 'RAUL', country: 'Mexico', countryCode: 'MEX', position: 'ST', role: PlayerRole.attacker, rating: 88, trait: 'Target Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'mex-hirving-lozano', name: 'Hirving Lozano', shortName: 'LOZANO', country: 'Mexico', countryCode: 'MEX', position: 'LW/RW', role: PlayerRole.attacker, rating: 88, trait: 'Explosive Winger', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'mex-luis-chavez', name: 'Luis Chávez', shortName: 'CHAVEZ', country: 'Mexico', countryCode: 'MEX', position: 'CM', role: PlayerRole.attacker, rating: 86, trait: 'Set-Piece Creator', tier: CardTier.bronze, icon: Icons.sync_alt),
  // === CANADA ===
  PlayerCard(id: 'can-jonathan-david', name: 'Jonathan David', shortName: 'J. DAVID', country: 'Canada', countryCode: 'CAN', position: 'ST', role: PlayerRole.attacker, rating: 90, trait: 'Clinical Finisher', tier: CardTier.gold, icon: Icons.sports_soccer),
  PlayerCard(id: 'can-tajon-buchanan', name: 'Tajon Buchanan', shortName: 'BUCHANAN', country: 'Canada', countryCode: 'CAN', position: 'RW/RWB', role: PlayerRole.attacker, rating: 88, trait: 'Direct Runner', tier: CardTier.silver, icon: Icons.directions_run),
  PlayerCard(id: 'can-ismael-kone', name: 'Ismaël Koné', shortName: 'KONE', country: 'Canada', countryCode: 'CAN', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Ball Carrier', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'can-cyle-larin', name: 'Cyle Larin', shortName: 'LARIN', country: 'Canada', countryCode: 'CAN', position: 'ST', role: PlayerRole.attacker, rating: 88, trait: 'Box Striker', tier: CardTier.silver, icon: Icons.sports_soccer),
  // === JAPAN ===
  PlayerCard(id: 'jpn-kaoru-mitoma', name: 'Kaoru Mitoma', shortName: 'MITOMA', country: 'Japan', countryCode: 'JPN', position: 'LW', role: PlayerRole.attacker, rating: 90, trait: 'Explosive Winger', tier: CardTier.gold, icon: Icons.directions_run),
  PlayerCard(id: 'jpn-takefusa-kubo', name: 'Takefusa Kubo', shortName: 'KUBO', country: 'Japan', countryCode: 'JPN', position: 'RW/CAM', role: PlayerRole.attacker, rating: 90, trait: 'Technical Creator', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'jpn-takumi-minamino', name: 'Takumi Minamino', shortName: 'MINAMINO', country: 'Japan', countryCode: 'JPN', position: 'CAM/LW', role: PlayerRole.attacker, rating: 88, trait: 'Support Forward', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'jpn-daichi-kamada', name: 'Daichi Kamada', shortName: 'KAMADA', country: 'Japan', countryCode: 'JPN', position: 'CAM', role: PlayerRole.attacker, rating: 88, trait: 'Final Pass Specialist', tier: CardTier.silver, icon: Icons.psychology),
  PlayerCard(id: 'jpn-ritsu-doan', name: 'Ritsu Doan', shortName: 'DOAN', country: 'Japan', countryCode: 'JPN', position: 'RW', role: PlayerRole.attacker, rating: 88, trait: 'Cut-In Winger', tier: CardTier.silver, icon: Icons.directions_run),
  // === SOUTH KOREA ===
  PlayerCard(id: 'kor-son-heung-min', name: 'Son Heung-min', shortName: 'SON', country: 'South Korea', countryCode: 'KOR', position: 'LW/ST', role: PlayerRole.attacker, rating: 92, trait: 'Captain Finisher', tier: CardTier.platinum, icon: Icons.bolt),
  PlayerCard(id: 'kor-lee-kang-in', name: 'Lee Kang-in', shortName: 'KANG-IN', country: 'South Korea', countryCode: 'KOR', position: 'CAM/RW', role: PlayerRole.attacker, rating: 90, trait: 'Creative Playmaker', tier: CardTier.gold, icon: Icons.psychology),
  PlayerCard(id: 'kor-hwang-hee-chan', name: 'Hwang Hee-chan', shortName: 'HWANG', country: 'South Korea', countryCode: 'KOR', position: 'ST/LW', role: PlayerRole.attacker, rating: 88, trait: 'Direct Forward', tier: CardTier.silver, icon: Icons.sports_soccer),
  PlayerCard(id: 'kor-hwang-in-beom', name: 'Hwang In-beom', shortName: 'IN-BEOM', country: 'South Korea', countryCode: 'KOR', position: 'CM', role: PlayerRole.attacker, rating: 88, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.sync_alt),
  PlayerCard(id: 'kor-oh-hyeon-gyu', name: 'Oh Hyeon-gyu', shortName: 'OH', country: 'South Korea', countryCode: 'KOR', position: 'ST', role: PlayerRole.attacker, rating: 86, trait: 'Box Striker', tier: CardTier.bronze, icon: Icons.sports_soccer),
  PlayerCard(id: 'kor-lee-jae-sung', name: 'Lee Jae-sung', shortName: 'JAE-SUNG', country: 'South Korea', countryCode: 'KOR', position: 'CAM', role: PlayerRole.attacker, rating: 86, trait: 'Link-Up Creator', tier: CardTier.bronze, icon: Icons.psychology),
  // === AUSTRALIA ===
  PlayerCard(id: 'aus-riley-mcgree', name: 'Riley McGree', shortName: 'MCGREE', country: 'Australia', countryCode: 'AUS', position: 'CAM/LW', role: PlayerRole.attacker, rating: 86, trait: 'Chance Creator', tier: CardTier.bronze, icon: Icons.psychology),
  PlayerCard(id: 'aus-nestory-irankunda', name: 'Nestory Irankunda', shortName: 'IRANKUNDA', country: 'Australia', countryCode: 'AUS', position: 'RW', role: PlayerRole.attacker, rating: 84, trait: 'Explosive Prospect', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'aus-martin-boyle', name: 'Martin Boyle', shortName: 'BOYLE', country: 'Australia', countryCode: 'AUS', position: 'RW', role: PlayerRole.attacker, rating: 86, trait: 'Direct Runner', tier: CardTier.bronze, icon: Icons.directions_run),
  PlayerCard(id: 'aus-mitchell-duke', name: 'Mitchell Duke', shortName: 'DUKE', country: 'Australia', countryCode: 'AUS', position: 'ST', role: PlayerRole.attacker, rating: 86, trait: 'Target Forward', tier: CardTier.bronze, icon: Icons.sports_soccer),
];

const defenders = [
  // === ARGENTINA ===
  PlayerCard(id: 'arg-cristian-romero', name: 'Cristian Romero', shortName: 'ROMERO', country: 'Argentina', countryCode: 'ARG', position: 'CB', role: PlayerRole.defender, rating: 90, trait: 'Aggressive Stopper', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'arg-lisandro-martinez', name: 'Lisandro Martínez', shortName: 'LISANDRO', country: 'Argentina', countryCode: 'ARG', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Ball-Winning CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'arg-nahuel-molina', name: 'Nahuel Molina', shortName: 'MOLINA', country: 'Argentina', countryCode: 'ARG', position: 'RB', role: PlayerRole.defender, rating: 86, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === BRAZIL ===
  PlayerCard(id: 'bra-casemiro', name: 'Casemiro', shortName: 'CASEMIRO', country: 'Brazil', countryCode: 'BRA', position: 'CDM', role: PlayerRole.defender, rating: 90, trait: 'Shield Midfielder', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'bra-marquinhos', name: 'Marquinhos', shortName: 'MARQUINHOS', country: 'Brazil', countryCode: 'BRA', position: 'CB', role: PlayerRole.defender, rating: 90, trait: 'Leader CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'bra-gabriel-magalhaes', name: 'Gabriel Magalhães', shortName: 'GABRIEL', country: 'Brazil', countryCode: 'BRA', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  // === FRANCE ===
  PlayerCard(id: 'fra-aurelien-tchouameni', name: 'Aurélien Tchouaméni', shortName: 'TCHOUAMENI', country: 'France', countryCode: 'FRA', position: 'CDM', role: PlayerRole.defender, rating: 90, trait: 'Ball Winner', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'fra-william-saliba', name: 'William Saliba', shortName: 'SALIBA', country: 'France', countryCode: 'FRA', position: 'CB', role: PlayerRole.defender, rating: 90, trait: 'Ball-Playing CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'fra-dayot-upamecano', name: 'Dayot Upamecano', shortName: 'UPAMECANO', country: 'France', countryCode: 'FRA', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Power Stopper', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'fra-jules-kounde', name: 'Jules Koundé', shortName: 'KOUNDE', country: 'France', countryCode: 'FRA', position: 'RB/CB', role: PlayerRole.defender, rating: 88, trait: 'Recovery Defender', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'fra-theo-hernandez', name: 'Theo Hernández', shortName: 'THEO', country: 'France', countryCode: 'FRA', position: 'LB', role: PlayerRole.defender, rating: 88, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'fra-n-golo-kante', name: "N'Golo Kanté", shortName: 'KANTE', country: 'France', countryCode: 'FRA', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  // === ENGLAND ===
  PlayerCard(id: 'eng-declan-rice', name: 'Declan Rice', shortName: 'RICE', country: 'England', countryCode: 'ENG', position: 'CDM/CM', role: PlayerRole.defender, rating: 90, trait: 'Shield Midfielder', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'eng-john-stones', name: 'John Stones', shortName: 'STONES', country: 'England', countryCode: 'ENG', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Ball-Playing CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'eng-reece-james', name: 'Reece James', shortName: 'R. JAMES', country: 'England', countryCode: 'ENG', position: 'RB', role: PlayerRole.defender, rating: 88, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  // === PORTUGAL ===
  PlayerCard(id: 'por-joao-neves', name: 'João Neves', shortName: 'J. NEVES', country: 'Portugal', countryCode: 'POR', position: 'CM/CDM', role: PlayerRole.defender, rating: 88, trait: 'Press Breaker', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'por-nuno-mendes', name: 'Nuno Mendes', shortName: 'N. MENDES', country: 'Portugal', countryCode: 'POR', position: 'LB', role: PlayerRole.defender, rating: 90, trait: 'Attacking Fullback', tier: CardTier.gold, icon: Icons.swap_horiz),
  PlayerCard(id: 'por-ruben-dias', name: 'Rúben Dias', shortName: 'DIAS', country: 'Portugal', countryCode: 'POR', position: 'CB', role: PlayerRole.defender, rating: 90, trait: 'Leader CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'por-joao-cancelo', name: 'João Cancelo', shortName: 'CANCELO', country: 'Portugal', countryCode: 'POR', position: 'RB/LB', role: PlayerRole.defender, rating: 88, trait: 'Attacking Fullback', tier: CardTier.silver, icon: Icons.swap_horiz),
  // === SPAIN ===
  PlayerCard(id: 'esp-rodri', name: 'Rodri', shortName: 'RODRI', country: 'Spain', countryCode: 'ESP', position: 'CDM', role: PlayerRole.defender, rating: 92, trait: 'Tempo Controller', tier: CardTier.platinum, icon: Icons.security),
  PlayerCard(id: 'esp-dean-huijsen', name: 'Dean Huijsen', shortName: 'HUIJSEN', country: 'Spain', countryCode: 'ESP', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Ball-Playing CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'esp-pau-cubarsi', name: 'Pau Cubarsí', shortName: 'CUBARSI', country: 'Spain', countryCode: 'ESP', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Ball-Playing CB', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'esp-dani-carvajal', name: 'Dani Carvajal', shortName: 'CARVAJAL', country: 'Spain', countryCode: 'ESP', position: 'RB', role: PlayerRole.defender, rating: 88, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'esp-martin-zubimendi', name: 'Martin Zubimendi', shortName: 'ZUBIMENDI', country: 'Spain', countryCode: 'ESP', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Ball Winner', tier: CardTier.silver, icon: Icons.security),
  // === GERMANY ===
  PlayerCard(id: 'ger-joshua-kimmich', name: 'Joshua Kimmich', shortName: 'KIMMICH', country: 'Germany', countryCode: 'GER', position: 'CDM/RB', role: PlayerRole.defender, rating: 90, trait: 'Tempo Controller', tier: CardTier.gold, icon: Icons.security),
  PlayerCard(id: 'ger-antonio-rudiger', name: 'Antonio Rüdiger', shortName: 'RUDIGER', country: 'Germany', countryCode: 'GER', position: 'CB', role: PlayerRole.defender, rating: 90, trait: 'Aggressive Stopper', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'ger-leon-goretzka', name: 'Leon Goretzka', shortName: 'GORETZKA', country: 'Germany', countryCode: 'GER', position: 'CM', role: PlayerRole.defender, rating: 88, trait: 'Box-to-Box Enforcer', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'ger-jonathan-tah', name: 'Jonathan Tah', shortName: 'TAH', country: 'Germany', countryCode: 'GER', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'ger-david-raum', name: 'David Raum', shortName: 'RAUM', country: 'Germany', countryCode: 'GER', position: 'LB', role: PlayerRole.defender, rating: 86, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === NETHERLANDS ===
  PlayerCard(id: 'ned-virgil-van-dijk', name: 'Virgil van Dijk', shortName: 'VAN DIJK', country: 'Netherlands', countryCode: 'NED', position: 'CB', role: PlayerRole.defender, rating: 92, trait: 'Leader CB', tier: CardTier.platinum, icon: Icons.shield),
  PlayerCard(id: 'ned-denzel-dumfries', name: 'Denzel Dumfries', shortName: 'DUMFRIES', country: 'Netherlands', countryCode: 'NED', position: 'RB/RWB', role: PlayerRole.defender, rating: 88, trait: 'Power Fullback', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'ned-micky-van-de-ven', name: 'Micky van de Ven', shortName: 'VAN DE VEN', country: 'Netherlands', countryCode: 'NED', position: 'CB/LB', role: PlayerRole.defender, rating: 88, trait: 'Recovery Defender', tier: CardTier.silver, icon: Icons.shield),
  // === BELGIUM ===
  PlayerCard(id: 'bel-amadou-onana', name: 'Amadou Onana', shortName: 'ONANA', country: 'Belgium', countryCode: 'BEL', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'bel-timothy-castagne', name: 'Timothy Castagne', shortName: 'CASTAGNE', country: 'Belgium', countryCode: 'BEL', position: 'RB/LB', role: PlayerRole.defender, rating: 86, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'bel-arthur-theate', name: 'Arthur Theate', shortName: 'THEATE', country: 'Belgium', countryCode: 'BEL', position: 'CB/LB', role: PlayerRole.defender, rating: 86, trait: 'Flexible Defender', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'bel-axel-witsel', name: 'Axel Witsel', shortName: 'WITSEL', country: 'Belgium', countryCode: 'BEL', position: 'CDM/CB', role: PlayerRole.defender, rating: 86, trait: 'Veteran Shield', tier: CardTier.bronze, icon: Icons.security),
  // === CROATIA ===
  PlayerCard(id: 'cro-josko-gvardiol', name: 'Joško Gvardiol', shortName: 'GVARDIOL', country: 'Croatia', countryCode: 'CRO', position: 'CB/LB', role: PlayerRole.defender, rating: 90, trait: 'Ball-Playing CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'cro-marcelo-brozovic', name: 'Marcelo Brozović', shortName: 'BROZOVIC', country: 'Croatia', countryCode: 'CRO', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'cro-josip-stanisic', name: 'Josip Stanišić', shortName: 'STANISIC', country: 'Croatia', countryCode: 'CRO', position: 'RB/CB', role: PlayerRole.defender, rating: 88, trait: 'Flexible Defender', tier: CardTier.silver, icon: Icons.swap_horiz),
  // === URUGUAY ===
  PlayerCard(id: 'uru-ronald-araujo', name: 'Ronald Araújo', shortName: 'ARAUJO', country: 'Uruguay', countryCode: 'URU', position: 'CB/RB', role: PlayerRole.defender, rating: 90, trait: 'Recovery Defender', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'uru-jose-maria-gimenez', name: 'José María Giménez', shortName: 'GIMENEZ', country: 'Uruguay', countryCode: 'URU', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aggressive Stopper', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'uru-manuel-ugarte', name: 'Manuel Ugarte', shortName: 'UGARTE', country: 'Uruguay', countryCode: 'URU', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Ball Winner', tier: CardTier.silver, icon: Icons.security),
  // === COLOMBIA ===
  PlayerCard(id: 'col-jefferson-lerma', name: 'Jefferson Lerma', shortName: 'LERMA', country: 'Colombia', countryCode: 'COL', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'col-daniel-munoz', name: 'Daniel Muñoz', shortName: 'D. MUNOZ', country: 'Colombia', countryCode: 'COL', position: 'RB', role: PlayerRole.defender, rating: 88, trait: 'Attacking Fullback', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'col-davinson-sanchez', name: 'Davinson Sánchez', shortName: 'DAVINSON', country: 'Colombia', countryCode: 'COL', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  // === USA ===
  PlayerCard(id: 'usa-tyler-adams', name: 'Tyler Adams', shortName: 'ADAMS', country: 'USA', countryCode: 'USA', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Ball Winner', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'usa-antonee-robinson', name: 'Antonee Robinson', shortName: 'A. ROBINSON', country: 'USA', countryCode: 'USA', position: 'LB', role: PlayerRole.defender, rating: 88, trait: 'Overlap Runner', tier: CardTier.silver, icon: Icons.swap_horiz),
  PlayerCard(id: 'usa-chris-richards', name: 'Chris Richards', shortName: 'RICHARDS', country: 'USA', countryCode: 'USA', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Ball-Playing CB', tier: CardTier.bronze, icon: Icons.shield),
  // === MEXICO ===
  PlayerCard(id: 'mex-edson-alvarez', name: 'Edson Álvarez', shortName: 'EDSON', country: 'Mexico', countryCode: 'MEX', position: 'CDM/CB', role: PlayerRole.defender, rating: 88, trait: 'Shield Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'mex-johan-vasquez', name: 'Johan Vásquez', shortName: 'VASQUEZ', country: 'Mexico', countryCode: 'MEX', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Ball-Playing CB', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'mex-cesar-montes', name: 'César Montes', shortName: 'MONTES', country: 'Mexico', countryCode: 'MEX', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Aerial Defender', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'mex-jorge-sanchez', name: 'Jorge Sánchez', shortName: 'J. SANCHEZ', country: 'Mexico', countryCode: 'MEX', position: 'RB', role: PlayerRole.defender, rating: 86, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'mex-jesus-gallardo', name: 'Jesús Gallardo', shortName: 'GALLARDO', country: 'Mexico', countryCode: 'MEX', position: 'LB', role: PlayerRole.defender, rating: 86, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === CANADA ===
  PlayerCard(id: 'can-alphonso-davies', name: 'Alphonso Davies', shortName: 'DAVIES', country: 'Canada', countryCode: 'CAN', position: 'LB/LW', role: PlayerRole.defender, rating: 90, trait: 'Explosive Fullback', tier: CardTier.gold, icon: Icons.swap_horiz),
  PlayerCard(id: 'can-stephen-eustaquio', name: 'Stephen Eustáquio', shortName: 'EUSTAQUIO', country: 'Canada', countryCode: 'CAN', position: 'CM/CDM', role: PlayerRole.defender, rating: 88, trait: 'Tempo Controller', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'can-alistair-johnston', name: 'Alistair Johnston', shortName: 'JOHNSTON', country: 'Canada', countryCode: 'CAN', position: 'RB', role: PlayerRole.defender, rating: 86, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'can-moise-bombito', name: 'Moïse Bombito', shortName: 'BOMBITO', country: 'Canada', countryCode: 'CAN', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Recovery Defender', tier: CardTier.bronze, icon: Icons.shield),
  PlayerCard(id: 'can-derek-cornelius', name: 'Derek Cornelius', shortName: 'CORNELIUS', country: 'Canada', countryCode: 'CAN', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Aerial Defender', tier: CardTier.bronze, icon: Icons.shield),
  // === JAPAN ===
  PlayerCard(id: 'jpn-wataru-endo', name: 'Wataru Endo', shortName: 'ENDO', country: 'Japan', countryCode: 'JPN', position: 'CDM', role: PlayerRole.defender, rating: 88, trait: 'Captain Shield', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'jpn-takehiro-tomiyasu', name: 'Takehiro Tomiyasu', shortName: 'TOMIYASU', country: 'Japan', countryCode: 'JPN', position: 'CB/RB', role: PlayerRole.defender, rating: 88, trait: 'Flexible Defender', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'jpn-ko-itakura', name: 'Ko Itakura', shortName: 'ITAKURA', country: 'Japan', countryCode: 'JPN', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Ball-Playing CB', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'jpn-hidemasa-morita', name: 'Hidemasa Morita', shortName: 'MORITA', country: 'Japan', countryCode: 'JPN', position: 'CM', role: PlayerRole.defender, rating: 86, trait: 'Tempo Controller', tier: CardTier.bronze, icon: Icons.security),
  // === SOUTH KOREA ===
  PlayerCard(id: 'kor-kim-min-jae', name: 'Kim Min-jae', shortName: 'KIM MJ', country: 'South Korea', countryCode: 'KOR', position: 'CB', role: PlayerRole.defender, rating: 90, trait: 'Leader CB', tier: CardTier.gold, icon: Icons.shield),
  PlayerCard(id: 'kor-paik-seung-ho', name: 'Paik Seung-ho', shortName: 'PAIK', country: 'South Korea', countryCode: 'KOR', position: 'CM/CDM', role: PlayerRole.defender, rating: 86, trait: 'Ball Winner', tier: CardTier.bronze, icon: Icons.security),
  PlayerCard(id: 'kor-seol-young-woo', name: 'Seol Young-woo', shortName: 'SEOL', country: 'South Korea', countryCode: 'KOR', position: 'RB/LB', role: PlayerRole.defender, rating: 86, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  // === AUSTRALIA ===
  PlayerCard(id: 'aus-harry-souttar', name: 'Harry Souttar', shortName: 'SOUTTAR', country: 'Australia', countryCode: 'AUS', position: 'CB', role: PlayerRole.defender, rating: 88, trait: 'Aerial Defender', tier: CardTier.silver, icon: Icons.shield),
  PlayerCard(id: 'aus-jackson-irvine', name: 'Jackson Irvine', shortName: 'IRVINE', country: 'Australia', countryCode: 'AUS', position: 'CM', role: PlayerRole.defender, rating: 88, trait: 'Engine Midfielder', tier: CardTier.silver, icon: Icons.security),
  PlayerCard(id: 'aus-aziz-behich', name: 'Aziz Behich', shortName: 'BEHICH', country: 'Australia', countryCode: 'AUS', position: 'LB/LWB', role: PlayerRole.defender, rating: 86, trait: 'Wide Defender', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'aus-lewis-miller', name: 'Lewis Miller', shortName: 'MILLER', country: 'Australia', countryCode: 'AUS', position: 'RB/RWB', role: PlayerRole.defender, rating: 86, trait: 'Overlap Runner', tier: CardTier.bronze, icon: Icons.swap_horiz),
  PlayerCard(id: 'aus-alessandro-circati', name: 'Alessandro Circati', shortName: 'CIRCATI', country: 'Australia', countryCode: 'AUS', position: 'CB', role: PlayerRole.defender, rating: 86, trait: 'Recovery Defender', tier: CardTier.bronze, icon: Icons.shield),
];

const goalkeepers = [
  PlayerCard(id: 'arg-emiliano-martinez', name: 'Emiliano Martínez', shortName: 'EMI', country: 'Argentina', countryCode: 'ARG', position: 'GK', role: PlayerRole.goalkeeper, rating: 90, trait: 'Penalty Wall', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'bra-alisson-becker', name: 'Alisson Becker', shortName: 'ALISSON', country: 'Brazil', countryCode: 'BRA', position: 'GK', role: PlayerRole.goalkeeper, rating: 90, trait: 'Sweeper Keeper', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'bra-ederson-moraes', name: 'Ederson Moraes', shortName: 'EDERSON', country: 'Brazil', countryCode: 'BRA', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Sweeper Keeper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'fra-mike-maignan', name: 'Mike Maignan', shortName: 'MAIGNAN', country: 'France', countryCode: 'FRA', position: 'GK', role: PlayerRole.goalkeeper, rating: 90, trait: 'Shot Stopper', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'eng-jordan-pickford', name: 'Jordan Pickford', shortName: 'PICKFORD', country: 'England', countryCode: 'ENG', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Shot Stopper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'por-diogo-costa', name: 'Diogo Costa', shortName: 'D. COSTA', country: 'Portugal', countryCode: 'POR', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Shot Stopper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'esp-unai-simon', name: 'Unai Simón', shortName: 'SIMON', country: 'Spain', countryCode: 'ESP', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Shot Stopper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'ger-oliver-baumann', name: 'Oliver Baumann', shortName: 'BAUMANN', country: 'Germany', countryCode: 'GER', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'ned-bart-verbruggen', name: 'Bart Verbruggen', shortName: 'VERBRUGGEN', country: 'Netherlands', countryCode: 'NED', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'bel-thibaut-courtois', name: 'Thibaut Courtois', shortName: 'COURTOIS', country: 'Belgium', countryCode: 'BEL', position: 'GK', role: PlayerRole.goalkeeper, rating: 90, trait: 'Penalty Wall', tier: CardTier.gold, icon: Icons.pan_tool),
  PlayerCard(id: 'cro-dominik-livakovic', name: 'Dominik Livaković', shortName: 'LIVAKOVIC', country: 'Croatia', countryCode: 'CRO', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Penalty Keeper', tier: CardTier.silver, icon: Icons.pan_tool),
  PlayerCard(id: 'uru-sergio-rochet', name: 'Sergio Rochet', shortName: 'ROCHET', country: 'Uruguay', countryCode: 'URU', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'col-camilo-vargas', name: 'Camilo Vargas', shortName: 'VARGAS', country: 'Colombia', countryCode: 'COL', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'usa-matt-turner', name: 'Matt Turner', shortName: 'TURNER', country: 'USA', countryCode: 'USA', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'mex-luis-malagon', name: 'Luis Malagón', shortName: 'MALAGON', country: 'Mexico', countryCode: 'MEX', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'can-dayne-st-clair', name: 'Dayne St. Clair', shortName: 'ST. CLAIR', country: 'Canada', countryCode: 'CAN', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'jpn-zion-suzuki', name: 'Zion Suzuki', shortName: 'ZION', country: 'Japan', countryCode: 'JPN', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Reflex Keeper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'kor-kim-seung-gyu', name: 'Kim Seung-gyu', shortName: 'KIM SG', country: 'South Korea', countryCode: 'KOR', position: 'GK', role: PlayerRole.goalkeeper, rating: 86, trait: 'Shot Stopper', tier: CardTier.bronze, icon: Icons.pan_tool),
  PlayerCard(id: 'aus-mathew-ryan', name: 'Mathew Ryan', shortName: 'RYAN', country: 'Australia', countryCode: 'AUS', position: 'GK', role: PlayerRole.goalkeeper, rating: 88, trait: 'Veteran Keeper', tier: CardTier.silver, icon: Icons.pan_tool),
];

const allPlayerCards = [...attackers, ...defenders, ...goalkeepers];

const actionCards = [
  ActionCard(
    id: 'act1',
    title: 'Through Ball',
    category: ActionCategory.attack,
    effect: '+15 Attack Power',
    power: 15,
    risky: false,
    icon: Icons.trending_up,
  ),
  ActionCard(
    id: 'act2',
    title: 'Power Shot',
    category: ActionCategory.attack,
    effect: '+20 Attack, -5 Accuracy',
    power: 20,
    risky: false,
    icon: Icons.sports_soccer,
  ),
  ActionCard(
    id: 'act3',
    title: 'Skill Move',
    category: ActionCategory.attack,
    effect: '+12 Attack, Bypass Trait',
    power: 12,
    risky: false,
    icon: Icons.auto_awesome,
  ),
  ActionCard(
    id: 'act4',
    title: 'Cut Inside',
    category: ActionCategory.attack,
    effect: '+10 Attack, +5 Scenario',
    power: 10,
    risky: false,
    icon: Icons.turn_right,
  ),
  ActionCard(
    id: 'act5',
    title: 'Long Shot',
    category: ActionCategory.attack,
    effect: '+25 Attack, High Risk',
    power: 25,
    risky: true,
    icon: Icons.my_location,
  ),
  ActionCard(
    id: 'act6',
    title: 'Quick Break',
    category: ActionCategory.attack,
    effect: '+18 Counter Bonus',
    power: 18,
    risky: false,
    icon: Icons.flash_on,
  ),
  ActionCard(
    id: 'act7',
    title: 'Slide Tackle',
    category: ActionCategory.defense,
    effect: '+15 Defense Power',
    power: 15,
    risky: false,
    icon: Icons.swipe_down,
  ),
  ActionCard(
    id: 'act8',
    title: 'Press High',
    category: ActionCategory.defense,
    effect: '+12 Defense, Disrupt',
    power: 12,
    risky: false,
    icon: Icons.compress,
  ),
  ActionCard(
    id: 'act9',
    title: 'Block Lane',
    category: ActionCategory.defense,
    effect: '+10 Defense, +5 Position',
    power: 10,
    risky: false,
    icon: Icons.block,
  ),
  ActionCard(
    id: 'act10',
    title: 'Tight Marking',
    category: ActionCategory.defense,
    effect: '+14 Defense Power',
    power: 14,
    risky: false,
    icon: Icons.person_pin_circle,
  ),
  ActionCard(
    id: 'act11',
    title: 'Intercept',
    category: ActionCategory.defense,
    effect: '+18 Defense, Read Play',
    power: 18,
    risky: false,
    icon: Icons.call_split,
  ),
  ActionCard(
    id: 'act12',
    title: 'Last-Ditch Tackle',
    category: ActionCategory.defense,
    effect: '+22 Defense, Foul Risk',
    power: 22,
    risky: true,
    icon: Icons.warning,
  ),
  ActionCard(
    id: 'act13',
    title: 'All In',
    category: ActionCategory.special,
    effect: '+30 Power, Red Card Risk',
    power: 30,
    risky: true,
    icon: Icons.local_fire_department,
  ),
  ActionCard(
    id: 'act14',
    title: 'Tactical Foul',
    category: ActionCategory.special,
    effect: 'Stop Play, Yellow Risk',
    power: 8,
    risky: true,
    icon: Icons.flag,
  ),
  ActionCard(
    id: 'act15',
    title: 'Mind Game',
    category: ActionCategory.special,
    effect: '-10 Opponent Power',
    power: 10,
    risky: false,
    icon: Icons.psychology,
  ),
  ActionCard(
    id: 'act16',
    title: 'Fast Recovery',
    category: ActionCategory.special,
    effect: '+8 All Stats',
    power: 8,
    risky: false,
    icon: Icons.healing,
  ),
];

const commonUseCases = [
  AppInfoItem(
    title: 'Quick Local Duel',
    body:
        'Jump into a four-round head-to-head with one prepared deck and instant rematches.',
    icon: Icons.sports_soccer,
    accent: Cyber.cyan,
  ),
  AppInfoItem(
    title: 'Deck Tuning',
    body:
        'Swap attackers, defenders, and action cards to test new balance before kickoff.',
    icon: Icons.tune,
    accent: Cyber.lime,
  ),
  AppInfoItem(
    title: 'Scenario Practice',
    body:
        'Learn how round bonuses change the right play in attack and defense situations.',
    icon: Icons.radar,
    accent: Cyber.amber,
  ),
];

const coreFeatures = [
  AppInfoItem(
    title: '5-A-Side Builder',
    body:
        'Two attackers, two defenders, and a six-card action strip laid out like the web pitch.',
    icon: Icons.view_quilt,
    accent: Cyber.cyan,
  ),
  AppInfoItem(
    title: 'Scenario Rounds',
    body:
        'Every round reveals a tactical modifier before you lock your player and action card.',
    icon: Icons.auto_awesome_motion,
    accent: Cyber.violet,
  ),
  AppInfoItem(
    title: 'Penalty Finish',
    body:
        'Tied matches roll into a shootout with sudden death until one side finally breaks through.',
    icon: Icons.emoji_events,
    accent: Cyber.red,
  ),
  AppInfoItem(
    title: 'Daily Reveal',
    body:
        'Open a random featured player card for a quick showcase moment from the home screen.',
    icon: Icons.style,
    accent: Cyber.amber,
  ),
];

const scenarios = [
  ScenarioCard(
    id: 'sc1',
    title: 'Counter Attack',
    description: 'Quick transition, spaces open up',
    attackBonus: 8,
    defenseBonus: 3,
    icon: Icons.run_circle,
  ),
  ScenarioCard(
    id: 'sc2',
    title: '1v1 Final Third',
    description: 'Face to face with the last defender',
    attackBonus: 5,
    defenseBonus: 5,
    icon: Icons.adjust,
  ),
  ScenarioCard(
    id: 'sc3',
    title: 'Set Piece Chance',
    description: 'Free kick from a dangerous position',
    attackBonus: 6,
    defenseBonus: 6,
    icon: Icons.sports,
  ),
  ScenarioCard(
    id: 'sc4',
    title: 'Last Minute Pressure',
    description: 'Everything on the line, final push',
    attackBonus: 10,
    defenseBonus: 2,
    icon: Icons.timer,
  ),
  ScenarioCard(
    id: 'sc5',
    title: 'Box Defense',
    description: 'Packed defense, tight spaces',
    attackBonus: 2,
    defenseBonus: 10,
    icon: Icons.grid_view,
  ),
  ScenarioCard(
    id: 'sc6',
    title: 'Wide Break',
    description: 'Overlapping run down the flank',
    attackBonus: 7,
    defenseBonus: 4,
    icon: Icons.open_in_full,
  ),
  ScenarioCard(
    id: 'sc7',
    title: 'Penalty Box Chaos',
    description: 'Scramble in the box, anything goes',
    attackBonus: 8,
    defenseBonus: 8,
    icon: Icons.shuffle,
  ),
];

class SecureGameStorage {
  SecureGameStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deckKey = 'pd_deck_slots_v1';
  static const _tutorialKey = 'pd_tutorial_seen_v1';
  static const _ownedCardsKey = 'pd_owned_cards_v1';
  static const _historyKey = 'pd_match_history_v1';
  static const _starterPackClaimedKey = 'pd_starter_pack_claimed_v1';

  final FlutterSecureStorage _storage;

  Future<List<StoredDeckSlot>> loadDecks() async {
    try {
      final raw = await _storage.read(key: _deckKey);
      if (raw == null || raw.isEmpty) return defaultDeckSlots;
      final data = jsonDecode(raw) as List;
      return data.map((item) => StoredDeckSlot.fromJson(item)).toList();
    } catch (_) {
      return defaultDeckSlots;
    }
  }

  Future<void> saveDecks(List<StoredDeckSlot> decks) async {
    await _storage.write(
      key: _deckKey,
      value: jsonEncode(decks.map((deck) => deck.toJson()).toList()),
    );
  }

  Future<Set<String>> loadTutorialSeen() async {
    try {
      final raw = await _storage.read(key: _tutorialKey);
      if (raw == null || raw.isEmpty) return {};
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTutorialSeen(Set<String> seen) async {
    await _storage.write(key: _tutorialKey, value: jsonEncode(seen.toList()));
  }

  Future<void> resetTutorial() => _storage.delete(key: _tutorialKey);

  Future<List<String>> loadOwnedCards() async {
    try {
      final raw = await _storage.read(key: _ownedCardsKey);
      if (raw == null || raw.isEmpty) return const [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveOwnedCards(List<String> cardIds) async {
    await _storage.write(key: _ownedCardsKey, value: jsonEncode(cardIds));
  }

  Future<bool> loadStarterPackClaimed() async {
    try {
      final raw = await _storage.read(key: _starterPackClaimedKey);
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> saveStarterPackClaimed() async {
    await _storage.write(key: _starterPackClaimedKey, value: 'true');
  }

  Future<List<MatchHistoryEntry>> loadMatchHistory() async {
    try {
      final raw = await _storage.read(key: _historyKey);
      if (raw == null || raw.isEmpty) return const [];
      final data = jsonDecode(raw) as List;
      return data
          .map(
            (item) =>
                MatchHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveMatchHistory(List<MatchHistoryEntry> history) async {
    await _storage.write(
      key: _historyKey,
      value: jsonEncode(history.map((entry) => entry.toJson()).toList()),
    );
  }
}

const defaultDeckSlots = [
  StoredDeckSlot(
    id: 'slot-1',
    name: 'World Icons',
    attackers: ['fra-kylian-mbappe', 'eng-harry-kane'],
    defenders: ['ned-virgil-van-dijk', 'esp-rodri'],
    actions: ['act1', 'act2', 'act6', 'act7', 'act8', 'act15'],
  ),
];

const tutorialKeys = [
  'home',
  'deck-builder',
  'toss',
  'scenario',
  'play',
  'round-result',
  'match-end',
  'penalty',
  'final',
];

class TutorialStepData {
  const TutorialStepData({required this.title, required this.body});

  final String title;
  final String body;
}

const homeTutorialSteps = [
  TutorialStepData(
    title: 'Welcome, Operator',
    body:
        'PITCH/DUEL is a 4-round card duel. Each round, play one player card and one action card. Stats, scenario, and luck decide the outcome.',
  ),
  TutorialStepData(
    title: "You're pre-loaded",
    body:
        'Your default loadout is ready: 2 attackers, 2 defenders, 6 actions. Play now or customize in Deck Builder.',
  ),
  TutorialStepData(
    title: 'How a match flows',
    body:
        '1. Coin toss (round 1 only)\n2. Scenario reveals + role assigned\n3. Pick a player & action card\n4. See the outcome -> next round\n\nTap PLAY MATCH when ready.',
  ),
];

const deckTutorialSteps = [
  TutorialStepData(
    title: 'Build a 5-a-side',
    body: 'Shape the pitch with 2 ATK, 2 DEF, and 6 actions.',
  ),
  TutorialStepData(
    title: 'Edit, Save, Play',
    body:
        'Tap Edit to change the deck, save it, then play when the squad is ready.',
  ),
];

const tossTutorialSteps = [
  TutorialStepData(
    title: 'Coin Toss',
    body:
        'Pick HEADS or TAILS. The winner chooses attack or defense for round 1.',
  ),
  TutorialStepData(
    title: 'Roles Alternate',
    body:
        'This is the only toss. After round 1, roles flip automatically each round.',
  ),
];

const scenarioTutorialSteps = [
  TutorialStepData(
    title: 'Scenario Briefing',
    body:
        'Each round has a football situation: counter attack, set piece, box defense, and more.',
  ),
  TutorialStepData(
    title: 'Bonus Stats',
    body:
        'ATK +X and DEF +X are added this round. Bigger attack bonus favors the attacker.',
  ),
  TutorialStepData(
    title: 'Your Role',
    body: 'The banner shows your role. Pick cards around attack or defense.',
  ),
];

const playTutorialSteps = [
  TutorialStepData(
    title: 'Pick Your Player',
    body:
        'Choose one player. OVR is base power. Used players are locked for the match.',
  ),
  TutorialStepData(
    title: 'Pick an Action',
    body:
        'Pick one action. Options match your role: ATK when attacking, DEF when defending, SPC anytime.',
  ),
  TutorialStepData(
    title: 'Risky Cards',
    body:
        'Warning cards boost power but can cause fouls or red cards. Red cards remove a player.',
  ),
  TutorialStepData(
    title: 'Read the Preview',
    body:
        'EST shows rating + action + scenario bonus. CPU power is hidden, and luck still matters.',
  ),
];

const resultTutorialSteps = [
  TutorialStepData(
    title: 'Round Resolved',
    body: 'The label shows: GOAL, SAVED, MISSED, FOUL, or RED CARD.',
  ),
  TutorialStepData(
    title: 'Used Cards',
    body:
        'Round cards appear side-by-side. Used players are marked USED and cannot replay.',
  ),
  TutorialStepData(
    title: 'Next Round',
    body: 'Tap NEXT ROUND. Roles switch each round, so attack becomes defense.',
  ),
];

const matchEndTutorialSteps = [
  TutorialStepData(
    title: 'Full Time',
    body: 'After 4 rounds, the banner shows VICTORY, DEFEAT, or DEADLOCK.',
  ),
  TutorialStepData(
    title: 'Round Log',
    body: 'The log recaps each scenario and outcome.',
  ),
  TutorialStepData(
    title: 'Tied? Penalties!',
    body: 'A draw goes to a penalty shootout.',
  ),
];

const penaltyTutorialSteps = [
  TutorialStepData(
    title: 'Sudden Death',
    body:
        'Tied match: penalty shootout. Kicks alternate until someone leads after equal attempts.',
  ),
  TutorialStepData(
    title: 'How It Works',
    body:
        'Tap TAKE KICK on your turn. CPU kicks auto-fire. Each kick has about a 65-75% score chance.',
  ),
];

const finalTutorialSteps = [
  TutorialStepData(
    title: 'Match Archive',
    body: 'Final scoreline, plus penalties if needed, appears here.',
  ),
  TutorialStepData(title: 'MVP', body: 'MVP goes to your goal scorer.'),
  TutorialStepData(
    title: 'What Next?',
    body: 'REMATCH uses the same deck. HOME exits. DECK opens squad tuning.',
  ),
];

class GameState {
  const GameState({
    required this.loading,
    required this.deckSlots,
    required this.activeDeckId,
    required this.deckAttackers,
    required this.deckDefenders,
    required this.deckActions,
    required this.ownedCardIds,
    required this.matchHistory,
    required this.tutorialSeen,
    required this.starterPackCards,
    required this.starterPackPending,
    required this.phase,
    required this.currentRound,
    required this.playerScore,
    required this.opponentScore,
    required this.playerAttacking,
    required this.tossChoice,
    required this.tossResult,
    required this.playerWonToss,
    required this.initialAttackingChoice,
    required this.currentScenario,
    required this.selectedPlayerCard,
    required this.selectedActionCard,
    required this.usedPlayerCards,
    required this.usedActionCards,
    required this.redCardedCards,
    required this.roundResults,
    required this.opponentAttackers,
    required this.opponentDefenders,
    required this.opponentActions,
    required this.opponentRedCarded,
    required this.penaltyKicks,
    required this.penaltyPlayerScore,
    required this.penaltyOpponentScore,
    required this.penaltyRound,
    required this.penaltyPhaseOver,
  });

  factory GameState.initial() => GameState(
    loading: true,
    deckSlots: defaultDeckSlots,
    activeDeckId: defaultDeckSlots.first.id,
    deckAttackers: cardsByIds(attackers, defaultDeckSlots.first.attackers),
    deckDefenders: cardsByIds(defenders, defaultDeckSlots.first.defenders),
    deckActions: actionCardsByIds(defaultDeckSlots.first.actions),
    ownedCardIds: const [],
    matchHistory: const [],
    tutorialSeen: const {},
    starterPackCards: const [],
    starterPackPending: false,
    phase: MatchPhase.idle,
    currentRound: 0,
    playerScore: 0,
    opponentScore: 0,
    playerAttacking: true,
    tossChoice: null,
    tossResult: null,
    playerWonToss: null,
    initialAttackingChoice: null,
    currentScenario: null,
    selectedPlayerCard: null,
    selectedActionCard: null,
    usedPlayerCards: const [],
    usedActionCards: const [],
    redCardedCards: const [],
    roundResults: const [],
    opponentAttackers: const [],
    opponentDefenders: const [],
    opponentActions: const [],
    opponentRedCarded: const [],
    penaltyKicks: const [],
    penaltyPlayerScore: 0,
    penaltyOpponentScore: 0,
    penaltyRound: 0,
    penaltyPhaseOver: false,
  );

  final bool loading;
  final List<StoredDeckSlot> deckSlots;
  final String activeDeckId;
  final List<PlayerCard> deckAttackers;
  final List<PlayerCard> deckDefenders;
  final List<ActionCard> deckActions;
  final List<String> ownedCardIds;
  final List<MatchHistoryEntry> matchHistory;
  final Set<String> tutorialSeen;
  final List<PlayerCard> starterPackCards;
  final bool starterPackPending;
  final MatchPhase phase;
  final int currentRound;
  final int playerScore;
  final int opponentScore;
  final bool playerAttacking;
  final String? tossChoice;
  final String? tossResult;
  final bool? playerWonToss;
  final bool? initialAttackingChoice;
  final ScenarioCard? currentScenario;
  final PlayerCard? selectedPlayerCard;
  final ActionCard? selectedActionCard;
  final List<String> usedPlayerCards;
  final List<String> usedActionCards;
  final List<String> redCardedCards;
  final List<RoundResult> roundResults;
  final List<PlayerCard> opponentAttackers;
  final List<PlayerCard> opponentDefenders;
  final List<ActionCard> opponentActions;
  final List<String> opponentRedCarded;
  final List<PenaltyKick> penaltyKicks;
  final int penaltyPlayerScore;
  final int penaltyOpponentScore;
  final int penaltyRound;
  final bool penaltyPhaseOver;

  bool get deckReady =>
      deckAttackers.length == 2 &&
      deckDefenders.length == 2 &&
      deckActions.length == 6;

  GameState copyWith({
    bool? loading,
    List<StoredDeckSlot>? deckSlots,
    String? activeDeckId,
    List<PlayerCard>? deckAttackers,
    List<PlayerCard>? deckDefenders,
    List<ActionCard>? deckActions,
    List<String>? ownedCardIds,
    List<MatchHistoryEntry>? matchHistory,
    Set<String>? tutorialSeen,
    List<PlayerCard>? starterPackCards,
    bool? starterPackPending,
    MatchPhase? phase,
    int? currentRound,
    int? playerScore,
    int? opponentScore,
    bool? playerAttacking,
    Object? tossChoice = _sentinel,
    Object? tossResult = _sentinel,
    Object? playerWonToss = _sentinel,
    Object? initialAttackingChoice = _sentinel,
    Object? currentScenario = _sentinel,
    Object? selectedPlayerCard = _sentinel,
    Object? selectedActionCard = _sentinel,
    List<String>? usedPlayerCards,
    List<String>? usedActionCards,
    List<String>? redCardedCards,
    List<RoundResult>? roundResults,
    List<PlayerCard>? opponentAttackers,
    List<PlayerCard>? opponentDefenders,
    List<ActionCard>? opponentActions,
    List<String>? opponentRedCarded,
    List<PenaltyKick>? penaltyKicks,
    int? penaltyPlayerScore,
    int? penaltyOpponentScore,
    int? penaltyRound,
    bool? penaltyPhaseOver,
  }) => GameState(
    loading: loading ?? this.loading,
    deckSlots: deckSlots ?? this.deckSlots,
    activeDeckId: activeDeckId ?? this.activeDeckId,
    deckAttackers: deckAttackers ?? this.deckAttackers,
    deckDefenders: deckDefenders ?? this.deckDefenders,
    deckActions: deckActions ?? this.deckActions,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    matchHistory: matchHistory ?? this.matchHistory,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    starterPackCards: starterPackCards ?? this.starterPackCards,
    starterPackPending: starterPackPending ?? this.starterPackPending,
    phase: phase ?? this.phase,
    currentRound: currentRound ?? this.currentRound,
    playerScore: playerScore ?? this.playerScore,
    opponentScore: opponentScore ?? this.opponentScore,
    playerAttacking: playerAttacking ?? this.playerAttacking,
    tossChoice: tossChoice == _sentinel
        ? this.tossChoice
        : tossChoice as String?,
    tossResult: tossResult == _sentinel
        ? this.tossResult
        : tossResult as String?,
    playerWonToss: playerWonToss == _sentinel
        ? this.playerWonToss
        : playerWonToss as bool?,
    initialAttackingChoice: initialAttackingChoice == _sentinel
        ? this.initialAttackingChoice
        : initialAttackingChoice as bool?,
    currentScenario: currentScenario == _sentinel
        ? this.currentScenario
        : currentScenario as ScenarioCard?,
    selectedPlayerCard: selectedPlayerCard == _sentinel
        ? this.selectedPlayerCard
        : selectedPlayerCard as PlayerCard?,
    selectedActionCard: selectedActionCard == _sentinel
        ? this.selectedActionCard
        : selectedActionCard as ActionCard?,
    usedPlayerCards: usedPlayerCards ?? this.usedPlayerCards,
    usedActionCards: usedActionCards ?? this.usedActionCards,
    redCardedCards: redCardedCards ?? this.redCardedCards,
    roundResults: roundResults ?? this.roundResults,
    opponentAttackers: opponentAttackers ?? this.opponentAttackers,
    opponentDefenders: opponentDefenders ?? this.opponentDefenders,
    opponentActions: opponentActions ?? this.opponentActions,
    opponentRedCarded: opponentRedCarded ?? this.opponentRedCarded,
    penaltyKicks: penaltyKicks ?? this.penaltyKicks,
    penaltyPlayerScore: penaltyPlayerScore ?? this.penaltyPlayerScore,
    penaltyOpponentScore: penaltyOpponentScore ?? this.penaltyOpponentScore,
    penaltyRound: penaltyRound ?? this.penaltyRound,
    penaltyPhaseOver: penaltyPhaseOver ?? this.penaltyPhaseOver,
  );
}

const _sentinel = Object();

sealed class GameEvent {}

class GameLoaded extends GameEvent {}

class DeckSaved extends GameEvent {
  DeckSaved(this.slot);
  final StoredDeckSlot slot;
}

class DeckApplied extends GameEvent {
  DeckApplied(this.slotId);
  final String slotId;
}

class DeckCreated extends GameEvent {}

class TutorialReset extends GameEvent {}

class TutorialSeenMarked extends GameEvent {
  TutorialSeenMarked(this.keyName);
  final String keyName;
}

class TutorialsSkippedAll extends GameEvent {}

class OwnedCardAdded extends GameEvent {
  OwnedCardAdded(this.cardId);
  final String cardId;
}

class StarterPackSeen extends GameEvent {}

class MatchReset extends GameEvent {}

class MatchStarted extends GameEvent {}

class TossChoiceChanged extends GameEvent {
  TossChoiceChanged(this.choice);
  final String choice;
}

class TossResolved extends GameEvent {}

class RoleChosen extends GameEvent {
  RoleChosen(this.playerAttacking);
  final bool playerAttacking;
}

class ScenarioShown extends GameEvent {}

class PlayStarted extends GameEvent {}

class PlayerSelected extends GameEvent {
  PlayerSelected(this.card);
  final PlayerCard card;
}

class ActionSelected extends GameEvent {
  ActionSelected(this.card);
  final ActionCard card;
}

class MovePlayed extends GameEvent {}

class RoundAdvanced extends GameEvent {}

class PenaltyStarted extends GameEvent {}

class PenaltyTaken extends GameEvent {}

class MatchFinished extends GameEvent {}

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc(this._storage) : super(GameState.initial()) {
    on<GameLoaded>(_onLoaded);
    on<DeckSaved>(_onDeckSaved);
    on<DeckApplied>(_onDeckApplied);
    on<DeckCreated>(_onDeckCreated);
    on<TutorialReset>(_onTutorialReset);
    on<TutorialSeenMarked>(_onTutorialSeenMarked);
    on<TutorialsSkippedAll>(_onTutorialsSkippedAll);
    on<OwnedCardAdded>(_onOwnedCardAdded);
    on<StarterPackSeen>(
      (_, emit) => emit(
        state.copyWith(starterPackPending: false, starterPackCards: const []),
      ),
    );
    on<MatchReset>((_, emit) => emit(_resetMatch(state)));
    on<MatchStarted>(_onMatchStarted);
    on<TossChoiceChanged>(
      (event, emit) => emit(state.copyWith(tossChoice: event.choice)),
    );
    on<TossResolved>(_onTossResolved);
    on<RoleChosen>(_onRoleChosen);
    on<ScenarioShown>(_onScenarioShown);
    on<PlayStarted>((_, emit) => emit(state.copyWith(phase: MatchPhase.play)));
    on<PlayerSelected>(
      (event, emit) => emit(state.copyWith(selectedPlayerCard: event.card)),
    );
    on<ActionSelected>(
      (event, emit) => emit(state.copyWith(selectedActionCard: event.card)),
    );
    on<MovePlayed>(_onMovePlayed);
    on<RoundAdvanced>(_onRoundAdvanced);
    on<PenaltyStarted>(
      (_, emit) => emit(
        state.copyWith(
          phase: MatchPhase.penalty,
          penaltyKicks: [],
          penaltyPlayerScore: 0,
          penaltyOpponentScore: 0,
          penaltyRound: 0,
          penaltyPhaseOver: false,
        ),
      ),
    );
    on<PenaltyTaken>(_onPenaltyTaken);
    on<MatchFinished>(_onMatchFinished);
  }

  final SecureGameStorage _storage;
  final Random _random = Random();

  Future<void> _onLoaded(GameLoaded event, Emitter<GameState> emit) async {
    try {
      developer.log('GameLoaded: Starting initialization');

      final slots = await _storage.loadDecks().timeout(
        const Duration(seconds: 2),
        onTimeout: () => defaultDeckSlots,
      );
      developer.log('GameLoaded: Loaded decks');

      final safeSlots = slots.isEmpty
          ? defaultDeckSlots
          : slots.map(_hydratedSlot).toList();
      final active = safeSlots.first;

      final seen = await _storage.loadTutorialSeen().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String>{},
      );
      developer.log('GameLoaded: Loaded tutorial seen');

      final owned = await _storage.loadOwnedCards().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String>[],
      );
      developer.log('GameLoaded: Loaded owned cards');

      final history = await _storage.loadMatchHistory().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <MatchHistoryEntry>[],
      );
      developer.log('GameLoaded: Loaded history');

      final starterPackClaimed = await _storage.loadStarterPackClaimed().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      developer.log('GameLoaded: Loaded starter pack status: $starterPackClaimed');

      var ownedCards = owned;
      var starterPackCards = const <PlayerCard>[];
      var starterPackPending = false;

      if (!starterPackClaimed) {
        developer.log('GameLoaded: Building starter pack');
        starterPackCards = _buildStarterPack();
        ownedCards = {
          ...ownedCards,
          ...starterPackCards.map((card) => card.id),
        }.toList();
        starterPackPending = true;
        await _storage.saveOwnedCards(ownedCards);
        await _storage.saveStarterPackClaimed();
        developer.log('GameLoaded: Starter pack built and saved');
      }

      developer.log('GameLoaded: Emitting state');
      emit(
        state.copyWith(
          loading: false,
          deckSlots: safeSlots,
          activeDeckId: active.id,
          deckAttackers: cardsByIds(attackers, active.attackers),
          deckDefenders: cardsByIds(defenders, active.defenders),
          deckActions: actionCardsByIds(active.actions),
          ownedCardIds: ownedCards,
          matchHistory: history,
          tutorialSeen: seen,
          starterPackCards: starterPackCards,
          starterPackPending: starterPackPending,
        ),
      );
      developer.log('GameLoaded: Complete');
    } catch (e, st) {
      developer.log('GameLoaded ERROR: $e\n$st');
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> _onOwnedCardAdded(
    OwnedCardAdded event,
    Emitter<GameState> emit,
  ) async {
    final owned = {...state.ownedCardIds, event.cardId}.toList();
    emit(state.copyWith(ownedCardIds: owned));
    await _storage.saveOwnedCards(owned);
  }

  Future<void> _onDeckSaved(DeckSaved event, Emitter<GameState> emit) async {
    final cleaned = _hydratedSlot(event.slot);
    final slots = [
      for (final slot in state.deckSlots)
        if (slot.id == cleaned.id) cleaned else slot,
    ];
    await _storage.saveDecks(slots);
    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: cleaned.id,
        deckAttackers: cardsByIds(attackers, cleaned.attackers),
        deckDefenders: cardsByIds(defenders, cleaned.defenders),
        deckActions: actionCardsByIds(cleaned.actions),
      ),
    );
  }

  void _onDeckApplied(DeckApplied event, Emitter<GameState> emit) {
    final slot = state.deckSlots.firstWhere(
      (deck) => deck.id == event.slotId,
      orElse: () => state.deckSlots.first,
    );
    emit(
      state.copyWith(
        activeDeckId: slot.id,
        deckAttackers: cardsByIds(attackers, slot.attackers),
        deckDefenders: cardsByIds(defenders, slot.defenders),
        deckActions: actionCardsByIds(slot.actions),
      ),
    );
  }

  Future<void> _onDeckCreated(
    DeckCreated event,
    Emitter<GameState> emit,
  ) async {
    final slot = StoredDeckSlot(
      id: 'slot-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Squad ${state.deckSlots.length + 1}',
      attackers: const [],
      defenders: const [],
      actions: const [],
    );
    final slots = [...state.deckSlots, slot];
    await _storage.saveDecks(slots);
    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: slot.id,
        deckAttackers: const [],
        deckDefenders: const [],
        deckActions: const [],
      ),
    );
  }

  Future<void> _onTutorialReset(
    TutorialReset event,
    Emitter<GameState> emit,
  ) async {
    await _storage.resetTutorial();
    emit(state.copyWith(tutorialSeen: {}));
  }

  Future<void> _onTutorialSeenMarked(
    TutorialSeenMarked event,
    Emitter<GameState> emit,
  ) async {
    final seen = {...state.tutorialSeen, event.keyName};
    emit(state.copyWith(tutorialSeen: seen));
    await _storage.saveTutorialSeen(seen);
  }

  Future<void> _onTutorialsSkippedAll(
    TutorialsSkippedAll event,
    Emitter<GameState> emit,
  ) async {
    final seen = tutorialKeys.toSet();
    emit(state.copyWith(tutorialSeen: seen));
    await _storage.saveTutorialSeen(seen);
  }

  void _onMatchStarted(MatchStarted event, Emitter<GameState> emit) {
    final oppAttackers = [...attackers]..shuffle(_random);
    final oppDefenders = [...defenders]..shuffle(_random);
    final oppActions = [...actionCards]..shuffle(_random);
    emit(
      _resetMatch(state).copyWith(
        phase: MatchPhase.toss,
        currentRound: 1,
        opponentAttackers: oppAttackers.take(2).toList(),
        opponentDefenders: oppDefenders.take(2).toList(),
        opponentActions: oppActions.take(6).toList(),
      ),
    );
  }

  void _onTossResolved(TossResolved event, Emitter<GameState> emit) {
    if (state.tossChoice == null) return;
    final result = _random.nextBool() ? 'heads' : 'tails';
    emit(
      state.copyWith(
        tossResult: result,
        playerWonToss: result == state.tossChoice,
        phase: MatchPhase.tossResult,
      ),
    );
  }

  void _onRoleChosen(RoleChosen event, Emitter<GameState> emit) {
    emit(
      state.copyWith(
        playerAttacking: event.playerAttacking,
        initialAttackingChoice: event.playerAttacking,
        phase: MatchPhase.scenario,
        currentScenario: null,
      ),
    );
  }

  void _onScenarioShown(ScenarioShown event, Emitter<GameState> emit) {
    final used = state.roundResults.map((round) => round.scenario.id).toSet();
    final available = scenarios
        .where((scenario) => !used.contains(scenario.id))
        .toList();
    final pool = available.isEmpty ? scenarios : available;
    emit(
      state.copyWith(
        currentScenario: pool[_random.nextInt(pool.length)],
        phase: MatchPhase.scenario,
      ),
    );
  }

  void _onMovePlayed(MovePlayed event, Emitter<GameState> emit) {
    final playerCard = state.selectedPlayerCard;
    final actionCard = state.selectedActionCard;
    final scenario = state.currentScenario;
    if (playerCard == null || actionCard == null || scenario == null) return;

    final oppPlayers = state.playerAttacking
        ? state.opponentDefenders
              .where((card) => !state.opponentRedCarded.contains(card.id))
              .toList()
        : state.opponentAttackers
              .where((card) => !state.opponentRedCarded.contains(card.id))
              .toList();
    final fallback = state.playerAttacking
        ? state.opponentDefenders.first
        : state.opponentAttackers.first;
    final oppPlayer = oppPlayers.isEmpty
        ? fallback
        : oppPlayers[_random.nextInt(oppPlayers.length)];
    final oppAction =
        state.opponentActions[_random.nextInt(state.opponentActions.length)];

    final attackerCard = state.playerAttacking ? playerCard : oppPlayer;
    final defenderCard = state.playerAttacking ? oppPlayer : playerCard;
    final attackAction = state.playerAttacking ? actionCard : oppAction;
    final defenseAction = state.playerAttacking ? oppAction : actionCard;
    final attackPower =
        attackerCard.rating +
        attackAction.power +
        scenario.attackBonus +
        _random.nextDouble() * 20;
    final defensePower =
        defenderCard.rating +
        defenseAction.power +
        scenario.defenseBonus +
        _random.nextDouble() * 20;
    final outcome = _resolveRound(
      attackPower,
      defensePower,
      attackAction,
      defenseAction,
    );

    final opponentRedCarded = [...state.opponentRedCarded];
    final redCarded = [...state.redCardedCards];
    if (outcome == RoundOutcome.redCard) {
      if (state.playerAttacking) {
        opponentRedCarded.add(defenderCard.id);
      } else {
        redCarded.add(defenderCard.id);
      }
    }

    final playerGoal = outcome == RoundOutcome.goal && state.playerAttacking;
    final opponentGoal = outcome == RoundOutcome.goal && !state.playerAttacking;
    final result = RoundResult(
      round: state.currentRound,
      scenario: scenario,
      playerAttacking: state.playerAttacking,
      attackerCard: attackerCard,
      defenderCard: defenderCard,
      attackAction: attackAction,
      defenseAction: defenseAction,
      outcome: outcome,
      attackPower: attackPower,
      defensePower: defensePower,
    );

    emit(
      state.copyWith(
        phase: MatchPhase.roundResult,
        playerScore: state.playerScore + (playerGoal ? 1 : 0),
        opponentScore: state.opponentScore + (opponentGoal ? 1 : 0),
        usedPlayerCards: [...state.usedPlayerCards, playerCard.id],
        usedActionCards: [...state.usedActionCards, actionCard.id],
        redCardedCards: redCarded,
        opponentRedCarded: opponentRedCarded,
        roundResults: [...state.roundResults, result],
      ),
    );
  }

  void _onRoundAdvanced(RoundAdvanced event, Emitter<GameState> emit) {
    if (state.currentRound >= 4) {
      emit(state.copyWith(phase: MatchPhase.matchEnd));
      return;
    }
    final nextRound = state.currentRound + 1;
    final initialAttack = state.initialAttackingChoice ?? state.playerAttacking;
    emit(
      state.copyWith(
        currentRound: nextRound,
        phase: MatchPhase.scenario,
        currentScenario: null,
        selectedPlayerCard: null,
        selectedActionCard: null,
        playerAttacking: nextRound.isOdd ? initialAttack : !initialAttack,
      ),
    );
  }

  void _onPenaltyTaken(PenaltyTaken event, Emitter<GameState> emit) {
    if (state.penaltyPhaseOver) return;
    final byPlayer = state.penaltyRound.isEven;
    final chance = 0.65 + _random.nextDouble() * 0.1;
    final scored = _random.nextDouble() < chance;
    final kick = PenaltyKick(
      byPlayer: byPlayer,
      scored: scored,
      label: scored ? 'Goal' : (_random.nextBool() ? 'Saved' : 'Missed'),
    );
    final kicks = [...state.penaltyKicks, kick];
    final playerScore = state.penaltyPlayerScore + (byPlayer && scored ? 1 : 0);
    final opponentScore =
        state.penaltyOpponentScore + (!byPlayer && scored ? 1 : 0);
    final nextRound = state.penaltyRound + 1;
    var over = false;
    if (kicks.length >= 6 &&
        kicks.length.isEven &&
        playerScore != opponentScore) {
      over = true;
    }
    emit(
      state.copyWith(
        penaltyKicks: kicks,
        penaltyPlayerScore: playerScore,
        penaltyOpponentScore: opponentScore,
        penaltyRound: nextRound,
        penaltyPhaseOver: over,
      ),
    );
  }

  Future<void> _onMatchFinished(
    MatchFinished event,
    Emitter<GameState> emit,
  ) async {
    final activeDeck = state.deckSlots
        .where((slot) => slot.id == state.activeDeckId)
        .firstOrNull;
    final historyEntry = MatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      deckName: activeDeck?.name ?? 'Unknown Deck',
      timestampIso: DateTime.now().toIso8601String(),
      resultLabel: _resultLabelForState(state),
      playerScore: state.playerScore,
      opponentScore: state.opponentScore,
      penaltyPlayerScore: state.penaltyKicks.isEmpty
          ? null
          : state.penaltyPlayerScore,
      penaltyOpponentScore: state.penaltyKicks.isEmpty
          ? null
          : state.penaltyOpponentScore,
      rounds: state.roundResults
          .map(
            (round) => MatchHistoryRound(
              round: round.round,
              scenarioTitle: round.scenario.title,
              outcomeLabel: outcomeLabel(round.outcome),
              playerAttacking: round.playerAttacking,
            ),
          )
          .toList(),
    );
    final history = [historyEntry, ...state.matchHistory].take(12).toList();
    emit(state.copyWith(phase: MatchPhase.finalResult, matchHistory: history));
    await _storage.saveMatchHistory(history);
  }

  RoundOutcome _resolveRound(
    double attackPower,
    double defensePower,
    ActionCard attackAction,
    ActionCard defenseAction,
  ) {
    if (defenseAction.risky && _random.nextDouble() < 0.12) {
      return RoundOutcome.redCard;
    }
    if (attackAction.risky && _random.nextDouble() < 0.12) {
      return RoundOutcome.foul;
    }
    final diff = attackPower - defensePower;
    final roll = _random.nextDouble();
    if (diff > 15) {
      if (roll < 0.75) return RoundOutcome.goal;
      if (roll < 0.95) return RoundOutcome.saved;
      return RoundOutcome.blocked;
    }
    if (diff > 5) {
      if (roll < 0.60) return RoundOutcome.goal;
      if (roll < 0.90) return RoundOutcome.saved;
      return RoundOutcome.missed;
    }
    if (diff > -5) {
      if (roll < 0.45) return RoundOutcome.goal;
      if (roll < 0.80) return RoundOutcome.saved;
      return _random.nextBool() ? RoundOutcome.missed : RoundOutcome.blocked;
    }
    if (diff > -15) {
      if (roll < 0.65) return RoundOutcome.saved;
      if (roll < 0.90) return RoundOutcome.blocked;
      return RoundOutcome.goal;
    }
    if (roll < 0.75) return RoundOutcome.saved;
    if (roll < 0.95) return RoundOutcome.blocked;
    return RoundOutcome.goal;
  }

  GameState _resetMatch(GameState old) => GameState.initial().copyWith(
    loading: false,
    deckSlots: old.deckSlots,
    activeDeckId: old.activeDeckId,
    deckAttackers: old.deckAttackers,
    deckDefenders: old.deckDefenders,
    deckActions: old.deckActions,
    ownedCardIds: old.ownedCardIds,
    matchHistory: old.matchHistory,
    tutorialSeen: old.tutorialSeen,
    starterPackCards: old.starterPackCards,
    starterPackPending: old.starterPackPending,
  );

  StoredDeckSlot _hydratedSlot(StoredDeckSlot slot) => StoredDeckSlot(
    id: slot.id,
    name: slot.name,
    attackers: slot.attackers
        .where((id) => attackers.any((card) => card.id == id))
        .toList(),
    defenders: slot.defenders
        .where((id) => defenders.any((card) => card.id == id))
        .toList(),
    actions: slot.actions
        .where((id) => actionCards.any((card) => card.id == id))
        .toList(),
  );

  List<PlayerCard> _buildStarterPack() {
    final usedIds = <String>{};
    return [
      _pickCardForPack(attackers, excludeIds: usedIds),
      _pickCardForPack(attackers, excludeIds: usedIds),
      _pickCardForPack(defenders, excludeIds: usedIds),
      _pickCardForPack(defenders, excludeIds: usedIds),
      _pickCardForPack(goalkeepers, excludeIds: usedIds),
    ];
  }

  PlayerCard _pickCardForPack(List<PlayerCard> source, {Set<String>? excludeIds}) {
    final available = excludeIds == null
        ? source
        : source.where((card) => !excludeIds.contains(card.id)).toList();
    final poolSource = available.isEmpty ? source : available;
    final byTier = {
      CardTier.bronze: poolSource
          .where((card) => card.tier == CardTier.bronze)
          .toList(),
      CardTier.silver: poolSource
          .where((card) => card.tier == CardTier.silver)
          .toList(),
      CardTier.gold: poolSource.where((card) => card.tier == CardTier.gold).toList(),
      CardTier.platinum: poolSource
          .where((card) => card.tier == CardTier.platinum)
          .toList(),
    };
    final roll = _random.nextDouble();
    final tier = roll < 0.50
        ? CardTier.bronze
        : roll < 0.80
        ? CardTier.silver
        : roll < 0.95
        ? CardTier.gold
        : CardTier.platinum;
    final pool = byTier[tier];
    if (pool != null && pool.isNotEmpty) {
      final card = pool[_random.nextInt(pool.length)];
      excludeIds?.add(card.id);
      return card;
    }
    final card = poolSource[_random.nextInt(poolSource.length)];
    excludeIds?.add(card.id);
    return card;
  }

  String _resultLabelForState(GameState state) {
    if (state.playerScore > state.opponentScore) return 'Victory';
    if (state.playerScore < state.opponentScore) return 'Defeat';
    if (state.penaltyPlayerScore > state.penaltyOpponentScore) return 'Victory';
    if (state.penaltyPlayerScore < state.penaltyOpponentScore) return 'Defeat';
    return 'Draw';
  }
}

List<PlayerCard> cardsByIds(List<PlayerCard> source, List<String> ids) => ids
    .map((id) => source.where((card) => card.id == id).firstOrNull)
    .whereType<PlayerCard>()
    .toList();

List<ActionCard> actionCardsByIds(List<String> ids) => ids
    .map((id) => actionCards.where((card) => card.id == id).firstOrNull)
    .whereType<ActionCard>()
    .toList();

class PitchDuelApp extends StatelessWidget {
  const PitchDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
      child: MaterialApp(
        title: 'Pitch Duel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Cyber.cyan,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Cyber.bg,
          fontFamily: 'Onest',
          textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
            fontFamily: 'Onest',
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xff070b14),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Cyber.panel,
            elevation: 0,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              side: BorderSide(color: Cyber.line),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              foregroundColor: Cyber.bg,
              backgroundColor: Cyber.cyan,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Cyber.cyan,
              side: const BorderSide(color: Cyber.line),
              minimumSize: const Size.fromHeight(46),
              textStyle: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          chipTheme: const ChipThemeData(
            backgroundColor: Cyber.panel2,
            selectedColor: Cyber.cyan,
            side: BorderSide(color: Cyber.line),
            labelStyle: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection section = AppSection.game;

  void _go(AppSection next) => setState(() => section = next);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state.loading) {
          return Container(
            color: Cyber.bg,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Cyber.cyan),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading Game...',
                    style: TextStyle(color: Cyber.cyan, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }
        return Stack(
          children: [
            switch (section) {
              AppSection.shop => ShopScreen(onNavigate: _go),
              _ => GameTabContent(onNavigate: _go),
            },
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomNavBar(
                currentSection: section,
                onNavigate: _go,
              ),
            ),
          ],
        );
      },
    );
  }
}

class GameTabContent extends StatefulWidget {
  const GameTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<GameTabContent> createState() => _GameTabContentState();
}

class _GameTabContentState extends State<GameTabContent> {
  AppSection _gameSection = AppSection.home;

  void _navigateGame(AppSection section) {
    if (section == AppSection.shop) {
      widget.onNavigate(AppSection.shop);
    } else if (section == AppSection.game ||
               section == AppSection.home ||
               section == AppSection.deck ||
               section == AppSection.howToPlay ||
               section == AppSection.match) {
      setState(() => _gameSection = section == AppSection.game ? AppSection.home : section);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_gameSection) {
      AppSection.home => HomeScreen(onNavigate: _navigateGame),
      AppSection.deck => DeckBuilderScreen(onNavigate: _navigateGame),
      AppSection.howToPlay => HowToPlayScreen(onNavigate: _navigateGame),
      AppSection.match => MatchScreen(onNavigate: _navigateGame),
      _ => HomeScreen(onNavigate: _navigateGame),
    };
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Shop',
            subtitle: '// Currency Exchange',
            onBack: () => onNavigate(AppSection.game),
            showShop: false,
          ),
          body: CyberBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 116),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/coin.svg',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your Balance',
                            style: TextStyle(
                              color: Cyber.muted,
                              fontFamily: 'Onest',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.ownedCardIds.length * 100}',
                            style: const TextStyle(
                              color: Color(0xffFDC700),
                              fontFamily: 'Orbitron',
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'COIN PACKAGES',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...[
                      _CoinPackage(
                        coins: 100,
                        price: '\$0.99',
                        bonus: 0,
                      ),
                      _CoinPackage(
                        coins: 550,
                        price: '\$4.99',
                        bonus: 50,
                      ),
                      _CoinPackage(
                        coins: 1200,
                        price: '\$9.99',
                        bonus: 200,
                        featured: true,
                      ),
                      _CoinPackage(
                        coins: 2500,
                        price: '\$19.99',
                        bonus: 500,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoinPackage extends StatelessWidget {
  const _CoinPackage({
    required this.coins,
    required this.price,
    required this.bonus,
    this.featured = false,
  });

  final int coins;
  final String price;
  final int bonus;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase $coins coins for $price'),
            backgroundColor: Cyber.cyan,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: featured ? Cyber.cyan : const Color(0xff2a3a52),
            width: featured ? 2 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: featured
                ? [
                    Cyber.cyan.withValues(alpha: 0.15),
                    Cyber.panel,
                    Cyber.panel2,
                  ]
                : [
                    Cyber.panel.withValues(alpha: 0.8),
                    Cyber.panel2,
                  ],
            stops: const [0, 0.42, 1],
          ),
          boxShadow: featured
              ? [
                  BoxShadow(
                    color: Cyber.cyan.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/coin.svg',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$coins',
                        style: const TextStyle(
                          color: Color(0xffFDC700),
                          fontFamily: 'Orbitron',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (bonus > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '+$bonus Bonus',
                      style: TextStyle(
                        color: Cyber.lime,
                        fontFamily: 'Onest',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (featured) ...[
                    const SizedBox(height: 6),
                    CyberChip(
                      label: 'BEST VALUE',
                      color: Cyber.lime,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: featured ? Cyber.cyan : Cyber.cyan.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                price,
                style: TextStyle(
                  color: featured ? Cyber.cyan : Cyber.muted,
                  fontFamily: 'Onest',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentSection,
    required this.onNavigate,
  });

  final AppSection currentSection;
  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Cyber.cyan.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg2.withValues(alpha: 0.8),
            Cyber.bg,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.sports_soccer,
                  label: 'GAME',
                  isActive: currentSection == AppSection.game,
                  onTap: () => onNavigate(AppSection.game),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NavItem(
                  icon: Icons.shopping_bag,
                  label: 'SHOP',
                  isActive: currentSection == AppSection.shop,
                  onTap: () => onNavigate(AppSection.shop),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Cyber.cyan : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Cyber.cyan : Cyber.muted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Cyber.cyan : Cyber.muted,
                fontFamily: 'Onest',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Pitch Duel',
            subtitle: '// Main Terminal',
            onBack: () => onNavigate(AppSection.home),
            showShop: true,
          ),
          body: CyberBackground(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 116),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 58,
                            color: Cyber.cyan,
                            shadows: [
                              Shadow(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          CyberChip(
                            label: state.deckReady
                                ? '● Deck Online'
                                : '◐ Default Loadout',
                            color: state.deckReady ? Cyber.lime : Cyber.amber,
                          ),
                          if (state.starterPackPending) ...[
                            const SizedBox(height: 18),
                            StarterPackHomePanel(cards: state.starterPackCards),
                          ],
                          const SizedBox(height: 28),
                          CyberCtaButton(
                            label: 'Play Match',
                            primary: true,
                            onPressed: state.deckReady
                                ? () {
                                    context.read<GameBloc>().add(
                                      MatchStarted(),
                                    );
                                    onNavigate(AppSection.match);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                          CyberCtaButton(
                            label: 'Deck Builder',
                            onPressed: () => onNavigate(AppSection.deck),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => onNavigate(AppSection.howToPlay),
                            child: const Text(
                              'HOW TO PLAY',
                              style: TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          MatchHistoryPanel(history: state.matchHistory),
                          const SizedBox(height: 16),
                          const FeaturesPanel(compact: true),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              context.read<GameBloc>().add(TutorialReset());
                              showTutorialNow(
                                context,
                                keyName: 'home',
                                steps: homeTutorialSteps,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tutorial reset')),
                              );
                            },
                            child: Text(
                              '↻ REPLAY WALKTHROUGH',
                              style: TextStyle(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(width: 160, child: HudLine()),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: DailyDropButton(),
                  ),
                ),
                const TutorialTip(keyName: 'home', steps: homeTutorialSteps),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DailyDropButton extends StatefulWidget {
  const DailyDropButton({super.key});

  @override
  State<DailyDropButton> createState() => _DailyDropButtonState();
}

class _DailyDropButtonState extends State<DailyDropButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0),
            Cyber.bg.withValues(alpha: 0.94),
            Cyber.bg,
          ],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GestureDetector(
          onTap: () {
            final pool = allPlayerCards;
            final card = pool[_random.nextInt(pool.length)];
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.86),
              builder: (_) => DailyDropRevealDialog(card: card),
            );
          },
          child: ClipPath(
            clipper: CyberClipper(),
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Cyber.amber, Color(0xffff7a2f), Cyber.magenta],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.amber.withValues(alpha: 0.32),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: const SizedBox(width: double.infinity, height: 76),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, _) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final travel = width + 260;
                          return Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(
                                  -180 + _shimmer.value * travel,
                                  0,
                                ),
                                child: Transform.rotate(
                                  angle: -0.32,
                                  child: Container(
                                    width: 132,
                                    height: constraints.maxHeight * 2.1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0),
                                          Colors.white.withValues(alpha: 0.18),
                                          Colors.white.withValues(alpha: 0.55),
                                          Colors.white.withValues(alpha: 0.18),
                                          Colors.white.withValues(alpha: 0),
                                        ],
                                        stops: const [0, 0.24, 0.5, 0.76, 1],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                        -1 + _shimmer.value * 2,
                                        -1,
                                      ),
                                      end: Alignment(
                                        0.2 + _shimmer.value * 2,
                                        1,
                                      ),
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.08),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22ffffff),
                          Color(0x00000000),
                          Color(0x22000000),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.style, color: Color(0xff160a00)),
                      SizedBox(width: 14),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY DROP',
                            style: TextStyle(
                              color: Color(0xaa160a00),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'OPEN YOUR DAILY CARD',
                            style: TextStyle(
                              color: Color(0xff160a00),
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DailyDropRevealDialog extends StatefulWidget {
  const DailyDropRevealDialog({required this.card, super.key});

  final PlayerCard card;

  @override
  State<DailyDropRevealDialog> createState() => _DailyDropRevealDialogState();
}

class _DailyDropRevealDialogState extends State<DailyDropRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: CyberPanel(
        accent: Cyber.amber,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final reveal = Curves.easeOutBack.transform(
              ((_controller.value - 0.48) / 0.52).clamp(0.0, 1.0),
            );
            final tear = Curves.easeInOutCubic.transform(
              ((_controller.value - 0.20) / 0.42).clamp(0.0, 1.0),
            );
            final packMotion = _controller.value;
            final packPulse =
                1 + sin(_controller.value * pi * 8) * 0.028 * (1 - tear);
            final flash = (1 - ((_controller.value - 0.52).abs() * 5)).clamp(
              0.0,
              1.0,
            );
            final details = Curves.easeOutCubic.transform(
              ((_controller.value - 0.70) / 0.30).clamp(0.0, 1.0),
            );
            return SizedBox(
              height: 560,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DailyDropBurstPainter(
                        progress: t,
                        intensity: max(flash, reveal),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    child: Text(
                      _controller.value < 0.48
                          ? 'UNPACKING DAILY DROP'
                          : 'CARD UNVEILED',
                      style: TextStyle(
                        color: Cyber.cyan.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 78 - tear * 62,
                    child: Opacity(
                      opacity: 1 - reveal.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: packPulse,
                        child: Transform.rotate(
                          angle: -0.08 * tear,
                          child: DailyDropPackVisual(
                            label: 'DAILY',
                            tear: tear,
                            topHalf: true,
                            motion: packMotion,
                            flash: flash,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 218 + tear * 72,
                    child: Opacity(
                      opacity: 1 - reveal.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: packPulse,
                        child: Transform.rotate(
                          angle: 0.08 * tear,
                          child: DailyDropPackVisual(
                            label: 'DROP',
                            tear: tear,
                            topHalf: false,
                            motion: packMotion,
                            flash: flash,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 66,
                    child: Opacity(
                      opacity: flash * 0.72,
                      child: Container(
                        width: 270,
                        height: 270,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.3),
                          boxShadow: [
                            BoxShadow(
                              color: Cyber.amber.withValues(alpha: 0.75),
                              blurRadius: 60,
                              spreadRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 76,
                    child: Transform.scale(
                      scale: 0.72 + reveal * 0.28,
                      child: Opacity(
                        opacity: reveal.clamp(0.0, 1.0),
                        child: CyberPlayerCardTile(
                          card: widget.card,
                          selected: true,
                          size: VisualCardSize.md,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 78,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: details,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - details)),
                        child: Column(
                          children: [
                            Text(
                              widget.card.shortName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.card.country} · ${widget.card.position}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Cyber.muted,
                                fontFamily: 'Onest',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.card.trait.toUpperCase()} // OVR ${widget.card.rating}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Cyber.lime,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _controller.isCompleted ? 'CLOSE' : 'SKIP REVEAL',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class StarterPackHomePanel extends StatelessWidget {
  const StarterPackHomePanel({required this.cards, super.key});

  final List<PlayerCard> cards;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STARTER PACK UNLOCKED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Cyber.amber.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final card in cards)
                SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(card.icon, color: tierColor(card.tier), size: 22),
                      const SizedBox(height: 3),
                      Text(
                        playerRoleLabel(card),
                        style: TextStyle(
                          color: tierColor(card.tier),
                          fontFamily: 'Orbitron',
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Create a dummy ShopPackOption for the starter pack animation
                final starterPack = ShopPackOption(
                  id: 'starter',
                  name: 'Starter Pack',
                  coins: 0,
                  gradient: LinearGradient(
                    colors: [Cyber.cyan, Cyber.cyan],
                  ),
                );

                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return PackOpeningScreen(
                        pack: starterPack,
                        cards: cards, // Pass the pre-generated starter cards
                        onComplete: () {
                          // Fire StarterPackSeen event after animation completes
                          context.read<GameBloc>().add(StarterPackSeen());
                        },
                      );
                    },
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              child: const Text('CLAIM CARDS'),
            ),
          ),
        ],
      ),
    );
  }
}

class StarterPackRevealDialog extends StatelessWidget {
  const StarterPackRevealDialog({required this.cards, super.key});

  final List<PlayerCard> cards;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: CyberPanel(
        accent: Cyber.amber,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STARTER PACK UNLOCKED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Cyber.amber.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'First launch reward: 2 ATK, 2 DEF, 1 GK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pack rarity odds: Bronze 50%  Silver 30%  Gold 15%  Platinum 5%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Cyber.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final card in cards)
                    CyberPlayerCardTile(
                      card: card,
                      selected: true,
                      size: VisualCardSize.sm,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CONTINUE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyDropPackVisual extends StatelessWidget {
  const DailyDropPackVisual({
    required this.label,
    required this.tear,
    required this.topHalf,
    required this.motion,
    required this.flash,
    super.key,
  });

  final String label;
  final double tear;
  final bool topHalf;
  final double motion;
  final double flash;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: Container(
        width: 210,
        height: 132,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: topHalf ? Alignment.topLeft : Alignment.bottomLeft,
            end: topHalf ? Alignment.bottomRight : Alignment.topRight,
            colors: const [Cyber.amber, Color(0xffff7a2f), Cyber.magenta],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: Cyber.amber.withValues(alpha: 0.36),
              blurRadius: 28,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: CardStripePainter(color: Colors.white),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(-150 + motion * 360, 0),
                child: Transform.rotate(
                  angle: -0.36,
                  child: Container(
                    width: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.34 + flash * 0.22),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.2, topHalf ? -0.45 : 0.45),
                    radius: 0.95,
                    colors: [
                      Colors.white.withValues(alpha: 0.22 + flash * 0.38),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    topHalf ? Icons.style : Icons.auto_awesome,
                    color: const Color(0xff160a00),
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xff160a00),
                      fontFamily: 'Orbitron',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: topHalf ? 0 : null,
              top: topHalf ? null : 0,
              child: Container(
                height: 4 + tear * 8,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyDropBurstPainter extends CustomPainter {
  const DailyDropBurstPainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final rayPaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final angle = (pi * 2 / 18) * i + progress * pi;
      final start = 62 + progress * 18;
      final end = 132 + progress * 46 + intensity * 36;
      final opacity = (0.12 + intensity * 0.62 - (progress - 0.62).abs() * 0.22)
          .clamp(0.04, 0.72);
      rayPaint.color = (i.isEven ? Cyber.amber : Cyber.magenta).withValues(
        alpha: opacity,
      );
      canvas.drawLine(
        center + Offset(cos(angle) * start, sin(angle) * start),
        center + Offset(cos(angle) * end, sin(angle) * end),
        rayPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DailyDropBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}

class DeckBuilderScreen extends StatefulWidget {
  const DeckBuilderScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends State<DeckBuilderScreen> {
  late List<String?> selectedAttackers;
  late List<String?> selectedDefenders;
  late List<String?> selectedActions;
  bool editing = false;
  DeckPickerLane activeLane = DeckPickerLane.attacker;
  int activeSlotIndex = 0;
  ActionCategory? actionFilter;

  @override
  void initState() {
    super.initState();
    final state = context.read<GameBloc>().state;
    _loadDeckIntoEditor(state);
  }

  bool get valid =>
      selectedAttackers.every((id) => id != null) &&
      selectedDefenders.every((id) => id != null) &&
      selectedActions.every((id) => id != null);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (_, state) {
        if (!editing) {
          _loadDeckIntoEditor(state);
        }
      },
      builder: (context, state) {
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
        );
        final selectedAttackerCards = cardsByIds(
          attackers,
          selectedAttackers.whereType<String>().toList(),
        );
        final selectedDefenderCards = cardsByIds(
          defenders,
          selectedDefenders.whereType<String>().toList(),
        );
        final selectedActionCards = actionCardsByIds(
          selectedActions.whereType<String>().toList(),
        );
        final actionAtk = selectedActionCards
            .where((card) => card.category == ActionCategory.attack)
            .length;
        final actionDef = selectedActionCards
            .where((card) => card.category == ActionCategory.defense)
            .length;
        final actionSpc = selectedActionCards
            .where((card) => card.category == ActionCategory.special)
            .length;
        final missingAttackers = selectedAttackers
            .where((id) => id == null)
            .length;
        final missingDefenders = selectedDefenders
            .where((id) => id == null)
            .length;
        final missingActions = selectedActions.where((id) => id == null).length;
        final unbalancedActions =
            selectedActionCards.length == 6 &&
            (actionAtk == 0 || actionDef == 0);
        final focusedPlayer = switch (activeLane) {
          DeckPickerLane.attacker => selectedAttackerCards.elementAtOrNull(
            activeSlotIndex,
          ),
          DeckPickerLane.defender => selectedDefenderCards.elementAtOrNull(
            activeSlotIndex,
          ),
          DeckPickerLane.action => null,
        };
        final focusedAction = activeLane == DeckPickerLane.action
            ? selectedActionCards.elementAtOrNull(activeSlotIndex)
            : null;

        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Deck Builder',
            subtitle: editing ? 'Editing / squad planner' : active.name,
            onBack: () => widget.onNavigate(AppSection.home),
            showShop: false,
            rightSlot: TextButton(
              onPressed: editing
                  ? null
                  : () {
                      context.read<GameBloc>().add(DeckCreated());
                      setState(() {
                        editing = true;
                        selectedAttackers = List<String?>.filled(2, null);
                        selectedDefenders = List<String?>.filled(2, null);
                        selectedActions = List<String?>.filled(6, null);
                        activeLane = DeckPickerLane.attacker;
                        activeSlotIndex = 0;
                        actionFilter = null;
                      });
                    },
              child: const Text('NEW DECK'),
            ),
          ),
          body: CyberBackground(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 118),
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 58,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: state.deckSlots.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, index) {
                                      final slot = state.deckSlots[index];
                                      final activeSlot =
                                          slot.id == state.activeDeckId;
                                      return DeckPill(
                                        label: slot.name,
                                        meta:
                                            'P ${slot.attackers.length + slot.defenders.length}/4 / ACT ${slot.actions.length}/6',
                                        selected: activeSlot,
                                        onTap: editing
                                            ? null
                                            : () => context
                                                  .read<GameBloc>()
                                                  .add(DeckApplied(slot.id)),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DeckBuilderIntelPanel(
                                  editing: editing,
                                  valid: valid,
                                  missingAttackers: missingAttackers,
                                  missingDefenders: missingDefenders,
                                  missingActions: missingActions,
                                  actionAtk: actionAtk,
                                  actionDef: actionDef,
                                  actionSpc: actionSpc,
                                ),
                                const SizedBox(height: 10),
                                FiveSideDeckPanel(
                                  deckName: active.name,
                                  valid: valid,
                                  attackers: selectedAttackerCards,
                                  defenders: selectedDefenderCards,
                                  actions: selectedActionCards,
                                  actionAtk: actionAtk,
                                  actionDef: actionDef,
                                  actionSpc: actionSpc,
                                  focusedLane: activeLane,
                                  focusedIndex: activeSlotIndex,
                                  editing: editing,
                                  onAttackTap: (index) => _focusSlot(
                                    DeckPickerLane.attacker,
                                    index,
                                  ),
                                  onDefenseTap: (index) => _focusSlot(
                                    DeckPickerLane.defender,
                                    index,
                                  ),
                                  onActionTap: (index) =>
                                      _focusSlot(DeckPickerLane.action, index),
                                ),
                                if (unbalancedActions) ...[
                                  const SizedBox(height: 12),
                                  const DeckActionWarningPanel(),
                                ],
                                if (editing) ...[
                                  const SizedBox(height: 12),
                                  DeckFocusedSelectionPanel(
                                    lane: activeLane,
                                    slotIndex: activeSlotIndex,
                                    selectedPlayer: focusedPlayer,
                                    selectedAction: focusedAction,
                                    actionFilter: actionFilter,
                                    onFilterChanged: (filter) =>
                                        setState(() => actionFilter = filter),
                                    onClear: _clearActiveSlot,
                                    playerOptions:
                                        activeLane == DeckPickerLane.attacker
                                        ? attackers
                                        : defenders,
                                    actionOptions:
                                        activeLane == DeckPickerLane.action
                                        ? actionCards
                                              .where(
                                                (card) =>
                                                    actionFilter == null ||
                                                    card.category ==
                                                        actionFilter,
                                              )
                                              .toList()
                                        : const [],
                                    isPlayerDisabled: (card) =>
                                        _isPlayerCardLocked(card.id),
                                    isActionDisabled: (card) =>
                                        _isActionCardLocked(card.id),
                                    onSelectPlayer: _assignPlayerToActiveSlot,
                                    onSelectAction: _assignActionToActiveSlot,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    BottomActionBar(
                      primaryLabel: 'PLAY',
                      primaryEnabled: valid,
                      primaryOnTap: () {
                        final slot = _buildStoredSlot(
                          active.name,
                          state.activeDeckId,
                        );
                        context.read<GameBloc>().add(DeckSaved(slot));
                        context.read<GameBloc>().add(MatchStarted());
                        widget.onNavigate(AppSection.match);
                      },
                      secondaryLabel: editing ? 'SAVE' : 'EDIT',
                      secondaryOnTap: () {
                        if (editing) {
                          context.read<GameBloc>().add(
                            DeckSaved(
                              _buildStoredSlot(active.name, state.activeDeckId),
                            ),
                          );
                        }
                        setState(() {
                          editing = !editing;
                          if (editing) {
                            activeLane = DeckPickerLane.attacker;
                            activeSlotIndex = 0;
                            actionFilter = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const TutorialTip(
                  keyName: 'deck-builder',
                  steps: deckTutorialSteps,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _loadDeckIntoEditor(GameState state) {
    selectedAttackers = List<String?>.generate(
      2,
      (index) => index < state.deckAttackers.length
          ? state.deckAttackers[index].id
          : null,
    );
    selectedDefenders = List<String?>.generate(
      2,
      (index) => index < state.deckDefenders.length
          ? state.deckDefenders[index].id
          : null,
    );
    selectedActions = List<String?>.generate(
      6,
      (index) =>
          index < state.deckActions.length ? state.deckActions[index].id : null,
    );
  }

  StoredDeckSlot _buildStoredSlot(String name, String id) => StoredDeckSlot(
    id: id,
    name: name,
    attackers: selectedAttackers.whereType<String>().toList(),
    defenders: selectedDefenders.whereType<String>().toList(),
    actions: selectedActions.whereType<String>().toList(),
  );

  void _focusSlot(DeckPickerLane lane, int index) {
    if (!editing) return;
    setState(() {
      activeLane = lane;
      activeSlotIndex = index;
      if (lane != DeckPickerLane.action) {
        actionFilter = null;
      }
    });
  }

  bool _isPlayerCardLocked(String id) {
    if (activeLane == DeckPickerLane.action) return true;
    final activeList = activeLane == DeckPickerLane.attacker
        ? selectedAttackers
        : selectedDefenders;
    final currentId = activeList[activeSlotIndex];
    return activeList.contains(id) && currentId != id;
  }

  bool _isActionCardLocked(String id) {
    final currentId = selectedActions[activeSlotIndex];
    return selectedActions.contains(id) && currentId != id;
  }

  void _assignPlayerToActiveSlot(PlayerCard card) {
    if (!editing || activeLane == DeckPickerLane.action) return;
    setState(() {
      final activeList = activeLane == DeckPickerLane.attacker
          ? [...selectedAttackers]
          : [...selectedDefenders];
      final previousIndex = activeList.indexOf(card.id);
      final currentId = activeList[activeSlotIndex];
      if (previousIndex != -1 && previousIndex != activeSlotIndex) {
        activeList[previousIndex] = currentId;
      }
      activeList[activeSlotIndex] = card.id;
      if (activeLane == DeckPickerLane.attacker) {
        selectedAttackers = activeList;
      } else {
        selectedDefenders = activeList;
      }
      _advanceFocus();
    });
  }

  void _assignActionToActiveSlot(ActionCard card) {
    if (!editing || activeLane != DeckPickerLane.action) return;
    setState(() {
      final activeList = [...selectedActions];
      final previousIndex = activeList.indexOf(card.id);
      final currentId = activeList[activeSlotIndex];
      if (previousIndex != -1 && previousIndex != activeSlotIndex) {
        activeList[previousIndex] = currentId;
      }
      activeList[activeSlotIndex] = card.id;
      selectedActions = activeList;
      _advanceFocus();
    });
  }

  void _clearActiveSlot() {
    if (!editing) return;
    setState(() {
      switch (activeLane) {
        case DeckPickerLane.attacker:
          selectedAttackers[activeSlotIndex] = null;
          break;
        case DeckPickerLane.defender:
          selectedDefenders[activeSlotIndex] = null;
          break;
        case DeckPickerLane.action:
          selectedActions[activeSlotIndex] = null;
          break;
      }
    });
  }

  void _advanceFocus() {
    final nextAttacker = selectedAttackers.indexOf(null);
    final nextDefender = selectedDefenders.indexOf(null);
    final nextAction = selectedActions.indexOf(null);
    if (nextAttacker != -1) {
      activeLane = DeckPickerLane.attacker;
      activeSlotIndex = nextAttacker;
      return;
    }
    if (nextDefender != -1) {
      activeLane = DeckPickerLane.defender;
      activeSlotIndex = nextDefender;
      return;
    }
    if (nextAction != -1) {
      activeLane = DeckPickerLane.action;
      activeSlotIndex = nextAction;
    }
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Timer? cpuTossTimer;
  Timer? cpuPenaltyTimer;

  @override
  void dispose() {
    cpuTossTimer?.cancel();
    cpuPenaltyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        if (state.phase == MatchPhase.scenario &&
            state.currentScenario == null) {
          context.read<GameBloc>().add(ScenarioShown());
        }
        if (state.phase == MatchPhase.tossResult &&
            state.playerWonToss == false) {
          cpuTossTimer?.cancel();
          cpuTossTimer = Timer(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            context.read<GameBloc>().add(RoleChosen(Random().nextBool()));
          });
        }
        if (state.phase == MatchPhase.penalty &&
            !state.penaltyPhaseOver &&
            state.penaltyRound.isOdd) {
          cpuPenaltyTimer?.cancel();
          cpuPenaltyTimer = Timer(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            context.read<GameBloc>().add(PenaltyTaken());
          });
        }
      },
      builder: (context, state) {
        return switch (state.phase) {
          MatchPhase.toss => TossPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.tossResult => TossResultPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.scenario => ScenarioPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.play => PlayPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.roundResult => RoundResultPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.matchEnd => MatchEndPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.penalty => PenaltyPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.finalResult => FinalResultPhase(
            state: state,
            onNavigate: widget.onNavigate,
          ),
          MatchPhase.idle => GameScaffold(
            title: 'Match',
            subtitle: '// Match Terminal',
            leading: IconButton(
              onPressed: () => _quit(context),
              icon: const Icon(Icons.close),
            ),
            child: Center(
              child: CyberCtaButton(
                label: 'Start Match',
                primary: true,
                onPressed: () => context.read<GameBloc>().add(MatchStarted()),
              ),
            ),
          ),
        };
      },
    );
  }

  Future<void> _quit(BuildContext context) async {
    final gameBloc = context.read<GameBloc>();
    final phase = gameBloc.state.phase;
    final matchInProgress =
        phase != MatchPhase.idle &&
        phase != MatchPhase.finalResult &&
        phase != MatchPhase.matchEnd;

    if (matchInProgress) {
      final confirmed = await showCyberConfirmDialog(
        context,
        title: 'Quit Match?',
        message: 'Your current match progress will be lost.',
        confirmLabel: 'Quit',
        cancelLabel: 'Keep Playing',
        destructive: true,
      );
      if (!mounted || !confirmed) return;
    }

    gameBloc.add(MatchReset());
    widget.onNavigate(AppSection.home);
  }
}

class TossPhase extends StatelessWidget {
  const TossPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Coin Toss Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'toss',
      tutorialSteps: tossTutorialSteps,
      children: [
        const SizedBox(height: 18),
        Icon(
          Icons.toll,
          size: 92,
          color: Cyber.cyan,
          shadows: [Shadow(color: Cyber.cyan, blurRadius: 18)],
        ),
        const SizedBox(height: 8),
        const Text(
          '▸ INITIATING TOSS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                label: 'Heads',
                selected: state.tossChoice == 'heads',
                onTap: () =>
                    context.read<GameBloc>().add(TossChoiceChanged('heads')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceButton(
                label: 'Tails',
                selected: state.tossChoice == 'tails',
                onTap: () =>
                    context.read<GameBloc>().add(TossChoiceChanged('tails')),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: state.tossChoice == null
              ? null
              : () => context.read<GameBloc>().add(TossResolved()),
          icon: const Icon(Icons.flip),
          label: const Text('▸ FLIP COIN'),
        ),
      ],
    );
  }
}

class TossResultPhase extends StatelessWidget {
  const TossResultPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Coin Toss Result',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'toss',
      tutorialSteps: tossTutorialSteps,
      children: [
        InfoPanel(
          icon: Icons.toll,
          title: 'It landed ${state.tossResult?.toUpperCase()}',
          body: state.playerWonToss == true
              ? 'You won the toss. Pick your opening role.'
              : 'CPU won the toss and is choosing a role.',
        ),
        if (state.playerWonToss == true)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.read<GameBloc>().add(RoleChosen(true)),
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('Attack'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.read<GameBloc>().add(RoleChosen(false)),
                  icon: const Icon(Icons.shield),
                  label: const Text('Defend'),
                ),
              ),
            ],
          )
        else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class ScenarioPhase extends StatelessWidget {
  const ScenarioPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final scenario = state.currentScenario;
    if (scenario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Scenario Briefing',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'scenario',
      tutorialSteps: scenarioTutorialSteps,
      children: [
        InfoPanel(
          icon: scenario.icon,
          title: scenario.title,
          body:
              '${scenario.description}\nAttack +${scenario.attackBonus}  Defense +${scenario.defenseBonus}\nYou are ${state.playerAttacking ? 'attacking' : 'defending'} this round.',
        ),
        FilledButton.icon(
          onPressed: () => context.read<GameBloc>().add(PlayStarted()),
          icon: const Icon(Icons.style),
          label: const Text('▸ SELECT CARDS'),
        ),
      ],
    );
  }
}

class PlayPhase extends StatelessWidget {
  const PlayPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final playerPool = state.playerAttacking
        ? state.deckAttackers
        : state.deckDefenders;
    final availablePlayers = playerPool
        .where((card) => !state.redCardedCards.contains(card.id))
        .toList();
    final availableActions = state.deckActions
        .where(
          (card) => state.playerAttacking
              ? card.category == ActionCategory.attack ||
                    card.category == ActionCategory.special
              : card.category == ActionCategory.defense ||
                    card.category == ActionCategory.special,
        )
        .toList();
    final scenarioBonus = state.playerAttacking
        ? state.currentScenario?.attackBonus ?? 0
        : state.currentScenario?.defenseBonus ?? 0;
    final estimate =
        state.selectedPlayerCard == null || state.selectedActionCard == null
        ? null
        : state.selectedPlayerCard!.rating +
              state.selectedActionCard!.power +
              scenarioBonus;
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: state.currentScenario?.title ?? '// Play Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'play',
      tutorialSteps: playTutorialSteps,
      children: [
        RoleStrip(attacking: state.playerAttacking),
        SelectedMovePanel(
          player: state.selectedPlayerCard,
          action: state.selectedActionCard,
          estimate: estimate,
        ),
        SectionLabel(
          label: state.playerAttacking
              ? 'Roster // Finishers'
              : 'Roster // Stoppers',
        ),
        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: availablePlayers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final card = availablePlayers[index];
              return CyberPlayerCardTile(
                card: card,
                selected: state.selectedPlayerCard?.id == card.id,
                onTap: () => context.read<GameBloc>().add(PlayerSelected(card)),
              );
            },
          ),
        ),
        const SectionLabel(label: 'Action Grid'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in availableActions)
              CyberActionCardTile(
                card: card,
                selected: state.selectedActionCard?.id == card.id,
                onTap: () => context.read<GameBloc>().add(ActionSelected(card)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        CyberCtaButton(
          label: 'Execute Move',
          primary: true,
          onPressed:
              state.selectedPlayerCard == null ||
                  state.selectedActionCard == null
              ? null
              : () => context.read<GameBloc>().add(MovePlayed()),
        ),
      ],
    );
  }
}

class RoundResultPhase extends StatelessWidget {
  const RoundResultPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final result = state.roundResults.last;
    return MatchPhaseScaffold(
      title: 'Round ${result.round} // Result',
      subtitle: '// Resolution Log',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'round-result',
      tutorialSteps: resultTutorialSteps,
      children: [
        Icon(outcomeIcon(result.outcome), size: 72, color: Cyber.cyan),
        Text(
          outcomeLabel(result.outcome).toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: 2,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CyberChip(
              label: result.attackPower.toStringAsFixed(1),
              color: Cyber.lime,
            ),
            const SizedBox(width: 10),
            CyberChip(
              label: result.defensePower.toStringAsFixed(1),
              color: Cyber.cyan,
            ),
          ],
        ),
        InfoPanel(
          icon: outcomeIcon(result.outcome),
          title: outcomeLabel(result.outcome),
          body:
              '${result.attackerCard.name} with ${result.attackAction.title}\nvs ${result.defenderCard.name} with ${result.defenseAction.title}\nPower ${result.attackPower.toStringAsFixed(1)} - ${result.defensePower.toStringAsFixed(1)}',
        ),
        if (state.currentRound >= 4)
          FilledButton.icon(
            onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
            icon: const Icon(Icons.flag),
            label: const Text('Full-Time Result'),
          )
        else
          _NextRoundCountdown(
            onComplete: () => context.read<GameBloc>().add(RoundAdvanced()),
          ),
      ],
    );
  }
}

class _NextRoundCountdown extends StatefulWidget {
  const _NextRoundCountdown({required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<_NextRoundCountdown> createState() => _NextRoundCountdownState();
}

class _NextRoundCountdownState extends State<_NextRoundCountdown> {
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    for (var i = 3; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds = i - 1);
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _seconds > 0 ? '$_seconds' : 'Go!',
          style: const TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 48,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Next round starting…',
          style: TextStyle(color: Cyber.line, fontSize: 13),
        ),
      ],
    );
  }
}

class MatchEndPhase extends StatelessWidget {
  const MatchEndPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final tied = state.playerScore == state.opponentScore;
    final title = tied
        ? 'Deadlock'
        : (state.playerScore > state.opponentScore ? 'Victory' : 'Defeat');
    return MatchPhaseScaffold(
      title: 'Full Time',
      subtitle: '// Match Archive',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'match-end',
      tutorialSteps: matchEndTutorialSteps,
      children: [
        InfoPanel(
          icon: tied ? Icons.balance : Icons.emoji_events,
          title: title,
          body: tied
              ? 'The match is level. Settle it from the spot.'
              : 'Regular time is complete.',
        ),
        FilledButton.icon(
          onPressed: () => context.read<GameBloc>().add(
            tied ? PenaltyStarted() : MatchFinished(),
          ),
          icon: Icon(tied ? Icons.adjust : Icons.done),
          label: Text(tied ? 'Penalty Shootout' : 'Finish Match'),
        ),
      ],
    );
  }
}

class PenaltyPhase extends StatelessWidget {
  const PenaltyPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final playerTurn = state.penaltyRound.isEven;
    return MatchPhaseScaffold(
      title: 'Penalty Shootout',
      subtitle: '// Sudden Pressure',
      state: state,
      onQuit: onQuit,
      scoreLabel:
          'PEN ${state.penaltyPlayerScore}-${state.penaltyOpponentScore}',
      tutorialKey: 'penalty',
      tutorialSteps: penaltyTutorialSteps,
      children: [
        InfoPanel(
          icon: Icons.adjust,
          title:
              'Penalties ${state.penaltyPlayerScore}-${state.penaltyOpponentScore}',
          body: state.penaltyPhaseOver
              ? 'Shootout complete.'
              : playerTurn
              ? 'Your kick.'
              : 'CPU is stepping up.',
        ),
        for (final kick in state.penaltyKicks.reversed)
          CyberPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  kick.scored ? Icons.check_circle : Icons.cancel,
                  color: kick.scored ? Cyber.lime : Cyber.red,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(kick.byPlayer ? 'YOU' : 'CPU')),
                Text(kick.label),
              ],
            ),
          ),
        if (state.penaltyPhaseOver)
          FilledButton.icon(
            onPressed: () => context.read<GameBloc>().add(MatchFinished()),
            icon: const Icon(Icons.done_all),
            label: const Text('Final Result'),
          )
        else
          FilledButton.icon(
            onPressed: playerTurn
                ? () => context.read<GameBloc>().add(PenaltyTaken())
                : null,
            icon: const Icon(Icons.sports_soccer),
            label: Text(playerTurn ? 'Take Kick' : 'CPU Kicking'),
          ),
      ],
    );
  }
}

class FinalResultPhase extends StatelessWidget {
  const FinalResultPhase({
    required this.state,
    required this.onNavigate,
    super.key,
  });

  final GameState state;
  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final won =
        state.playerScore > state.opponentScore ||
        (state.playerScore == state.opponentScore &&
            state.penaltyPlayerScore > state.penaltyOpponentScore);
    final mvp = state.roundResults
        .where(
          (round) =>
              round.outcome == RoundOutcome.goal && round.playerAttacking,
        )
        .map((round) => round.attackerCard)
        .firstOrNull;
    return GameScaffold(
      title: 'Final Result',
      subtitle: '// Archive Complete',
      leading: IconButton(
        onPressed: () {
          context.read<GameBloc>().add(MatchReset());
          onNavigate(AppSection.home);
        },
        icon: const Icon(Icons.close),
      ),
      child: Stack(
        children: [
          PhaseList(
            children: [
              ScoreboardPanel(state: state, label: 'FINAL'),
              InfoPanel(
                icon: won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                title: won ? 'Match Won' : 'Match Lost',
                body:
                    'Regular score ${state.playerScore}-${state.opponentScore}${state.penaltyKicks.isNotEmpty ? '\nPenalties ${state.penaltyPlayerScore}-${state.penaltyOpponentScore}' : ''}',
              ),
              if (mvp != null) CyberPlayerCardTile(card: mvp, selected: true),
              Text('Round Log', style: Theme.of(context).textTheme.titleLarge),
              for (final round in state.roundResults)
                ListTile(
                  leading: CircleAvatar(child: Text('${round.round}')),
                  title: Text(
                    '${round.scenario.title}: ${outcomeLabel(round.outcome)}',
                  ),
                  subtitle: Text(
                    round.playerAttacking ? 'You attacked' : 'You defended',
                  ),
                ),
              FilledButton.icon(
                onPressed: () {
                  context.read<GameBloc>().add(MatchStarted());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Rematch'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<GameBloc>().add(MatchReset());
                  onNavigate(AppSection.home);
                },
                icon: const Icon(Icons.home),
                label: const Text('Home'),
              ),
            ],
          ),
          const TutorialTip(keyName: 'final', steps: finalTutorialSteps),
        ],
      ),
    );
  }
}

Future<bool> showCyberConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: CyberConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    ),
  );
  return confirmed ?? false;
}

void _showMatchHistoryArchive(
  BuildContext context,
  List<MatchHistoryEntry> history,
) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => _MatchHistoryArchivePage(history: history),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

void _showMatchHistoryDetail(BuildContext context, MatchHistoryEntry entry) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => _MatchHistoryDetailPage(entry: entry),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _MatchHistoryArchivePage extends StatelessWidget {
  const _MatchHistoryArchivePage({required this.history});

  final List<MatchHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MATCH ARCHIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Cyber.cyan),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Text(
                'Recent finished matches are stored locally on this device.',
                style: TextStyle(
                  color: Cyber.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? const Center(
                      child: Text(
                        'No archived matches yet.',
                        style: TextStyle(
                          color: Color(0xffd1d5db),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: history.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        return MatchHistoryTile(
                          entry: entry,
                          onTap: () => _showMatchHistoryDetail(context, entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchHistoryDetailPage extends StatelessWidget {
  const _MatchHistoryDetailPage({required this.entry});

  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.deckName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Cyber.cyan),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CyberChip(
                    label: entry.resultLabel,
                    color: switch (entry.resultLabel) {
                      'Victory' => Cyber.lime,
                      'Defeat' => Cyber.red,
                      _ => Cyber.amber,
                    },
                  ),
                  CyberChip(
                    label: '${entry.playerScore}-${entry.opponentScore}',
                    color: Cyber.cyan,
                  ),
                  if (entry.penaltyPlayerScore != null)
                    CyberChip(
                      label:
                          'PEN ${entry.penaltyPlayerScore}-${entry.penaltyOpponentScore}',
                      color: Cyber.violet,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                _historyTimestampLabel(entry.timestampIso),
                style: const TextStyle(
                  color: Cyber.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: SectionLabel(label: 'Round Log'),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: entry.rounds.length,
                separatorBuilder: (_, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final round = entry.rounds[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Cyber.bg.withValues(alpha: 0.4),
                      border: Border.all(color: Cyber.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Cyber.cyan.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Cyber.cyan.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            '${round.round}',
                            style: const TextStyle(
                              color: Cyber.cyan,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                round.scenarioTitle.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${round.playerAttacking ? 'You attacked' : 'You defended'} · ${round.outcomeLabel}',
                                style: const TextStyle(
                                  color: Cyber.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _historyTimestampLabel(String timestampIso) {
  final stamp = DateTime.tryParse(timestampIso)?.toLocal();
  if (stamp == null) return 'Unknown time';
  final month = switch (stamp.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  final hour = stamp.hour % 12 == 0 ? 12 : stamp.hour % 12;
  final minute = stamp.minute.toString().padLeft(2, '0');
  final meridiem = stamp.hour >= 12 ? 'PM' : 'AM';
  return '$month ${stamp.day}, ${stamp.year}  $hour:$minute $meridiem';
}

class CyberConfirmDialog extends StatelessWidget {
  const CyberConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? Cyber.red : Cyber.cyan;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: CyberPanel(
          accent: destructive ? Cyber.magenta : Cyber.cyan,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: accent,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          destructive ? 'WARNING' : 'CONFIRM',
                          style: TextStyle(
                            color: accent,
                            fontFamily: 'Orbitron',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xff9aa8bb),
                        fontFamily: 'Onest',
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const HudLine(),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: _CyberDialogAction(
                        label: cancelLabel,
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff1e2538)),
                    Expanded(
                      child: _CyberDialogAction(
                        label: '$confirmLabel >',
                        color: accent,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyberDialogAction extends StatelessWidget {
  const _CyberDialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Build a valid deck with 2 attackers, 2 defenders, and 6 action cards.',
      'Win or lose the toss to decide the first-round role.',
      'Each round reveals a scenario bonus, then you choose one player and one legal action.',
      'Goals are decided by rating, action power, scenario bonus, a hidden roll, and risk checks.',
      'After four rounds, tied games go to a three-kick shootout plus sudden death.',
    ];
    return GameScaffold(
      title: 'How to Play',
      subtitle: '// Match Rules and Deck Guide',
      leading: IconButton(
        onPressed: () => onNavigate(AppSection.home),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoPanel(
            icon: Icons.menu_book,
            title: 'Know the Match Loop',
            body:
                'Pitch Duel mirrors the web UI flow: build a legal five-a-side deck, read the round scenario, then commit one player card and one action card at a time.',
          ),
          const SizedBox(height: 16),
          CyberPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(label: 'Round Flow'),
                const SizedBox(height: 8),
                for (var i = 0; i < steps.length; i++) ...[
                  ProcedureStepTile(index: i + 1, body: steps[i]),
                  if (i < steps.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const UseCasesPanel(),
          const SizedBox(height: 16),
          const FeaturesPanel(),
        ],
      ),
    );
  }
}

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.showShop = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showShop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReactHeaderBar(
        title: title,
        subtitle: subtitle,
        onBack: leading == null ? null : () => Navigator.maybePop(context),
        leftSlot: leading,
        showShop: showShop,
      ),
      body: CyberBackground(child: child),
    );
  }
}

class ReactHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const ReactHeaderBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.leftSlot,
    this.rightSlot,
    this.showShop = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leftSlot;
  final Widget? rightSlot;
  final bool showShop;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0b1120), Color(0xff070b14)],
          ),
          border: Border(bottom: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Row(
          children: [
            if (leftSlot != null)
              SizedBox(width: 42, height: 42, child: leftSlot)
            else if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Cyber.cyan,
              ),
            if (leftSlot != null || onBack != null) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '/',
                        style: TextStyle(
                          color: Cyber.cyan,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Cyber.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (showShop) ...[
              HeaderShopButton(onTap: () => showShopDialog(context)),
              const SizedBox(width: 8),
            ],
            ?rightSlot,
          ],
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: HudLine(),
      ),
    );
  }
}

class HeaderShopButton extends StatelessWidget {
  const HeaderShopButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Cyber.cyan.withValues(alpha: 0.08),
          border: Border.all(color: Cyber.cyan.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Cyber.cyan.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: -6,
            ),
          ],
        ),
        child: const Text(
          'SHOP',
          style: TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Onest',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

class ShopPackOption {
  const ShopPackOption({
    required this.id,
    required this.name,
    required this.coins,
    required this.gradient,
  });

  final String id;
  final String name;
  final int coins;
  final LinearGradient gradient;
}

const shopPacks = [
  ShopPackOption(
    id: 'bronze',
    name: 'Bronze Pack',
    coins: 10,
    gradient: LinearGradient(
      colors: [Color(0xff855332), Color(0xffc07a45), Color(0xff3a2519)],
    ),
  ),
  ShopPackOption(
    id: 'silver',
    name: 'Silver Pack',
    coins: 50,
    gradient: LinearGradient(
      colors: [Color(0xff657080), Color(0xffd9e2ef), Color(0xff485160)],
    ),
  ),
  ShopPackOption(
    id: 'gold',
    name: 'Gold Pack',
    coins: 250,
    gradient: LinearGradient(
      colors: [Color(0xff9b6418), Color(0xffffd23d), Color(0xff7a4108)],
    ),
  ),
  ShopPackOption(
    id: 'platinum',
    name: 'Platinum Pack',
    coins: 1000,
    gradient: LinearGradient(
      colors: [
        Color(0xff25365a),
        Color(0xffc9f7ff),
        Color(0xffba6eff),
        Color(0xff10182e),
      ],
    ),
  ),
];

void showShopDialog(BuildContext context) {
  final bloc = context.read<GameBloc>();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => BlocProvider.value(
        value: bloc,
        child: const _ShopPage(),
      ),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

void showTutorialNow(
  BuildContext context, {
  required String keyName,
  required List<TutorialStepData> steps,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => BlocProvider.value(
      value: context.read<GameBloc>(),
      child: TutorialDialog(keyName: keyName, steps: steps, force: true),
    ),
  );
}

class _ShopPage extends StatefulWidget {
  const _ShopPage();

  @override
  State<_ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<_ShopPage> {
  ShopPackOption? openingPack;
  PlayerCard? revealedCard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.55),
            radius: 0.75,
            colors: [
              Cyber.cyan.withValues(alpha: 0.18),
              const Color(0xe603050a),
              const Color(0xf003050a),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: openingPack == null
                          ? _ShopPackPicker(onOpen: _openPack)
                          : _ShopOpeningStage(
                              pack: openingPack!,
                              card: revealedCard!,
                              onBack: () => setState(() {
                                openingPack = null;
                                revealedCard = null;
                              }),
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Cyber.cyan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPack(ShopPackOption pack) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (ctx, a, b) => PackOpeningScreen(
          pack: pack,
          onComplete: () => developer.log('Pack opening animation completed'),
        ),
        transitionsBuilder: (ctx, animation, b, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

class _ShopPackPicker extends StatelessWidget {
  const _ShopPackPicker({required this.onOpen});

  final ValueChanged<ShopPackOption> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 42, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARD SHOP',
                        style: TextStyle(
                          color: Cyber.cyan.withValues(alpha: 0.62),
                          fontFamily: 'Onest',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'CHOOSE PACK',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.style, color: Cyber.cyan, size: 34),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: shopPacks.length,
            itemBuilder: (_, index) {
              final pack = shopPacks[index];
              return ShopPackCard(pack: pack, onTap: () => onOpen(pack));
            },
          ),
        ],
      ),
    );
  }
}

class ShopPackCard extends StatelessWidget {
  const ShopPackCard({required this.pack, required this.onTap, super.key});

  final ShopPackOption pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: CyberClipper(),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: pack.gradient,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 26),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.24),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Cyber.bg.withValues(alpha: 0.38),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(Icons.style, color: Colors.white, size: 24),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 34,
              child: Text(
                pack.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 15,
              child: Text(
                '${pack.coins} COINS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'Onest',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopOpeningStage extends StatelessWidget {
  const _ShopOpeningStage({
    required this.pack,
    required this.card,
    required this.onBack,
  });

  final ShopPackOption pack;
  final PlayerCard card;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 560,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _PackBurst(),
          Positioned(top: 58, child: ShopPackVisual(pack: pack)),
          Positioned(
            top: 32,
            child: Column(
              children: [
                Text(
                  '${pack.name} Opened'.toUpperCase(),
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.72),
                    fontFamily: 'Onest',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 192),
                CyberPlayerCardTile(
                  card: card,
                  selected: true,
                  size: VisualCardSize.md,
                ),
                const SizedBox(height: 14),
                Text(
                  card.name.toUpperCase(),
                  style: const TextStyle(
                    color: Cyber.cyan,
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ADDED TO YOUR CARDS',
                  style: TextStyle(
                    color: Cyber.lime,
                    fontFamily: 'Onest',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.1,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: onBack,
                  child: const Text('CHOOSE ANOTHER PACK'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShopPackVisual extends StatelessWidget {
  const ShopPackVisual({required this.pack, super.key});

  final ShopPackOption pack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 198,
      height: 282,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: pack.gradient,
                border: Border.all(
                  color: Cyber.amber.withValues(alpha: 0.86),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.amber.withValues(alpha: 0.42),
                    blurRadius: 28,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: CardStripePainter(color: Colors.white)),
          ),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.42),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.style, color: Cyber.bg, size: 34),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.26),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                  stops: const [0, 0.18, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialTip extends StatefulWidget {
  const TutorialTip({
    required this.keyName,
    required this.steps,
    this.forceToken = 0,
    super.key,
  });

  final String keyName;
  final List<TutorialStepData> steps;
  final int forceToken;

  @override
  State<TutorialTip> createState() => _TutorialTipState();
}

class _TutorialTipState extends State<TutorialTip> {
  bool _scheduled = false;
  int _lastForceToken = 0;

  @override
  void initState() {
    super.initState();
    _lastForceToken = widget.forceToken;
    _maybeSchedule();
  }

  @override
  void didUpdateWidget(covariant TutorialTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final forced = widget.forceToken != _lastForceToken;
    if (forced) {
      _lastForceToken = widget.forceToken;
      _scheduled = false;
      _schedule(force: true);
      return;
    }
    _maybeSchedule();
  }

  void _maybeSchedule() {
    // Schedule tutorial automatically if not yet seen (first launch experience)
    // This creates the guided walkthrough for new players
    if (!_scheduled && widget.steps.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Check if this tutorial has been seen by reading from GameBloc state
        final gameState = context.read<GameBloc>().state;
        if (!gameState.tutorialSeen.contains(widget.keyName)) {
          _schedule(force: false);
        }
      });
    }
  }

  void _schedule({bool force = false}) {
    if (_scheduled || widget.steps.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        builder: (_) => BlocProvider.value(
          value: context.read<GameBloc>(),
          child: TutorialDialog(
            keyName: widget.keyName,
            steps: widget.steps,
            force: force,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({
    required this.keyName,
    required this.steps,
    this.force = false,
    super.key,
  });

  final String keyName;
  final List<TutorialStepData> steps;
  final bool force;

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[index];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: CyberPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Cyber.cyan,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Cyber.cyan, blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '▸ ONBOARDING · ${(index + 1).toString().padLeft(2, '0')}/${widget.steps.length.toString().padLeft(2, '0')}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Cyber.cyan,
                      fontFamily: 'Onest',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                TextButton(onPressed: _skipAll, child: const Text('SKIP ALL')),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step.title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              step.body,
              style: const TextStyle(
                color: Color(0xffd1d5db),
                fontFamily: 'Onest',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: i == widget.steps.length - 1 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: i == index
                            ? Cyber.cyan
                            : i < index
                            ? Cyber.cyan.withValues(alpha: 0.42)
                            : const Color(0xff1e2538),
                        boxShadow: i == index
                            ? [
                                BoxShadow(
                                  color: Cyber.cyan.withValues(alpha: 0.7),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const HudLine(),
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => index--),
                      child: const Text('◄ BACK'),
                    ),
                  ),
                Expanded(
                  child: TextButton(
                    onPressed: _next,
                    child: Text(
                      index < widget.steps.length - 1 ? 'NEXT ▸' : 'GOT IT ▸',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (index < widget.steps.length - 1) {
      setState(() => index++);
      return;
    }
    context.read<GameBloc>().add(TutorialSeenMarked(widget.keyName));
    Navigator.pop(context);
  }

  void _skipAll() {
    context.read<GameBloc>().add(TutorialsSkippedAll());
    Navigator.pop(context);
  }
}

class _PackBurst extends StatelessWidget {
  const _PackBurst();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 310,
      child: Stack(
        children: [
          for (var i = 0; i < 12; i++)
            Positioned.fill(
              child: Transform.rotate(
                angle: i * pi / 6,
                child: Align(
                  alignment: const Alignment(0, -0.38),
                  child: Container(
                    width: 3,
                    height: 126,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Cyber.amber.withValues(alpha: 0.95),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Cyber.amber.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CyberBackground extends StatelessWidget {
  const CyberBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: CyberGridPainter())),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, -0.75),
                radius: 1.1,
                colors: [
                  Cyber.cyan.withValues(alpha: 0.12),
                  Cyber.violet.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class CyberGridPainter extends CustomPainter {
  const CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cyber.bg);
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HudLine extends StatelessWidget {
  const HudLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Cyber.cyan.withValues(alpha: 0.9),
            Cyber.magenta.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class PhaseList extends StatelessWidget {
  const PhaseList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, index) => children[index],
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemCount: children.length,
    );
  }
}

class MatchPhaseScaffold extends StatelessWidget {
  const MatchPhaseScaffold({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.children,
    required this.onQuit,
    this.scoreLabel,
    this.tutorialKey,
    this.tutorialSteps = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final GameState state;
  final List<Widget> children;
  final VoidCallback onQuit;
  final String? scoreLabel;
  final String? tutorialKey;
  final List<TutorialStepData> tutorialSteps;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: title,
      subtitle: subtitle,
      showShop: false,
      leading: IconButton(
        onPressed: onQuit,
        icon: const Icon(Icons.close, color: Cyber.cyan),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              ScoreboardPanel(state: state, label: scoreLabel),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, index) => children[index],
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemCount: children.length,
                ),
              ),
            ],
          ),
          if (tutorialKey != null)
            TutorialTip(keyName: tutorialKey!, steps: tutorialSteps),
        ],
      ),
    );
  }
}

class RoleStrip extends StatelessWidget {
  const RoleStrip({required this.attacking, super.key});

  final bool attacking;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: attacking ? Cyber.lime : Cyber.cyan,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            attacking ? Icons.sports_soccer : Icons.shield,
            color: attacking ? Cyber.lime : Cyber.cyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'YOU // ${attacking ? 'ATTACKING' : 'DEFENDING'}',
              style: TextStyle(
                color: attacking ? Cyber.lime : Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          const HiddenCard(),
          const SizedBox(width: 8),
          const HiddenCard(),
        ],
      ),
    );
  }
}

class HiddenCard extends StatelessWidget {
  const HiddenCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Cyber.red, Cyber.panel]),
        border: Border.all(color: Cyber.red.withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.style, color: Cyber.red, size: 16),
    );
  }
}

class SelectedMovePanel extends StatelessWidget {
  const SelectedMovePanel({
    required this.player,
    required this.action,
    required this.estimate,
    super.key,
  });

  final PlayerCard? player;
  final ActionCard? action;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Row(
        children: [
          Expanded(
            child: _MoveSlot(
              label: 'PLAYER',
              value: player?.name ?? 'Select card',
              color: Cyber.cyan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MoveSlot(
              label: 'ACTION',
              value: action?.title ?? 'Select action',
              color: Cyber.magenta,
            ),
          ),
          const SizedBox(width: 10),
          CyberChip(
            label: estimate == null ? 'EST --' : 'EST $estimate',
            color: Cyber.lime,
          ),
        ],
      ),
    );
  }
}

class _MoveSlot extends StatelessWidget {
  const _MoveSlot({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.45),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class CyberCtaButton extends StatelessWidget {
  const CyberCtaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary
        ? const LinearGradient(colors: [Cyber.cyan, Color(0xff5cb4ff)])
        : LinearGradient(colors: [Cyber.panel2, Cyber.panel]);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipPath(
          clipper: CyberClipper(),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: bg,
              border: Border.all(color: primary ? Cyber.cyan : Cyber.line),
              boxShadow: [
                BoxShadow(
                  color: (primary ? Cyber.cyan : Cyber.bg).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: primary ? Cyber.bg : Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadoutStatusPanel extends StatelessWidget {
  const LoadoutStatusPanel({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '▸ LOADOUT STATUS',
            style: TextStyle(
              color: Cyber.cyan.withValues(alpha: 0.68),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  'ATK',
                  '${state.deckAttackers.length}/2',
                  state.deckAttackers.length == 2,
                ),
              ),
              Expanded(
                child: MiniStat(
                  'DEF',
                  '${state.deckDefenders.length}/2',
                  state.deckDefenders.length == 2,
                ),
              ),
              Expanded(
                child: MiniStat(
                  'ACT',
                  '${state.deckActions.length}/6',
                  state.deckActions.length == 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MatchHistoryPanel extends StatelessWidget {
  const MatchHistoryPanel({required this.history, super.key});

  final List<MatchHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final preview = history.take(3).toList();
    return CyberPanel(
      accent: Cyber.cyan,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MATCH HISTORY',
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.68),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showMatchHistoryArchive(context, history),
                child: Text(history.isEmpty ? 'OPEN' : 'VIEW ALL'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            history.isEmpty
                ? 'No completed matches yet. Finish a match and it will land here.'
                : 'Tap any result to inspect the scoreline, deck, and round log.',
            style: const TextStyle(
              color: Cyber.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (preview.isEmpty)
            GestureDetector(
              onTap: () => _showMatchHistoryArchive(context, history),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Cyber.bg.withValues(alpha: 0.38),
                  border: Border.all(color: Cyber.line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history, color: Cyber.cyan),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Archive terminal ready. Your next finished match will appear here.',
                        style: TextStyle(
                          color: Color(0xffd1d5db),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < preview.length; i++) ...[
              MatchHistoryTile(
                entry: preview[i],
                onTap: () => _showMatchHistoryDetail(context, preview[i]),
              ),
              if (i < preview.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class MatchHistoryTile extends StatelessWidget {
  const MatchHistoryTile({required this.entry, required this.onTap, super.key});

  final MatchHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (entry.resultLabel) {
      'Victory' => Cyber.lime,
      'Defeat' => Cyber.red,
      _ => Cyber.amber,
    };
    final stamp = _historyTimestampLabel(entry.timestampIso);
    final scoreline = entry.penaltyPlayerScore == null
        ? '${entry.playerScore}-${entry.opponentScore}'
        : '${entry.playerScore}-${entry.opponentScore}  PEN ${entry.penaltyPlayerScore}-${entry.penaltyOpponentScore}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.34)),
              ),
              child: Icon(Icons.query_stats, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.resultLabel.toUpperCase()} // ${entry.deckName.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$scoreline  ·  $stamp',
                    style: const TextStyle(
                      color: Cyber.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Cyber.cyan),
          ],
        ),
      ),
    );
  }
}

class UseCasesPanel extends StatelessWidget {
  const UseCasesPanel({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            label: compact ? 'Use Cases // Quick Read' : 'Use Cases',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < commonUseCases.length; i++) ...[
            AppInfoTile(item: commonUseCases[i], compact: compact),
            if (i < commonUseCases.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class FeaturesPanel extends StatelessWidget {
  const FeaturesPanel({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            label: compact ? 'Features // React Match' : 'Core Features',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < coreFeatures.length; i++) ...[
            AppInfoTile(item: coreFeatures[i], compact: compact),
            if (i < coreFeatures.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class AppInfoTile extends StatelessWidget {
  const AppInfoTile({required this.item, this.compact = false, super.key});

  final AppInfoItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border.all(color: item.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              border: Border.all(color: item.accent.withValues(alpha: 0.34)),
            ),
            child: Icon(item.icon, color: item.accent, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    color: Cyber.muted,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProcedureStepTile extends StatelessWidget {
  const ProcedureStepTile({required this.index, required this.body, super.key});

  final int index;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.cyan.withValues(alpha: 0.14),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: Cyber.cyan,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              body,
              style: const TextStyle(
                color: Color(0xffd1d5db),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MiniStat extends StatelessWidget {
  const MiniStat(this.label, this.value, this.ok, {super.key});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: ok ? Cyber.cyan : Cyber.amber,
            fontFamily: 'Orbitron',
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class DeckFocusedSelectionPanel extends StatelessWidget {
  const DeckFocusedSelectionPanel({
    required this.lane,
    required this.slotIndex,
    required this.selectedPlayer,
    required this.selectedAction,
    required this.actionFilter,
    required this.onFilterChanged,
    required this.onClear,
    required this.playerOptions,
    required this.actionOptions,
    required this.isPlayerDisabled,
    required this.isActionDisabled,
    required this.onSelectPlayer,
    required this.onSelectAction,
    super.key,
  });

  final DeckPickerLane lane;
  final int slotIndex;
  final PlayerCard? selectedPlayer;
  final ActionCard? selectedAction;
  final ActionCategory? actionFilter;
  final ValueChanged<ActionCategory?> onFilterChanged;
  final VoidCallback onClear;
  final List<PlayerCard> playerOptions;
  final List<ActionCard> actionOptions;
  final bool Function(PlayerCard card) isPlayerDisabled;
  final bool Function(ActionCard card) isActionDisabled;
  final ValueChanged<PlayerCard> onSelectPlayer;
  final ValueChanged<ActionCard> onSelectAction;

  @override
  Widget build(BuildContext context) {
    final accent = switch (lane) {
      DeckPickerLane.attacker => Cyber.lime,
      DeckPickerLane.defender => Cyber.cyan,
      DeckPickerLane.action => Cyber.magenta,
    };
    final slotLabel = switch (lane) {
      DeckPickerLane.attacker =>
        slotIndex == 0 ? 'Left Striker' : 'Right Striker',
      DeckPickerLane.defender =>
        slotIndex == 0 ? 'Left Center Back' : 'Right Center Back',
      DeckPickerLane.action => 'Action Slot ${slotIndex + 1}',
    };
    final helper = switch (lane) {
      DeckPickerLane.attacker =>
        'Choose the exact attacker for this lane. Picking a card here can swap it with the other striker slot.',
      DeckPickerLane.defender =>
        'Lock in a defender for this position. Think in pairs so the back line feels balanced.',
      DeckPickerLane.action =>
        'Fill this action slot with the exact tactic you want ready in-match. Mix categories for better coverage.',
    };
    return CyberPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SLOT PICKER',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slotLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: selectedPlayer != null || selectedAction != null
                    ? onClear
                    : null,
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                label: const Text('CLEAR'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: const TextStyle(
              color: Color(0xffd1d5db),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(switch (lane) {
                  DeckPickerLane.attacker => Icons.sports_soccer,
                  DeckPickerLane.defender => Icons.shield,
                  DeckPickerLane.action => Icons.style,
                }, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedPlayer?.name ??
                        selectedAction?.title ??
                        'No card assigned yet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (lane == DeckPickerLane.action) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: actionFilter == null,
                  label: const Text('ALL'),
                  onSelected: (_) => onFilterChanged(null),
                ),
                for (final category in ActionCategory.values)
                  FilterChip(
                    selected: actionFilter == category,
                    label: Text(category.name.toUpperCase()),
                    onSelected: (_) => onFilterChanged(category),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 340,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (lane == DeckPickerLane.action)
                    for (final card in actionOptions)
                      Opacity(
                        opacity: isActionDisabled(card) ? 0.38 : 1,
                        child: IgnorePointer(
                          ignoring: isActionDisabled(card),
                          child: CyberActionCardTile(
                            card: card,
                            selected: selectedAction?.id == card.id,
                            disabled: isActionDisabled(card),
                            size: VisualCardSize.sm,
                            onTap: () => onSelectAction(card),
                          ),
                        ),
                      )
                  else
                    for (final card in playerOptions)
                      Opacity(
                        opacity: isPlayerDisabled(card) ? 0.38 : 1,
                        child: IgnorePointer(
                          ignoring: isPlayerDisabled(card),
                          child: CyberPlayerCardTile(
                            card: card,
                            selected: selectedPlayer?.id == card.id,
                            disabled: isPlayerDisabled(card),
                            size: VisualCardSize.sm,
                            onTap: () => onSelectPlayer(card),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeckPill extends StatelessWidget {
  const DeckPill({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String meta;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Cyber.lime, Cyber.cyan])
              : const LinearGradient(colors: [Cyber.panel2, Cyber.panel]),
          border: Border.all(color: selected ? Cyber.lime : Cyber.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Cyber.bg),
              const SizedBox(width: 6),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: selected ? Cyber.bg : Colors.white,
                    fontSize: 11,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  meta,
                  style: TextStyle(
                    color: selected
                        ? Cyber.bg.withValues(alpha: 0.65)
                        : Cyber.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DeckBuilderIntelPanel extends StatelessWidget {
  const DeckBuilderIntelPanel({
    required this.editing,
    required this.valid,
    required this.missingAttackers,
    required this.missingDefenders,
    required this.missingActions,
    required this.actionAtk,
    required this.actionDef,
    required this.actionSpc,
    super.key,
  });

  final bool editing;
  final bool valid;
  final int missingAttackers;
  final int missingDefenders;
  final int missingActions;
  final int actionAtk;
  final int actionDef;
  final int actionSpc;

  @override
  Widget build(BuildContext context) {
    final statusText = valid
        ? 'Deck is match-ready. Save or launch straight into a round.'
        : 'Need $missingAttackers attackers, $missingDefenders defenders, and $missingActions actions to complete the build.';
    return CyberPanel(
      accent: valid ? Cyber.lime : Cyber.amber,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  editing ? 'BUILD WORKSPACE' : 'DECK SUMMARY',
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.72),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              CyberChip(
                label: editing ? 'Edit Mode' : (valid ? 'Ready' : 'Incomplete'),
                color: editing
                    ? Cyber.violet
                    : (valid ? Cyber.lime : Cyber.amber),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Color(0xffd1d5db),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: MiniStat('ATK ACT', '$actionAtk', actionAtk > 0)),
              Expanded(child: MiniStat('DEF ACT', '$actionDef', actionDef > 0)),
              Expanded(child: MiniStat('SPC ACT', '$actionSpc', true)),
            ],
          ),
        ],
      ),
    );
  }
}

class DeckActionWarningPanel extends StatelessWidget {
  const DeckActionWarningPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(14),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Cyber.amber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your six-card action strip is legal, but it is missing either attack or defense coverage. The React UI warns here because one-sided decks can feel brittle in live rounds.',
              style: TextStyle(
                color: Color(0xfff3f4f6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FiveSideDeckPanel extends StatelessWidget {
  const FiveSideDeckPanel({
    required this.deckName,
    required this.valid,
    required this.attackers,
    required this.defenders,
    required this.actions,
    required this.actionAtk,
    required this.actionDef,
    required this.actionSpc,
    required this.focusedLane,
    required this.focusedIndex,
    required this.editing,
    required this.onAttackTap,
    required this.onDefenseTap,
    required this.onActionTap,
    super.key,
  });

  final String deckName;
  final bool valid;
  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final List<ActionCard> actions;
  final int actionAtk;
  final int actionDef;
  final int actionSpc;
  final DeckPickerLane focusedLane;
  final int focusedIndex;
  final bool editing;
  final ValueChanged<int> onAttackTap;
  final ValueChanged<int> onDefenseTap;
  final ValueChanged<int> onActionTap;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5-A-SIDE DECK',
                      style: TextStyle(
                        color: Cyber.cyan.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deckName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              CyberChip(
                label: valid ? 'Ready' : 'Build',
                color: valid ? Cyber.lime : Cyber.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FiveSidePitch(
            attackers: attackers,
            defenders: defenders,
            editing: editing,
            focusedAttackerIndex: focusedLane == DeckPickerLane.attacker
                ? focusedIndex
                : null,
            focusedDefenderIndex: focusedLane == DeckPickerLane.defender
                ? focusedIndex
                : null,
            onAttackTap: onAttackTap,
            onDefenseTap: onDefenseTap,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '6 ACTION CARDS',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const Spacer(),
              Text(
                'ATK $actionAtk / DEF $actionDef / SPC $actionSpc',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.45),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final card = index < actions.length ? actions[index] : null;
                if (card == null) {
                  return EmptyActionSlot(
                    highlighted:
                        editing &&
                        focusedLane == DeckPickerLane.action &&
                        focusedIndex == index,
                    onTap: () => onActionTap(index),
                  );
                }
                return CyberActionCardTile(
                  card: card,
                  selected:
                      editing &&
                      focusedLane == DeckPickerLane.action &&
                      focusedIndex == index,
                  onTap: () => onActionTap(index),
                  size: VisualCardSize.sm,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FiveSidePitch extends StatelessWidget {
  const FiveSidePitch({
    required this.attackers,
    required this.defenders,
    required this.editing,
    required this.focusedAttackerIndex,
    required this.focusedDefenderIndex,
    required this.onAttackTap,
    required this.onDefenseTap,
    super.key,
  });

  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final bool editing;
  final int? focusedAttackerIndex;
  final int? focusedDefenderIndex;
  final ValueChanged<int> onAttackTap;
  final ValueChanged<int> onDefenseTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 390,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff073222), Color(0xff061b22), Color(0xff08111d)],
        ),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: PitchPainter())),
          Positioned(
            left: 34,
            top: 28,
            child: FormationSlot(
              label: 'LS',
              card: attackers.firstOrNull,
              highlighted: editing && focusedAttackerIndex == 0,
              onTap: () => onAttackTap(0),
            ),
          ),
          Positioned(
            right: 34,
            top: 28,
            child: FormationSlot(
              label: 'RS',
              card: attackers.length > 1 ? attackers[1] : null,
              highlighted: editing && focusedAttackerIndex == 1,
              onTap: () => onAttackTap(1),
            ),
          ),
          Positioned(
            left: 34,
            top: 158,
            child: FormationSlot(
              label: 'LCB',
              card: defenders.firstOrNull,
              highlighted: editing && focusedDefenderIndex == 0,
              onTap: () => onDefenseTap(0),
            ),
          ),
          Positioned(
            right: 34,
            top: 158,
            child: FormationSlot(
              label: 'RCB',
              card: defenders.length > 1 ? defenders[1] : null,
              highlighted: editing && focusedDefenderIndex == 1,
              onTap: () => onDefenseTap(1),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 22, child: KeeperCore()),
        ],
      ),
    );
  }
}

class FormationSlot extends StatelessWidget {
  const FormationSlot({
    required this.label,
    required this.card,
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final String label;
  final PlayerCard? card;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (card != null) {
      return CyberPlayerCardTile(
        card: card!,
        selected: highlighted,
        onTap: onTap,
        size: VisualCardSize.sm,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 144,
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.58),
          border: Border.all(
            color: highlighted
                ? Cyber.lime.withValues(alpha: 0.85)
                : Cyber.cyan.withValues(alpha: 0.45),
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Cyber.lime.withValues(alpha: 0.24),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label.contains('S') ? Icons.sports_soccer : Icons.shield,
              color: highlighted ? Cyber.lime : Cyber.cyan,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ADD CARD',
              style: TextStyle(color: Cyber.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class KeeperCore extends StatelessWidget {
  const KeeperCore({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Cyber.magenta.withValues(alpha: 0.16),
          border: Border.all(color: Cyber.magenta.withValues(alpha: 0.65)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GK',
              style: TextStyle(
                color: Cyber.magenta,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
              ),
            ),
            Icon(Icons.back_hand, color: Cyber.magenta, size: 28),
            Text(
              'KEEPER CORE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyActionSlot extends StatelessWidget {
  const EmptyActionSlot({
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 96,
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.65),
          border: Border.all(
            color: highlighted ? Cyber.lime : Cyber.line,
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Cyber.lime.withValues(alpha: 0.18),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, color: Cyber.cyan),
            SizedBox(height: 6),
            Text(
              'ADD\nACTION',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cyber.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectionWrap<T> extends StatelessWidget {
  const SelectionWrap({
    required this.cards,
    required this.selectedIds,
    required this.enabled,
    required this.builder,
    required this.onToggle,
    required this.isDisabled,
    super.key,
  });

  final List<T> cards;
  final List<String> selectedIds;
  final bool enabled;
  final Widget Function(T card, bool selected, bool disabled) builder;
  final ValueChanged<T> onToggle;
  final bool Function(T card) isDisabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final card in cards)
            GestureDetector(
              onTap: enabled ? () => onToggle(card) : null,
              child: builder(
                card,
                selectedIds.contains(switch (card) {
                  PlayerCard c => c.id,
                  ActionCard c => c.id,
                  _ => '',
                }),
                isDisabled(card),
              ),
            ),
        ],
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.primaryOnTap,
    required this.secondaryLabel,
    required this.secondaryOnTap,
    super.key,
  });

  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback primaryOnTap;
  final String secondaryLabel;
  final VoidCallback secondaryOnTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Row(
          children: [
            Expanded(
              child: CyberCtaButton(
                label: secondaryLabel,
                onPressed: secondaryOnTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CyberCtaButton(
                label: primaryLabel,
                primary: true,
                onPressed: primaryEnabled ? primaryOnTap : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PitchPainter extends CustomPainter {
  const PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(16, size.height * 0.26),
      Offset(size.width - 16, size.height * 0.26),
      paint,
    );
    canvas.drawLine(
      Offset(16, size.height * 0.54),
      Offset(size.width - 16, size.height * 0.54),
      paint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.54), 44, paint);
    canvas.drawRect(
      Rect.fromLTWH(20, 18, size.width - 40, size.height - 36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.55)),
              gradient: RadialGradient(
                colors: [Cyber.cyan.withValues(alpha: 0.25), Cyber.panel2],
              ),
            ),
            child: Icon(icon, size: 28, color: Cyber.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Cyber.cyan,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: Cyber.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Cyber.panelGradient(accent),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class CyberClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const cut = 12.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ScoreboardPanel extends StatelessWidget {
  const ScoreboardPanel({required this.state, this.label, super.key});

  final GameState state;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff070b14), Color(0xff111827), Color(0xff070b14)],
        ),
        border: Border(
          top: BorderSide(color: Cyber.cyan.withValues(alpha: 0.28)),
          bottom: BorderSide(color: Cyber.red.withValues(alpha: 0.32)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _HudIdentity(
              label: '[P1] YOU',
              score: state.playerScore,
              color: Cyber.cyan,
              alignRight: false,
            ),
          ),
          Column(
            children: [
              Text(
                label ?? 'RN ${max(1, state.currentRound)}/4',
                style: const TextStyle(
                  color: Cyber.muted,
                  fontSize: 10,
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '— VS —',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Expanded(
            child: _HudIdentity(
              label: 'CPU [E1]',
              score: state.opponentScore,
              color: Cyber.red,
              alignRight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudIdentity extends StatelessWidget {
  const _HudIdentity({
    required this.label,
    required this.score,
    required this.color,
    required this.alignRight,
  });

  final String label;
  final int score;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Onest',
              fontWeight: FontWeight.w900,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class CardList<T> extends StatelessWidget {
  const CardList({
    required this.cards,
    required this.selectedIds,
    required this.builder,
    required this.onToggle,
    required this.enabled,
    super.key,
  });

  final List<T> cards;
  final List<String> selectedIds;
  final Widget Function(T card, bool selected) builder;
  final ValueChanged<T> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final card = cards[index];
        final id = switch (card) {
          PlayerCard c => c.id,
          ActionCard c => c.id,
          _ => '',
        };
        return Opacity(
          opacity: enabled ? 1 : 0.72,
          child: InkWell(
            onTap: enabled ? () => onToggle(card) : null,
            child: builder(card, selectedIds.contains(id)),
          ),
        );
      },
    );
  }
}

enum VisualCardSize { sm, md }

class CyberPlayerCardTile extends StatelessWidget {
  const CyberPlayerCardTile({
    required this.card,
    required this.selected,
    this.disabled = false,
    this.size = VisualCardSize.sm,
    this.onTap,
    super.key,
  });

  final PlayerCard card;
  final bool selected;
  final bool disabled;
  final VisualCardSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tier = tierColor(card.tier);
    final small = size == VisualCardSize.sm;
    final width = small ? 96.0 : 128.0;
    final height = small ? 144.0 : 192.0;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? Cyber.cyan : tier, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff0f1623), Cyber.panel, Cyber.bg2],
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? Cyber.cyan : tier).withValues(alpha: 0.3),
                blurRadius: selected ? 22 : 12,
              ),
            ],
          ),
          child: ClipPath(
            clipper: CyberClipper(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: CardStripePainter(color: tier)),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  top: 4,
                  bottom: height * 0.24,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xfff7f7f4),
                          Colors.white,
                          tier,
                          const Color(0xff111827),
                          Cyber.red,
                        ],
                        stops: const [0, 0.40, 0.54, 0.72, 1],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        card.icon,
                        size: small ? 42 : 64,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: small ? 36 : 44,
                    height: small ? 30 : 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white, tier]),
                      border: const Border(
                        left: BorderSide(color: Colors.black54, width: 2),
                        bottom: BorderSide(color: Colors.black54, width: 2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${card.rating}',
                          style: TextStyle(
                            color: Cyber.bg,
                            fontFamily: 'Orbitron',
                            fontSize: small ? 12 : 15,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                          ),
                        ),
                        const Text(
                          'OVR',
                          style: TextStyle(
                            color: Cyber.bg,
                            fontSize: 5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: Colors.black.withValues(alpha: 0.58),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playerRoleLabel(card),
                          style: TextStyle(
                            color: tier,
                            fontFamily: 'Orbitron',
                            fontSize: small ? 6 : 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          card.countryCode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: small ? 5 : 6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: height * 0.24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    color: Colors.black.withValues(alpha: 0.64),
                    child: Text(
                      card.trait,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: small ? 7 : 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height * 0.24,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff202836), Color(0xff121824)],
                      ),
                    ),
                    child: Text(
                      card.shortName,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: small ? 9 : 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CyberActionCardTile extends StatelessWidget {
  const CyberActionCardTile({
    required this.card,
    required this.selected,
    this.disabled = false,
    this.size = VisualCardSize.sm,
    this.onTap,
    super.key,
  });

  final ActionCard card;
  final bool selected;
  final bool disabled;
  final VisualCardSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = actionColor(card.category);
    final small = size == VisualCardSize.sm;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.3 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: small ? 80 : 96,
          height: small ? 96 : 128,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Cyber.cyan
                  : (card.risky ? Cyber.magenta : color),
              width: selected ? 2 : 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.2), Cyber.panel, Cyber.bg2],
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? Cyber.cyan : color).withValues(alpha: 0.24),
                blurRadius: selected ? 16 : 8,
              ),
            ],
          ),
          child: ClipPath(
            clipper: CyberClipper(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    color: color,
                    child: Text(
                      actionCode(card.category),
                      style: const TextStyle(
                        color: Cyber.bg,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    color: Cyber.panel,
                    child: Text(
                      '+${card.power}',
                      style: const TextStyle(
                        color: Cyber.cyan,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(card.icon, color: color, size: small ? 20 : 24),
                      Text(
                        card.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        card.effect,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.76),
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (card.risky)
                  const Positioned(
                    bottom: 3,
                    left: 3,
                    child: Icon(
                      Icons.warning_amber,
                      color: Cyber.red,
                      size: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CyberChip extends StatelessWidget {
  const CyberChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontFamily: 'Onest',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class CardStripePainter extends CustomPainter {
  const CardStripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.11)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CardStripePainter oldDelegate) =>
      oldDelegate.color != color;
}

class PlayerCardTile extends StatelessWidget {
  const PlayerCardTile({
    required this.card,
    required this.selected,
    this.onTap,
    super.key,
  });

  final PlayerCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: tierColor(card.tier),
          child: Icon(card.icon, color: Colors.black),
        ),
        title: Text(
          card.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${card.countryCode} · ${card.trait} · ${card.position}'),
        trailing: Text(
          '${card.rating}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class ActionCardTile extends StatelessWidget {
  const ActionCardTile({
    required this.card,
    required this.selected,
    this.onTap,
    super.key,
  });

  final ActionCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(card.icon)),
        title: Text(
          card.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${card.category.name.toUpperCase()} • ${card.effect}${card.risky ? ' • Risky' : ''}',
        ),
        trailing: Text(
          '+${card.power}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Cyber.cyan.withValues(alpha: 0.18)
            : Cyber.panel,
        foregroundColor: selected ? Cyber.cyan : Cyber.muted,
        side: BorderSide(color: selected ? Cyber.cyan : Cyber.line),
      ),
      child: Text(label),
    );
  }
}

String playerRoleLabel(PlayerCard card) => switch (card.role) {
  PlayerRole.attacker => 'ATK',
  PlayerRole.defender => 'DEF',
  PlayerRole.goalkeeper => 'GK',
};

Color tierColor(CardTier tier) => switch (tier) {
  CardTier.bronze => const Color(0xffcd7f32),
  CardTier.silver => const Color(0xffcbd5e1),
  CardTier.gold => const Color(0xfffacc15),
  CardTier.platinum => const Color(0xff67e8f9),
};

Color actionColor(ActionCategory category) => switch (category) {
  ActionCategory.attack => Cyber.lime,
  ActionCategory.defense => Cyber.cyan,
  ActionCategory.special => Cyber.magenta,
};

String actionCode(ActionCategory category) => switch (category) {
  ActionCategory.attack => 'ATK',
  ActionCategory.defense => 'DEF',
  ActionCategory.special => 'SPC',
};

IconData outcomeIcon(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => Icons.sports_soccer,
  RoundOutcome.saved => Icons.pan_tool,
  RoundOutcome.blocked => Icons.block,
  RoundOutcome.missed => Icons.close,
  RoundOutcome.foul => Icons.flag,
  RoundOutcome.redCard => Icons.style,
};

String outcomeLabel(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => 'Goal',
  RoundOutcome.saved => 'Saved',
  RoundOutcome.blocked => 'Blocked',
  RoundOutcome.missed => 'Missed',
  RoundOutcome.foul => 'Foul',
  RoundOutcome.redCard => 'Red Card',
};

// FIFA-style pack opening animation screen
class PackOpeningScreen extends StatefulWidget {
  const PackOpeningScreen({
    required this.pack,
    required this.onComplete,
    this.cards,
    super.key,
  });

  final ShopPackOption pack;
  final VoidCallback onComplete;
  final List<PlayerCard>? cards;

  @override
  State<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends State<PackOpeningScreen>
    with TickerProviderStateMixin {
  late AnimationController _packBurstController;
  late AnimationController _cardsEntryController;
  late List<AnimationController> _cardFlipControllers;
  late List<AnimationController> _rarityEffectControllers;
  late List<AnimationController> _shakeControllers;
  late AnimationController _doneButtonController;
  late AnimationController _completionController;
  late List<PlayerCard> _revealedCards;
  late List<bool> _cardRevealed;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _revealedCards = [];
    _cardRevealed = [];
    _cardFlipControllers = [];
    _rarityEffectControllers = [];
    _shakeControllers = [];

    if (widget.cards != null && widget.cards!.length == 5) {
      _revealedCards.addAll(widget.cards!);
    } else {
      for (int i = 0; i < 5; i++) {
        _revealedCards.add(_pickPackCard(widget.pack.id));
      }
    }

    for (int i = 0; i < 5; i++) {
      _cardRevealed.add(false);
    }

    _packBurstController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _cardsEntryController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _doneButtonController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _completionController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    for (int i = 0; i < 5; i++) {
      _cardFlipControllers.add(
        AnimationController(duration: const Duration(milliseconds: 700), vsync: this),
      );
      _rarityEffectControllers.add(
        AnimationController(duration: const Duration(milliseconds: 900), vsync: this),
      );
      _shakeControllers.add(
        AnimationController(duration: const Duration(milliseconds: 400), vsync: this),
      );
    }

    _startPackOpeningSequence();
  }

  void _startPackOpeningSequence() async {
    await _packBurstController.forward();
    await _cardsEntryController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Stagger auto-reveal: fire each card 200ms apart, don't await so they can overlap
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      _revealCard(i); // intentionally fire-and-forget
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _revealCard(int index) async {
    if (_cardRevealed[index] || !mounted) return;
    final card = _revealedCards[index];

    // Higher rarity cards get a dramatic pre-pause before shaking
    final preDelay = switch (card.tier) {
      CardTier.bronze => Duration.zero,
      CardTier.silver => const Duration(milliseconds: 300),
      CardTier.gold => const Duration(milliseconds: 700),
      CardTier.platinum => const Duration(milliseconds: 1200),
    };
    if (preDelay > Duration.zero) {
      await Future<void>.delayed(preDelay);
      if (!mounted) return;
    }

    // Shake to build anticipation
    _shakeControllers[index].forward();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Flip to reveal
    setState(() => _cardRevealed[index] = true);
    _shakeControllers[index]
      ..stop()
      ..reset();
    await _cardFlipControllers[index].forward();
    if (!mounted) return;

    // Rarity glow burst
    _rarityEffectControllers[index].forward();
    developer.log('SoundManager.play("${card.tier.name}_reveal")');

    // Pack complete flourish after last card
    if (_allCardsRevealed) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _doneButtonController.forward();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) _completionController.forward();
    }
  }

  PlayerCard _pickPackCard(String _) {
    final roll = _random.nextDouble();
    final tier = roll < 0.50
        ? CardTier.bronze
        : roll < 0.80
            ? CardTier.silver
            : roll < 0.95
                ? CardTier.gold
                : CardTier.platinum;
    final pool = allPlayerCards.where((c) => c.tier == tier).toList();
    final fallback = pool.isEmpty ? allPlayerCards : pool;
    return fallback[_random.nextInt(fallback.length)];
  }

  bool get _allCardsRevealed => _cardRevealed.every((r) => r);

  @override
  void dispose() {
    _packBurstController.dispose();
    _cardsEntryController.dispose();
    _doneButtonController.dispose();
    _completionController.dispose();
    for (final c in _cardFlipControllers) {
      c.dispose();
    }
    for (final c in _rarityEffectControllers) {
      c.dispose();
    }
    for (final c in _shakeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [Color(0xff0d1a2d), Cyber.bg],
          ),
        ),
        child: Stack(
          children: [
            // Pack visual — shrinks and fades on burst
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 0.3).animate(
                    CurvedAnimation(parent: _packBurstController, curve: Curves.easeInQuad),
                  ),
                  child: AnimatedBuilder(
                    animation: _packBurstController,
                    builder: (context, child) => Opacity(
                      opacity: (1.0 - _packBurstController.value * 0.7).clamp(0.0, 1.0),
                      child: child,
                    ),
                    child: _AnimatedPackVisual(pack: widget.pack),
                  ),
                ),
              ),
            ),

            // Cards — centered Wrap that flows to new rows on narrow screens
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 110),
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      for (int i = 0; i < 5; i++) _buildCardRevealWidget(i),
                    ],
                  ),
                ),
              ),
            ),

            // Pack-complete diagonal shimmer sweep
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _completionController,
                builder: (context, _) {
                  if (_completionController.value == 0) return const SizedBox.shrink();
                  final t = _completionController.value;
                  final alignX = t * 4 - 2; // sweeps from -2 to 2 (off-screen → off-screen)
                  final alpha = (sin(t * pi) * 0.22).clamp(0.0, 1.0);
                  return IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(alignX - 1, -1),
                          end: Alignment(alignX + 1, 1),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: alpha),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Done button — slides up after all cards revealed
            Positioned(
              bottom: 48,
              left: 24,
              right: 24,
              child: FadeTransition(
                opacity: _doneButtonController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _doneButtonController,
                    curve: Curves.easeOut,
                  )),
                  child: CyberCtaButton(
                    label: 'Done',
                    primary: true,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onComplete();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRevealWidget(int index) {
    final card = _revealedCards[index];
    final glowColor = tierColor(card.tier);
    final (glowMaxAlpha, glowBase, blurBase, spreadBase) = switch (card.tier) {
      CardTier.bronze  => (0.30, 0.12, 10.0, 2.0),
      CardTier.silver  => (0.45, 0.20, 16.0, 4.0),
      CardTier.gold    => (0.70, 0.40, 26.0, 8.0),
      CardTier.platinum => (0.90, 0.55, 36.0, 14.0),
    };

    return AnimatedBuilder(
      animation: Listenable.merge([
        _cardsEntryController,
        _cardFlipControllers[index],
        _rarityEffectControllers[index],
        _shakeControllers[index],
      ]),
      builder: (context, _) {
        // Staggered spring-bounce entry from below
        final start = index * 0.2;
        final end = start + 0.2;
        final rawEntry = ((_cardsEntryController.value - start) / (end - start)).clamp(0.0, 1.0);
        final entry = Curves.elasticOut.transform(rawEntry);
        final slideY = (1.0 - entry) * 480;

        // Shake oscillation (3 full cycles, returns to zero)
        final shakeAngle = sin(_shakeControllers[index].value * pi * 6) * 0.07;

        // 3D flip with smooth easing
        final flipVal = Curves.easeInOutCubic.transform(_cardFlipControllers[index].value);
        final flipAngle = flipVal * pi;
        final showFront = flipVal > 0.5;

        // Animated rarity glow: bursts then settles
        final g = _rarityEffectControllers[index].value;
        final glowAlpha = (sin(g * pi) * glowMaxAlpha + g * glowBase).clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, slideY),
          child: Opacity(
            opacity: entry.clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateZ(shakeAngle),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: g > 0
                      ? [
                          BoxShadow(
                            color: glowColor.withValues(alpha: glowAlpha),
                            blurRadius: blurBase + g * blurBase * 2,
                            spreadRadius: spreadBase * g,
                          ),
                        ]
                      : null,
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(flipAngle),
                  // When showing front, counter-rotate so the card reads correctly
                  child: showFront
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: CyberPlayerCardTile(
                            card: card,
                            selected: false,
                            size: VisualCardSize.sm,
                          ),
                        )
                      : const _PackCardBack(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Face-down card back used during pack opening
class _PackCardBack extends StatelessWidget {
  const _PackCardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 144,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Cyber.cyan.withValues(alpha: 0.25),
            Cyber.panel,
            Cyber.panel2,
          ],
        ),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.6), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard, size: 32, color: Cyber.cyan),
          const SizedBox(height: 8),
          Text(
            '?',
            style: TextStyle(
              color: Cyber.cyan.withValues(alpha: 0.7),
              fontFamily: 'Orbitron',
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// Animated pack visual component
class _AnimatedPackVisual extends StatefulWidget {
  const _AnimatedPackVisual({required this.pack});

  final ShopPackOption pack;

  @override
  State<_AnimatedPackVisual> createState() => __AnimatedPackVisualState();
}

class __AnimatedPackVisualState extends State<_AnimatedPackVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseController.value * 0.1),
          child: Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              gradient: widget.pack.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Cyber.cyan.withValues(alpha: 0.4),
                  blurRadius: 20 + (_pulseController.value * 10),
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.card_giftcard,
                size: 60,
                color: Colors.white.withValues(alpha: 0.8 + (_pulseController.value * 0.2)),
              ),
            ),
          ),
        );
      },
    );
  }
}

