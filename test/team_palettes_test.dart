import 'package:card_game/data/team_palettes.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

SportTeam _team(String name, {Color color = const Color(0xff123456)}) =>
    SportTeam(id: 'x', name: name, shortName: 'XXX', color: color);

void main() {
  group('normaliseTeamName', () {
    test('strips accents so ESPN names match their generated keys', () {
      expect(normaliseTeamName('Atlético-MG'), 'atleticomg');
      expect(normaliseTeamName('Malmö FF'), 'malmoff');
      expect(normaliseTeamName('Örgryte IS'), 'orgryteis');
      expect(normaliseTeamName('São Paulo'), 'saopaulo');
      expect(normaliseTeamName('BK Häcken'), 'bkhacken');
    });

    test('transliterates letters that do not decompose', () {
      expect(normaliseTeamName('Bodø/Glimt'), 'bodoglimt');
      expect(normaliseTeamName('Æ FC'), 'aefc');
    });

    test('drops punctuation and spacing but keeps digits', () {
      expect(normaliseTeamName("Hapoel Be'er"), 'hapoelbeer');
      expect(normaliseTeamName('Iberia 1999'), 'iberia1999');
    });
  });

  group('kTeamPalettes', () {
    test('is non-trivial and sport-namespaced', () {
      expect(kTeamPalettes.length, greaterThan(800));
      for (final key in kTeamPalettes.keys) {
        expect(key, contains(':'));
        final sport = key.split(':').first;
        expect(
          Sport.values.map((s) => s.name),
          contains(sport),
          reason: '$key is namespaced by an unknown sport',
        );
      }
    });

    test('every label clears WCAG AA against its own fill', () {
      for (final entry in kTeamPalettes.entries) {
        final p = entry.value;
        expect(
          _contrast(p.primary, p.text),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} label is unreadable on its fill',
        );
      }
    });

    test('every accent separates from its own fill', () {
      for (final entry in kTeamPalettes.entries) {
        final p = entry.value;
        expect(
          _contrast(p.primary, p.secondary),
          greaterThan(1.5),
          reason: '${entry.key} accent edge is invisible against its fill',
        );
      }
    });
  });

  group('paletteForTeam', () {
    test('resolves a known team from the database', () {
      final palette = paletteForTeam(_team('Arsenal'), sport: Sport.football);
      expect(palette.primary, kTeamPalettes['football:arsenal']!.primary);
    });

    test('matches regardless of accents in the incoming name', () {
      final palette = paletteForTeam(_team('Atlético-MG'), sport: Sport.football);
      expect(palette.primary, kTeamPalettes['football:atleticomg']!.primary);
    });

    test('an override beats the generated entry', () {
      final palette = paletteForTeam(_team('Man City'), sport: Sport.football);
      expect(palette.primary, const Color(0xff74acde));
    });

    test('falls back to a derived palette for an unseen team', () {
      // Deliberately not in the database — must still render legibly rather
      // than throwing or returning a null-ish default.
      final palette = paletteForTeam(
        _team('Totally Fictional Rovers', color: const Color(0xff000000)),
        sport: Sport.football,
      );
      expect(palette.primary, const Color(0xff000000));
      expect(_contrast(palette.primary, palette.text), greaterThanOrEqualTo(4.5));
      expect(_contrast(palette.primary, palette.secondary), greaterThan(1.5));
    });

    test('finds a team even when the sport is unknown', () {
      final palette = paletteForTeam(_team('Arsenal'));
      expect(palette.primary, kTeamPalettes['football:arsenal']!.primary);
    });
  });

  group('derivePalette', () {
    test('picks readable text for both light and dark fills', () {
      expect(derivePalette(const Color(0xff000000)).text, Colors.white);
      expect(derivePalette(const Color(0xffffffff)).text, Colors.black);
    });
  });
}
