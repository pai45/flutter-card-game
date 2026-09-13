import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/f1_league_data.dart';

class EspnF1LeagueService {
  const EspnF1LeagueService();
  static const endpoint =
      'https://site.web.api.espn.com/apis/v2/sports/racing/f1/standings';
  static const assetPath = 'assets/data/f1-league-standings.json';

  Future<F1LeagueData> bundled() async {
    final json =
        jsonDecode(await rootBundle.loadString(assetPath))
            as Map<String, dynamic>;
    if (json['source'] != endpoint) {
      throw const FormatException('Unexpected F1 data source');
    }
    return F1LeagueData.fromEspn(
      json['response'] as Map<String, dynamic>,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  Future<F1LeagueData> fetch() async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError('ESPN standings HTTP ${response.statusCode}');
      }
      return F1LeagueData.fromEspn(
        jsonDecode(response.body) as Map<String, dynamic>,
        fetchedAt: DateTime.now().toUtc(),
      );
    } finally {
      client.close();
    }
  }
}
