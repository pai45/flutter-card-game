import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/f1_race_package.dart';

/// Loads the bundled F1 race-weekend package.
///
/// F1 is the one sport with no usable live path for a stats view. ESPN has no
/// `summary` feed for racing at all, the scoreboard the app polls flattens each
/// session into display strings (`"1. Verstappen · Red Bull (1:20.901)"`), and
/// a web build cannot reach ESPN directly anyway. So the charted STATS view is
/// driven entirely by the offline-generated package, and any race the package
/// does not cover falls back to the legacy session/standings panels.
///
/// Only the 2026 Italian GP is bundled today. Generate more with
/// `dart run tool/generate_f1_race.dart --race <name>`.
class F1RacePackageService {
  const F1RacePackageService();

  static const assetPaths = <String>['assets/data/f1-italian-gp.json'];

  static Future<List<F1RacePackage>>? _pending;

  /// The resolved packages, held separately from [_pending] so a second lookup
  /// never awaits a Future created during the first. That matters beyond
  /// bookkeeping: a Future belongs to the zone that created it, so awaiting a
  /// warm-up Future from inside a widget test's fake-async zone would never
  /// complete. Once loaded, every lookup resolves in its own caller's zone.
  static List<F1RacePackage>? _loaded;

  @visibleForTesting
  static void clearCache() {
    _pending = null;
    _loaded = null;
  }

  static Future<List<F1RacePackage>> _load() async {
    final cached = _loaded;
    if (cached != null) return cached;
    return _loaded = await (_pending ??= _loadAssets());
  }

  static Future<List<F1RacePackage>> _loadAssets() async {
    final packages = <F1RacePackage>[];
    for (final path in assetPaths) {
      try {
        final package = const F1RacePackageService().decode(
          await rootBundle.loadString(path),
        );
        if (package != null) packages.add(package);
      } catch (error) {
        // A missing or malformed asset must degrade to the legacy panels, never
        // take down the STATS tab.
        debugPrint('F1 race package $path unavailable: $error');
      }
    }
    return packages;
  }

  /// Every bundled weekend, in load order.
  static Future<List<F1RacePackage>> all() => _load();

  /// Resolves the package for a race by **alias**, never by a single id. The
  /// same weekend reaches this method as the ESPN event id (`600057442`), the
  /// three-letter code (`ITA`), or a fixture name that embeds the Grand Prix
  /// title — the same id-collision problem the league hubs hit, where matching
  /// on one field alone rendered an empty hub.
  static Future<F1RacePackage?> packageFor({
    String? raceId,
    String? name,
    String? abbreviation,
  }) async {
    final packages = await _load();
    if (packages.isEmpty) return null;

    final keys = [
      raceId,
      abbreviation,
      name,
    ].map(_normalize).where((k) => k.isNotEmpty).toList(growable: false);
    if (keys.isEmpty) return null;

    for (final package in packages) {
      final aliases = _aliasesFor(package);
      for (final key in keys) {
        if (aliases.contains(key)) return package;
      }
    }

    // A fixture name like "Pirelli Italian Grand Prix" arrives with broadcast
    // and sponsor decoration around the package's own name, so fall back to a
    // containment test in both directions before giving up.
    for (final package in packages) {
      final packageName = _normalize(package.name);
      if (packageName.isEmpty) continue;
      for (final key in keys) {
        if (key.length < 4) continue;
        if (key.contains(packageName) || packageName.contains(key)) {
          return package;
        }
      }
    }
    return null;
  }

  static Set<String> _aliasesFor(F1RacePackage package) => {
    _normalize(package.raceId),
    _normalize(package.abbreviation),
    _normalize(package.name),
    _normalize(package.shortName),
  }..removeWhere((alias) => alias.isEmpty);

  static String _normalize(String? raw) =>
      raw?.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '') ?? '';

  @visibleForTesting
  F1RacePackage? decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return null;
    final race = _map(decoded['race']);
    if (race == null) return null;
    final raceId = _string(race['id']);
    final name = _string(race['name']);
    if (raceId == null || name == null) return null;

    return F1RacePackage(
      raceId: raceId,
      name: name,
      shortName: _string(race['shortName']),
      abbreviation: _string(race['abbreviation']),
      season: _int(race['season']),
      startDate: _string(race['startDate']),
      endDate: _string(race['endDate']),
      circuit: _circuit(_map(race['circuit'])),
      drivers: _drivers(_map(decoded['drivers'])),
      constructors: _constructors(_map(decoded['constructors'])),
      sessions: _sessions(decoded['sessions']),
      standings: _standings(_map(decoded['standings'])),
      statDictionary: _statDictionary(_map(decoded['statDictionary'])),
    );
  }

  static F1Circuit? _circuit(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = _string(json['id']);
    final fullName = _string(json['fullName']);
    if (id == null || fullName == null) return null;
    final record = _map(json['lapRecord']);
    return F1Circuit(
      id: id,
      fullName: fullName,
      city: _string(json['city']),
      country: _string(json['country']),
      countryFlag: _string(json['countryFlag']),
      lengthKm: _double(json['lengthKm']),
      distanceKm: _double(json['distanceKm']),
      laps: _int(json['laps']),
      turns: _int(json['turns']),
      direction: _string(json['direction']),
      established: _int(json['established']),
      lapRecord: record == null
          ? const F1LapRecord()
          : F1LapRecord(
              driverId: _string(record['driverId']),
              time: _string(record['time']),
              year: _int(record['year']),
            ),
      diagrams: <String, String>{
        for (final entry in (_map(json['diagrams']) ?? const {}).entries)
          entry.key: ?_string(entry.value),
      },
      photo: _string(json['photo']),
    );
  }

  static Map<String, F1Driver> _drivers(Map<String, dynamic>? json) {
    final out = <String, F1Driver>{};
    for (final entry in (json ?? const {}).entries) {
      final value = _map(entry.value);
      if (value == null) continue;
      final displayName = _string(value['displayName']);
      if (displayName == null) continue;
      out[entry.key] = F1Driver(
        id: _string(value['id']) ?? entry.key,
        displayName: displayName,
        fullName: _string(value['fullName']),
        shortName: _string(value['shortName']),
        abbreviation: _string(value['abbreviation']),
        countryFlag: _string(value['countryFlag']),
        countryName: _string(value['countryName']),
        headshot: _string(value['headshot']),
        number: _string(value['number']),
        constructorId: _string(value['constructorId']),
        team: _string(value['team']),
        engine: _string(value['engine']),
        tire: _string(value['tire']),
        birthPlace: _string(value['birthPlace']),
        dateOfBirth: _string(value['dateOfBirth']),
      );
    }
    return out;
  }

  static Map<String, F1Constructor> _constructors(Map<String, dynamic>? json) {
    final out = <String, F1Constructor>{};
    for (final entry in (json ?? const {}).entries) {
      final value = _map(entry.value);
      if (value == null) continue;
      final name = _string(value['name']);
      if (name == null) continue;
      out[entry.key] = F1Constructor(
        id: _string(value['id']) ?? entry.key,
        name: name,
        displayName: _string(value['displayName']),
        color: _string(value['color']),
      );
    }
    return out;
  }

  static List<F1Session> _sessions(Object? raw) {
    final sessions = <F1Session>[];
    for (final item in (raw as List? ?? const [])) {
      final json = _map(item);
      if (json == null) continue;
      final id = _string(json['id']);
      if (id == null) continue;
      final type = _map(json['type']) ?? const {};
      sessions.add(
        F1Session(
          id: id,
          order: _int(json['order']) ?? sessions.length + 1,
          abbreviation: _string(type['abbreviation']) ?? '?',
          typeId: _string(type['id']),
          text: _string(type['text']),
          date: _string(json['date']),
          stats: _stats(_map(json['stats'])),
          classification: _classification(json['classification']),
        ),
      );
    }
    sessions.sort((a, b) => a.order.compareTo(b.order));
    return sessions;
  }

  static List<F1ClassificationEntry> _classification(Object? raw) {
    final rows = <F1ClassificationEntry>[];
    for (final item in (raw as List? ?? const [])) {
      final json = _map(item);
      if (json == null) continue;
      final position = _int(json['position']);
      final driverId = _string(json['driverId']);
      if (position == null || driverId == null) continue;
      final status = _map(json['status']) ?? const {};
      rows.add(
        F1ClassificationEntry(
          position: position,
          driverId: driverId,
          grid: _int(json['grid']),
          winner: json['winner'] == true,
          number: _string(json['number']),
          constructorName: _string(json['constructor']),
          teamColor: _string(json['teamColor']),
          statusName: _string(status['name']),
          statusDescription: _string(status['description']),
          statusCompleted: status['completed'] is bool
              ? status['completed'] as bool
              : null,
          statusLaps: _int(status['laps']),
          stats: _stats(_map(json['stats'])),
        ),
      );
    }
    rows.sort((a, b) => a.position.compareTo(b.position));
    return rows;
  }

  static Map<String, F1Stat> _stats(Map<String, dynamic>? json) {
    final out = <String, F1Stat>{};
    for (final entry in (json ?? const {}).entries) {
      final stat = F1Stat.fromJson(entry.value);
      if (stat != null) out[entry.key] = stat;
    }
    return out;
  }

  static F1SeasonStandings _standings(Map<String, dynamic>? json) {
    if (json == null) return const F1SeasonStandings.empty();
    return F1SeasonStandings(
      season: _int(json['season']),
      throughRace: _string(json['throughRace']),
      raceCodes: [
        for (final code in (json['raceCodes'] as List? ?? const []))
          ?_string(code),
      ],
      drivers: _standingsRows(json['drivers'], idKey: 'driverId'),
      constructors: _standingsRows(json['constructors'], idKey: 'constructorId'),
    );
  }

  static List<F1StandingsRow> _standingsRows(
    Object? raw, {
    required String idKey,
  }) {
    final rows = <F1StandingsRow>[];
    for (final item in (raw as List? ?? const [])) {
      final json = _map(item);
      if (json == null) continue;
      final id = _string(json[idKey]);
      if (id == null) continue;
      rows.add(
        F1StandingsRow(
          id: id,
          rank: _int(json['rank']),
          name: _string(json['name']),
          points: _int(json['points']),
          byRace: <String, int>{
            for (final entry in (_map(json['byRace']) ?? const {}).entries)
              entry.key: ?_int(entry.value),
          },
        ),
      );
    }
    return rows;
  }

  static Map<String, String> _statDictionary(Map<String, dynamic>? json) {
    final out = <String, String>{};
    for (final entry in (json ?? const {}).entries) {
      final value = _map(entry.value);
      final label =
          _string(value?['shortDisplayName']) ?? _string(value?['displayName']);
      if (label != null) out[entry.key] = label;
    }
    return out;
  }

  static Map<String, dynamic>? _map(Object? raw) =>
      raw is Map<String, dynamic> ? raw : null;

  static String? _string(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  static int? _int(Object? raw) => raw is num ? raw.toInt() : null;

  static double? _double(Object? raw) => raw is num ? raw.toDouble() : null;
}
