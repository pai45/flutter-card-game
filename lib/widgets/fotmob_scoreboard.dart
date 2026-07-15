import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FotmobScoreboardList extends StatefulWidget {
  const FotmobScoreboardList({super.key});

  @override
  State<FotmobScoreboardList> createState() => _FotmobScoreboardListState();
}

class _FotmobScoreboardListState extends State<FotmobScoreboardList> {
  bool _isLoading = true;
  String? _error;
  List<dynamic>? _allMatches;

  // Fotmob dark mode colors
  final Color bgMain = const Color(0xFF0a1019);

  @override
  void initState() {
    super.initState();
    _fetchAllMatches();
  }

  Future<void> _fetchAllMatches() async {
    try {
      final response = await http.get(Uri.parse(
          'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard?dates=20260611-20260719'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List;

        setState(() {
          _allMatches = events;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch match data (${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: bgMain,
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: bgMain,
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            _error!,
            style: TextStyle(color: Colors.red[300], fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_allMatches == null || _allMatches!.isEmpty) {
      return Container(
        color: bgMain,
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: Text(
            'No matches found.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      color: bgMain,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: _allMatches!.length,
        itemBuilder: (context, index) {
          final matchData = _allMatches![index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: MatchScoreboardCard(matchData: matchData),
          );
        },
      ),
    );
  }
}

class MatchScoreboardCard extends StatelessWidget {
  final Map<String, dynamic> matchData;

  const MatchScoreboardCard({super.key, required this.matchData});

  // Fotmob dark mode colors
  final Color bgCard = const Color(0xFF151d2a);
  final Color textPrimary = Colors.white;
  final Color textSecondary = const Color(0xFF8c97a5);
  final Color borderColor = const Color(0xFF212c3d);

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _getStatValue(List<dynamic>? stats, String statName) {
    if (stats == null) return '0';
    final stat = stats.firstWhere(
      (s) => s['name'] == statName,
      orElse: () => null,
    );
    return stat?['displayValue']?.toString() ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    final comp = matchData['competitions'] != null && matchData['competitions'].isNotEmpty
        ? matchData['competitions'][0]
        : null;

    if (comp == null) return const SizedBox.shrink();

    final competitors = comp['competitors'] as List;
    final homeTeamData = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => competitors[0]);
    final awayTeamData = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => competitors.length > 1 ? competitors[1] : competitors[0]);

    final homeColor = _parseColor(homeTeamData['team']['color'], const Color(0xFF444444));
    final awayColor = _parseColor(awayTeamData['team']['color'], const Color(0xFF888888));

    // Stats
    final homeStats = homeTeamData['statistics'] as List?;
    final awayStats = awayTeamData['statistics'] as List?;

    final homePossession = double.tryParse(_getStatValue(homeStats, 'possessionPct')) ?? 50.0;
    final awayPossession = double.tryParse(_getStatValue(awayStats, 'possessionPct')) ?? 50.0;
    
    final homeShots = double.tryParse(_getStatValue(homeStats, 'totalShots')) ?? 0.0;
    final awayShots = double.tryParse(_getStatValue(awayStats, 'totalShots')) ?? 0.0;

    // Events (Goals & Cards)
    final details = comp['details'] as List? ?? [];
    List<Widget> homeEvents = [];
    List<Widget> awayEvents = [];

    for (var detail in details) {
      final isHome = detail['team'] != null && detail['team']['id'] == homeTeamData['id'];
      final athletes = detail['athletesInvolved'] as List?;
      final athleteName = athletes != null && athletes.isNotEmpty 
          ? athletes[0]['shortName'] ?? athletes[0]['displayName'] 
          : 'Unknown';
      final clock = detail['clock'] != null ? detail['clock']['displayValue'] : '';
      
      bool isGoal = detail['scoreValue'] == 1;
      bool isYellow = detail['yellowCard'] == true;
      bool isRed = detail['redCard'] == true;
      
      String text = '$athleteName $clock';
      if (detail['penaltyKick'] == true && isGoal) {
        text += ' (P)';
      }

      Widget icon;
      if (isGoal) {
        icon = const Icon(Icons.sports_soccer, size: 14, color: Colors.white70);
      } else if (isRed) {
        icon = Container(width: 10, height: 14, color: Colors.red);
      } else if (isYellow) {
        icon = Container(width: 10, height: 14, color: Colors.yellow);
      } else {
        continue;
      }

      if (isHome) {
        homeEvents.add(_buildEventLeft(text, icon));
      } else {
        awayEvents.add(_buildEventRight(text, icon));
      }
    }

    String statusText = matchData['status']?['type']?['description'] ?? 'Finished';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scoreboard Card
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Status Badge
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border(
                          left: BorderSide(color: borderColor),
                          right: BorderSide(color: borderColor),
                          bottom: BorderSide(color: borderColor),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
                    child: Column(
                      children: [
                        // Teams Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTeam(
                              abbreviation: homeTeamData['team']?['abbreviation'] ?? 'HOME',
                              name: homeTeamData['team']?['shortDisplayName'] ?? 'Home',
                              color: homeColor,
                              textColor: ThemeData.estimateBrightnessForColor(homeColor) == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.black,
                            ),
                            // Score
                            Row(
                              children: [
                                Text(
                                  '${homeTeamData['score'] ?? 0}',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '-',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${awayTeamData['score'] ?? 0}',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                            _buildTeam(
                              abbreviation: awayTeamData['team']?['abbreviation'] ?? 'AWAY',
                              name: awayTeamData['team']?['shortDisplayName'] ?? 'Away',
                              color: awayColor,
                              textColor: ThemeData.estimateBrightnessForColor(awayColor) == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.black,
                            ),
                          ],
                        ),

                        if (homeEvents.isNotEmpty || awayEvents.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 16),
                          // Events
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: homeEvents,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: awayEvents,
                                ),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats Card
            if (homeStats != null || awayStats != null)
              Container(
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'MATCH STATS',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildStatRow('Possession', '${homePossession.toStringAsFixed(0)}%', '${awayPossession.toStringAsFixed(0)}%', homePossession, awayPossession, homeColor, awayColor),
                    const SizedBox(height: 16),
                    _buildStatRow('Total Shots', homeShots.toStringAsFixed(0), awayShots.toStringAsFixed(0), homeShots, awayShots, homeColor, awayColor),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeam({
    required String abbreviation,
    required String name,
    required Color color,
    required Color textColor,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            abbreviation,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEventLeft(String text, Widget icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: Text(text, style: TextStyle(color: textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          icon,
        ],
      ),
    );
  }

  Widget _buildEventRight(String text, Widget icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String val1,
    String val2,
    double rawVal1,
    double rawVal2,
    Color color1,
    Color color2,
  ) {
    final double total = rawVal1 + rawVal2;
    final double flex1 = total <= 0 ? 50 : (rawVal1 / total) * 100;
    final double flex2 = total <= 0 ? 50 : (rawVal2 / total) * 100;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(val1, style: TextStyle(color: rawVal1 > rawVal2 ? textPrimary : textSecondary, fontWeight: FontWeight.w600)),
            Text(label, style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(val2, style: TextStyle(color: rawVal2 >= rawVal1 ? textPrimary : textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: flex1.toInt() == 0 ? 1 : flex1.toInt(),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color1,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: flex2.toInt() == 0 ? 1 : flex2.toInt(),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color2,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
