import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
void main() async {
  final res = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard?dates=20260708'));
  final data = json.decode(res.body);
  final events = data['events'] as List? ?? [];
  
  for (var event in events) {
    print('Event: ${event['id']} - ${event['name']}');
    final sumRes = await http.get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/summary?event=${event['id']}'));
    final sumData = json.decode(sumRes.body);
    final boxscore = sumData['boxscore'];
    print('  boxscore != null: ${boxscore != null}');
    if (boxscore != null) {
      final players = boxscore['players'] as List? ?? [];
      print('  players: ${players.length}');
    }
  }
}
