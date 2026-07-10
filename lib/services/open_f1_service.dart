import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sport_match.dart';

class OpenF1Service {
  OpenF1Service({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<SportMatch> enrich(SportMatch fallback) async {
    if (fallback.sport != Sport.f1) return fallback;

    try {
      final response = await _client.get(
        Uri.parse('https://api.openf1.org/v1/drivers?session_key=latest'),
      );
      
      if (response.statusCode != 200) {
        return fallback.copyWith(
          liveStatusNote: 'OpenF1 API unavailable (${response.statusCode}).',
          clearLiveLastUpdated: true,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return fallback.copyWith(
          liveStatusNote: 'Invalid OpenF1 API response.',
          clearLiveLastUpdated: true,
        );
      }

      final List<String> drivers = decoded
          .whereType<Map<String, dynamic>>()
          .map((d) => d['full_name'] as String?)
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();

      if (drivers.isEmpty) {
        return fallback;
      }

      return fallback.copyWith(
        f1DriverStandings: drivers,
        liveStatusNote: 'Enriched via OpenF1 API',
        liveLastUpdated: DateTime.now(),
      );
    } catch (_) {
      return fallback.copyWith(
        liveStatusNote: 'OpenF1 API temporarily unavailable.',
        clearLiveLastUpdated: true,
      );
    }
  }
}
