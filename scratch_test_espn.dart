import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Let's query Wimbledon 2026 summary or scoreboard
  print('Querying Wimbledon 2026...');
  final url = 'https://site.api.espn.com/apis/site/v2/sports/tennis/atp/scoreboard?dates=20260712';
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      print(res.body);
    }
  } catch (e) {
    print('Error: \$e');
  }
}
