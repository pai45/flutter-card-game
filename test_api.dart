import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final cricketRes = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/cricket/scorepanel'));
  if (cricketRes.statusCode == 200) {
    final data = json.decode(cricketRes.body);
    final scores = data['scores'] as List? ?? [];
    int matchCount = 0;
    for (var score in scores) {
      final events = score['events'] as List? ?? [];
      for (var event in events) {
        String name = event['name']?.toString() ?? 'Unknown';
        String state = event['status']?['type']?['state'] ?? 'Unknown';
        String leagueId = score['leagues']?[0]?['id']?.toString() ?? 'unknown_league';
        print('Match: $name, State: $state, League: $leagueId');
        matchCount++;
      }
    }
    print('Total matches found: $matchCount');
  }
}
