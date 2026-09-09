// dart run tool/generate_f1_league.dart
// Preserve the actual ESPN document; the app and tests share its parser.
import 'dart:convert';
import 'dart:io';

import 'package:card_game/models/f1_league_data.dart';
import 'espn_feed_client.dart';

Future<void> main() async {
  const endpoint =
      'https://site.web.api.espn.com/apis/v2/sports/racing/f1/standings';
  final client = EspnFeedClient();
  try {
    final response = await client.getJson(endpoint);
    if (response == null) throw StateError('ESPN standings unavailable');
    final now = DateTime.now().toUtc();
    final data = F1LeagueData.fromEspn(response, fetchedAt: now);
    if (data.drivers.isEmpty || data.constructors.isEmpty) {
      throw StateError(
        'Both championship tables are required for the snapshot',
      );
    }
    await File('assets/data/f1-league-standings.json').writeAsString(
      '${jsonEncode({'source': endpoint, 'fetchedAt': now.toIso8601String(), 'response': response})}\n',
    );
    stdout.writeln(
      '${data.season}: ${data.drivers.length} drivers, '
      '${data.constructors.length} constructors, ${data.rounds.length} rounds',
    );
  } finally {
    client.close();
  }
}
