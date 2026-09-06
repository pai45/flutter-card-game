import 'dart:convert';
import 'dart:io';

import 'package:card_game/config/theme.dart';
import 'package:card_game/data/team_palette_data.g.dart';
import 'package:card_game/data/team_palettes.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/widgets/team_logo.dart';
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
  group('generated source', () {
    test('retains every source record and every required color role', () {
      final records =
          (jsonDecode(File('tool/data/team_palettes.json').readAsStringSync())
                  as List)
              .cast<Map<String, dynamic>>();

      expect(records, hasLength(6248));
      expect(kGeneratedTeamPaletteRecordCount, 6248);
      expect(kGeneratedTeamPaletteValues, hasLength(6246));
      final hex = RegExp(r'^#[0-9A-F]{6}$');
      for (final record in records) {
        expect(record['id'], isNotEmpty);
        expect(record['name'], isNotEmpty);
        expect(record['displayName'], isNotEmpty);
        expect(record['abbreviation'], isNotEmpty);
        expect(record['tournament'], isNotEmpty);
        for (final field in const [
          'primaryColor',
          'secondaryColor',
          'textColor',
          'secondaryTextColor',
        ]) {
          expect(
            record[field],
            matches(hex),
            reason: '${record['id']} has invalid $field',
          );
        }
      }
    });

    test('preserves competition-specific conflicts as separate palettes', () {
      expect(
        kGeneratedTeamPaletteValues['football:epl:chelsea'],
        isNot(kGeneratedTeamPaletteValues['football:englishfacup:chelsea']),
      );
      expect(
        kGeneratedTeamPaletteValues['football:epl:fulham'],
        isNot(kGeneratedTeamPaletteValues['football:englishfacup:fulham']),
      );
    });

    test('every UI identity color clears AA on every dark surface', () {
      const surfaces = [Cyber.bg, Cyber.card, Cyber.panel, Cyber.chartSurface];
      for (final entry in kGeneratedTeamPaletteValues.entries) {
        final color = Color(entry.value[3]);
        for (final surface in surfaces) {
          expect(
            _contrast(color, surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} fails on $surface',
          );
        }
      }
    });
  });

  group('normaliseTeamName', () {
    test('normalises accents, punctuation, spacing, and digits', () {
      expect(normaliseTeamName('Atlético-MG'), 'atleticomg');
      expect(normaliseTeamName('Malmö FF'), 'malmoff');
      expect(normaliseTeamName('Bodø/Glimt'), 'bodoglimt');
      expect(normaliseTeamName("Hapoel Be'er 1999"), 'hapoelbeer1999');
    });
  });

  group('paletteForTeam', () {
    test('uses an exact competition palette through a league id alias', () {
      final palette = paletteForTeam(
        _team('Chelsea', color: const Color(0xff034694)),
        sport: Sport.football,
        competition: 'eng.1',
      );

      expect(palette.primary, const Color(0xff034694));
      expect(palette.secondary, Colors.white);
      expect(palette.text, Colors.white);
      expect(palette.secondaryTextColor, const Color(0xff3390fb));
    });

    test('keeps a different competition variant distinct', () {
      final palette = paletteForTeam(
        _team('Chelsea', color: const Color(0xff144992)),
        sport: Sport.football,
        competition: 'English FA Cup',
      );

      expect(palette.primary, const Color(0xff144992));
      expect(palette.secondaryTextColor, const Color(0xff5090e7));
    });

    test('uses the closest supplied primary when a name is ambiguous', () {
      final palette = paletteForTeam(
        _team('Chelsea', color: const Color(0xff144992)),
        sport: Sport.football,
      );

      expect(palette.primary, const Color(0xff144992));
    });

    test('resolves basketball and cricket aliases', () {
      expect(
        paletteForTeam(
          _team('LA Lakers', color: const Color(0xff552583)),
          sport: Sport.basketball,
          competition: 'nba',
        ).secondaryTextColor,
        const Color(0xfffdb927),
      );
      expect(
        paletteForTeam(
          _team('India', color: const Color(0xff0033a0)),
          sport: Sport.cricket,
          competition: '23810',
        ).secondaryTextColor,
        const Color(0xffff9933),
      );
    });

    test('derives a safe fallback only for an unseen team', () {
      final palette = paletteForTeam(
        _team('Totally Fictional Rovers', color: const Color(0xff000000)),
        sport: Sport.football,
        competition: 'unknown-league',
      );

      expect(palette.primary, Colors.black);
      for (final surface in const [
        Cyber.bg,
        Cyber.card,
        Cyber.panel,
        Cyber.chartSurface,
      ]) {
        expect(
          _contrast(palette.secondaryTextColor, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  testWidgets('TeamLogo paints only the three supplied logo roles', (
    tester,
  ) async {
    const team = SportTeam(
      id: 'cfc',
      name: 'Chelsea',
      shortName: 'CHE',
      color: Color(0xff034694),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: TeamLogo(
          team: team,
          sport: Sport.football,
          competition: 'eng.1',
          width: 60,
          height: 60,
        ),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(TeamLogo),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.painter! as TeamLogoPainter;
    expect(painter.palette.primary, const Color(0xff034694));
    expect(painter.palette.secondary, Colors.white);
    expect(painter.palette.text, Colors.white);
    expect(painter.palette.secondaryTextColor, const Color(0xff3390fb));
    expect(painter.label, 'CHE');
  });
}
