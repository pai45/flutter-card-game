import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/f1_race_package_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts against the real bundled `assets/data/f1-italian-gp.json`, the same
/// way the football and cricket package tests do — the point is that the
/// shipped asset is correct, not that a fixture round-trips.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(F1RacePackageService.clearCache);

  test('bundled package resolves by every alias', () async {
    for (final lookup in <Map<String, String>>[
      {'raceId': '600057442'},
      {'abbreviation': 'ITA'},
      {'abbreviation': 'ita'},
      {'name': 'Pirelli Italian Grand Prix'},
      // Fixtures arrive with sponsor decoration around the title.
      {'name': 'FORMULA 1 PIRELLI ITALIAN GRAND PRIX 2026'},
    ]) {
      final package = await F1RacePackageService.packageFor(
        raceId: lookup['raceId'],
        name: lookup['name'],
        abbreviation: lookup['abbreviation'],
      );
      expect(package, isNotNull, reason: 'should resolve via $lookup');
      expect(package!.raceId, '600057442');
    }
  });

  test('an uncovered race resolves to null so the UI can fall back', () async {
    final package = await F1RacePackageService.packageFor(
      raceId: '600057443',
      name: 'Heineken Dutch Grand Prix',
      abbreviation: 'NLD',
    );
    expect(package, isNull);
  });

  test('the weekend carries all five sessions and a full field', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    expect(package, isNotNull);

    expect(
      package!.sessions.map((s) => s.abbreviation),
      ['FP1', 'FP2', 'FP3', 'Qual', 'Race'],
      reason: 'sessions arrive in running order',
    );
    for (final session in package.sessions) {
      expect(
        session.classification,
        hasLength(22),
        reason: '${session.abbreviation} should field 22 cars',
      );
      expect(
        session.classification.map((e) => e.position),
        List.generate(22, (i) => i + 1),
        reason: '${session.abbreviation} arrives position-sorted',
      );
    }

    // Four reserves ran FP1 only, so the weekend fields more drivers than the
    // race does. Anything joining sessions to a driver list must not assume
    // the race entry list covers the weekend.
    expect(package.drivers, hasLength(26));
    expect(package.constructors, hasLength(11));
    final raceDrivers = package.race!.classification
        .map((e) => e.driverId)
        .toSet();
    expect(raceDrivers, hasLength(22));
    expect(package.drivers.length - raceDrivers.length, 4);

    // Every classification row resolves to a known driver and constructor.
    for (final session in package.sessions) {
      for (final entry in session.classification) {
        expect(package.driver(entry.driverId), isNotNull);
      }
    }
  });

  test('the race winner came from P19 on the grid', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final winner = package!.winner!;

    expect(winner.driverId, '5829');
    expect(package.driver('5829')!.displayName, 'Kimi Antonelli');
    expect(winner.winner, isTrue);
    expect(winner.display('totalTime'), '1:51:15.281');
    expect(winner.value('championshipPts'), 25);
    expect(winner.display('fastestLap'), '1:23.504');

    // Grid is NOT qualifying position: he qualified 7th and started 19th after
    // a penalty. Only the grid slot reflects that.
    expect(winner.grid, 19);
    expect(winner.positionsGained, 18);
    final qualifying = package.qualifying!.entryFor('5829')!;
    expect(qualifying.position, 7);
    expect(qualifying.grid, isNull, reason: 'grid is set on the race only');
  });

  test('a retired car has no total time', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final last = package!.race!.classification.last;

    expect(last.position, 22);
    expect(last.driverId, '5498');
    expect(last.retired, isTrue);
    expect(last.statusDescription, 'Retired');
    expect(last.statusLaps, 1);
    expect(last.value('lapsCompleted'), 1);
    // The absence is the information — a zero here would read as a 0.000 time.
    expect(last.stat('totalTime'), isNull);
    expect(last.stat('behindTime'), isNull);
  });

  test('qualifying omits segments a driver never reached', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final rows = package!.qualifying!.classification;

    // Everyone runs Q1; 16 reach Q2; 10 reach Q3.
    expect(rows.where((e) => e.stat('qual1TimeMS') != null), hasLength(22));
    expect(rows.where((e) => e.stat('qual2TimeMS') != null), hasLength(16));
    expect(rows.where((e) => e.stat('qual3TimeMS') != null), hasLength(10));

    for (final row in rows) {
      if (row.position > 10) {
        expect(
          row.stat('qual3TimeMS'),
          isNull,
          reason: 'P${row.position} was knocked out before Q3',
        );
      }
      if (row.position > 16) {
        expect(row.stat('qual2TimeMS'), isNull);
      }
    }

    expect(rows.first.display('qual3TimeMS'), '1:21.786');
    expect(package.driver(rows.first.driverId)!.displayName, 'Pierre Gasly');
  });

  test('gaps split between lead-lap time and lapped cars', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final rows = package!.race!.classification;

    expect(rows.first.stat('behindTime'), isNull, reason: 'the leader is level');
    expect(rows[1].display('behindTime'), '+3.857');

    // The two are mutually exclusive: a car either has a time gap or a lap
    // count, never both, and together they cover every runner but the leader.
    for (final row in rows) {
      final timed = row.stat('behindTime') != null;
      final lapped = row.stat('behindLaps') != null;
      expect(timed && lapped, isFalse);
    }
    expect(rows.where((e) => e.stat('behindTime') != null), hasLength(14));
    expect(rows.where((e) => e.stat('behindLaps') != null), hasLength(7));
  });

  test('the circuit carries a lap record and a track map', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final circuit = package!.circuit!;

    expect(circuit.fullName, 'Autodromo Nazionale Monza');
    expect(circuit.locationLabel, 'Monza, Italy');
    expect(circuit.laps, 53);
    expect(circuit.turns, 11);
    expect(circuit.lengthKm, closeTo(5.793, 0.001));
    expect(circuit.lapRecord.time, '1:20.901');
    expect(circuit.lapRecord.year, 2025);
    expect(circuit.trackMap, isNotNull);
    expect(circuit.trackMap, endsWith('.svg'));
  });

  test('standings carry both tables and a per-round points grid', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final standings = package!.standings;

    expect(standings.throughRace, 'ITA');
    // 23 rows for 22 seats — mid-season driver changes mean this cannot be
    // joined 1:1 against the race entry list.
    expect(standings.drivers, hasLength(23));
    expect(standings.constructors, hasLength(11));
    expect(standings.raceCodes, hasLength(25));

    // Only 13 of the 25 rounds have been raced; the rest are absent, not zero.
    expect(standings.racedCodes, hasLength(13));
    expect(standings.racedCodes.last, 'ITA');

    final leader = standings.drivers.first;
    expect(leader.rank, 1);
    expect(leader.id, '5829');
    expect(leader.points, 267);
    expect(leader.byRace['ITA'], 25);
    expect(standings.constructors.first.byRace['ITA'], 43);
    expect(
      leader.byRace.containsKey('QAT'),
      isFalse,
      reason: 'a round that has not run carries no entry',
    );
  });

  test('the bundled weekend becomes a reachable fixture', () async {
    final fixtures = await F1RacePackageService.bundledFixtures();
    expect(fixtures, hasLength(1));

    final race = fixtures.single;
    // The STATS tab resolves the package off this id, so it has to be the ESPN
    // event id rather than a seeded slug.
    expect(race.id, '600057442');
    expect(race.sport, Sport.motorsport);
    expect(race.leagueId, 'f1');
    expect(race.status, MatchStatus.finished);

    // Real dates, not pinned to today: the week picker opens on the closest
    // race week, so a dated Grand Prix stays honest and still lands.
    expect(race.kickoff.toUtc(), DateTime.utc(2026, 9, 4, 10, 30));
    expect(race.f1WeekendEndDate!.toUtc(), DateTime.utc(2026, 9, 6, 13));

    // Same home/away shape the live scoreboard builds, so a live response for
    // this race de-duplicates against the bundled one instead of doubling it.
    expect(race.home.name, 'Pirelli Italian Grand Prix');
    expect(race.away.name, 'F1');
    expect(race.resultLine, contains('Kimi Antonelli'));

    // Five sessions, and the grid parser reads them like a live response.
    expect(race.f1Sessions!.map((s) => s.name), [
      'FP1',
      'FP2',
      'FP3',
      'Qual',
      'Race',
    ]);
    final qualifying = race.f1Sessions!.firstWhere((s) => s.isQualifying);
    expect(qualifying.results.first, '1. Pierre Gasly · Alpine (1:21.786)');

    final raceSession = race.f1Sessions!.last;
    expect(
      raceSession.results.first,
      '1. Kimi Antonelli · Mercedes (1:51:15.281)',
    );
    // A retired car reports its status rather than an empty bracket.
    expect(raceSession.results.last, endsWith('(Retired)'));

    expect(race.f1DriverStandings!.first, 'Kimi Antonelli');
    expect(race.f1DriverStandings, hasLength(23));
  });

  test('no session exposes usable lap-by-lap data', () async {
    final package = await F1RacePackageService.packageFor(raceId: '600057442');
    final race = package!.race!;

    // ESPN publishes no lap chart for F1, and `lapsLead` is not laps led: it
    // totals 4 across a 53-lap race. Nothing may present it as laps led, and
    // no leader-per-lap chart can be derived from this package.
    final ledTotal = race.classification.fold<double>(
      0,
      (sum, entry) => sum + (entry.value('lapsLead') ?? 0),
    );
    expect(ledTotal, 4);
    expect(race.stats['laps']!.value, 53);
    expect(ledTotal, lessThan(race.stats['laps']!.value));
  });
}
