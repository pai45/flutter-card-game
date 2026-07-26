import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/sport_match.dart';
import '../models/team_standing.dart';

class EspnService {
  const EspnService();

  Future<List<TeamStanding>> fetchStandings(String leagueId) async {
    try {
      // Use fifa.world for FIFA World Cup data
      final url = Uri.parse('https://site.web.api.espn.com/apis/v2/sports/soccer/fifa.world/standings');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final List allEntries = [];
        final children = data['children'] as List;
        for (final child in children) {
          if (child['standings'] != null && child['standings']['entries'] != null) {
            allEntries.addAll(child['standings']['entries']);
          }
        }

        final standings = allEntries.map((entry) {
          final teamData = entry['team'];
          final stats = entry['stats'] as List;

          String getStat(String name) {
            final stat = stats.firstWhere(
              (s) => s['name'] == name,
              orElse: () => null,
            );
            return stat != null ? stat['displayValue'].toString() : '0';
          }

          final rank = int.tryParse(getStat('rank')) ?? 0;
          final played = int.tryParse(getStat('gamesPlayed')) ?? 0;
          final won = int.tryParse(getStat('wins')) ?? 0;
          final drawn = int.tryParse(getStat('ties')) ?? 0;
          final lost = int.tryParse(getStat('losses')) ?? 0;
          final points = int.tryParse(getStat('points')) ?? 0;
          final goalDiff = getStat('pointDifferential');

          final teamName = teamData['name'] as String;
          final shortName = (teamData['abbreviation'] as String?) ??
              teamName.substring(0, 3).toUpperCase();
          final logoUrl = (teamData['logos'] != null &&
                  (teamData['logos'] as List).isNotEmpty)
              ? teamData['logos'][0]['href']
              : null;

          final team = SportTeam(
            id: teamData['id'].toString(),
            name: teamName,
            shortName: shortName,
            color: const Color(0xff3b82f6), // Use a default blue for acronym badges
            crestAsset: logoUrl,
          );

          return TeamStanding(
            team: team,
            rank: rank,
            played: played,
            won: won,
            lost: lost,
            drawn: drawn,
            points: points,
            diffLabel: int.tryParse(goalDiff) != null && int.parse(goalDiff) > 0
                ? '+$goalDiff'
                : goalDiff,
            form: 'W', // Simplified form
          );
        }).toList();

        // Sort globally by Points (descending)
        standings.sort((a, b) => b.points.compareTo(a.points));

        // Re-assign global rank
        return List.generate(standings.length, (index) {
          final s = standings[index];
          return TeamStanding(
            team: s.team,
            rank: index + 1,
            played: s.played,
            won: s.won,
            lost: s.lost,
            drawn: s.drawn,
            points: s.points,
            diffLabel: s.diffLabel,
            form: s.form,
          );
        });
      } else {
        throw Exception('Failed to load standings');
      }
    } catch (e) {
      debugPrint('Error fetching ESPN standings: $e');
      return [];
    }
  }
}
