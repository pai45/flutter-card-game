
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  for (final league in ['atp', 'wta']) {
    final url = 'https://site.api.espn.com/apis/site/v2/sports/tennis/$league/scoreboard?dates=20260710';
    print('Fetching $url');
    final res = await http.get(Uri.parse(url));
    final data = json.decode(res.body);
    final events = data['events'] as List? ?? [];
    for (var event in events) {
      final name = event['name'];
      final comps = event['competitions'] as List?;
      print('Event: $name, Comps: ${comps?.length}');
    }
  }
}

