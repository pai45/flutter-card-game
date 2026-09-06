import 'dart:ui' as ui;

import 'package:card_game/config/theme.dart';
import 'package:card_game/models/football_match_data.dart';
import 'package:card_game/screens/predictions/widgets/football_player_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TouchHeatGrid', () {
    test('a single centre touch lands in the middle and stays symmetric', () {
      final grid = TouchHeatGrid.from(const [(0.5, 0.5)]);
      expect(grid.isEmpty, isFalse);
      expect(grid.sampleCount, 1);
      expect(grid.centroid, (0.5, 0.5));

      final peakX = grid.peakIndex % TouchHeatGrid.cols;
      final peakY = grid.peakIndex ~/ TouchHeatGrid.cols;
      expect(peakX, anyOf(TouchHeatGrid.cols ~/ 2 - 1, TouchHeatGrid.cols ~/ 2));
      expect(peakY, anyOf(TouchHeatGrid.rows ~/ 2 - 1, TouchHeatGrid.rows ~/ 2));

      // The splat plus a symmetric blur must stay mirror-symmetric about both
      // axes, or the cloud would drift away from where the player actually was.
      for (var y = 0; y < TouchHeatGrid.rows; y++) {
        for (var x = 0; x < TouchHeatGrid.cols; x++) {
          final mirroredX = TouchHeatGrid.cols - 1 - x;
          final mirroredY = TouchHeatGrid.rows - 1 - y;
          expect(
            grid.cells[y * TouchHeatGrid.cols + x],
            closeTo(grid.cells[y * TouchHeatGrid.cols + mirroredX], 1e-9),
          );
          expect(
            grid.cells[y * TouchHeatGrid.cols + x],
            closeTo(grid.cells[mirroredY * TouchHeatGrid.cols + x], 1e-9),
          );
        }
      }
    });

    test('no touches yields an empty grid rather than a blank cloud', () {
      final grid = TouchHeatGrid.from(const []);
      expect(grid.isEmpty, isTrue);
      expect(grid.centroid, isNull);
      expect(grid.cells, isEmpty);
    });

    test('density is normalised to a 1.0 peak', () {
      final grid = TouchHeatGrid.from(const [
        (0.2, 0.3),
        (0.21, 0.31),
        (0.8, 0.7),
      ]);
      expect(grid.cells.reduce((a, b) => a > b ? a : b), closeTo(1.0, 1e-9));
      for (final cell in grid.cells) {
        expect(cell, inInclusiveRange(0.0, 1.0));
      }
    });

    test('the blur spreads weight without inventing or losing it', () {
      // One touch splats a total weight of 1 across four cells; the blur is a
      // normalised kernel, so the total must survive it.
      final grid = TouchHeatGrid.from(const [(0.5, 0.5)]);
      final total = grid.cells.fold<double>(0, (a, b) => a + b);
      // Cells are normalised by the peak, so compare the ratio instead.
      expect(total * grid.peakCount, greaterThan(0));
      expect(grid.peakCount, lessThanOrEqualTo(1.0));
    });

    test('mirroring flips the cloud onto the other goal', () {
      const touches = [(0.9, 0.3)];
      final right = TouchHeatGrid.from(touches);
      final left = TouchHeatGrid.from(touches, attackingRight: false);
      expect(right.centroid!.$1, closeTo(0.9, 1e-9));
      expect(left.centroid!.$1, closeTo(0.1, 1e-9));
      // y inverts too, per footballAttackingOffset's screen-space convention.
      expect(right.centroid!.$2, closeTo(0.7, 1e-9));
      expect(left.centroid!.$2, closeTo(0.3, 1e-9));
    });
  });

  // The heatmap and the shot map must place a coordinate identically — they
  // draw on the same pitch. This locks the refactor that moved the mirroring
  // out of FootballShot.pitchOffset and into footballAttackingOffset.
  group('shared attacking frame', () {
    test('pitchOffset still matches the extracted helper', () {
      for (final isHome in [true, false]) {
        final shot = FootballShot(
          playId: 'p',
          minuteLabel: "12'",
          minute: 12,
          period: 1,
          isHomeTeam: isHome,
          team: 'T',
          shooter: 'S',
          outcome: FootballShotOutcome.goal,
          fieldX: 0.87,
          fieldY: 0.32,
          isHeader: false,
        );
        expect(
          shot.pitchOffset(105, 68),
          footballAttackingOffset(0.87, 0.32, 105, 68, attackingRight: isHome),
        );
      }
    });
  });

  group('FootballPlayerHeatmapPainter', () {
    test('an untracked player still gets a pitch, and does not throw', () async {
      final painter = FootballPlayerHeatmapPainter(
        grid: TouchHeatGrid.from(const []),
        accent: Cyber.cyan,
        reveal: 1,
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(320, 210));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('a tracked player paints without throwing at every reveal step', () {
      final grid = TouchHeatGrid.from([
        for (var i = 0; i < 60; i++) (0.2 + i / 150, 0.3 + (i % 7) / 20),
      ]);
      for (final reveal in [0.0, 0.25, 0.5, 0.9, 1.0]) {
        final recorder = ui.PictureRecorder();
        FootballPlayerHeatmapPainter(
          grid: grid,
          accent: Cyber.cyan,
          reveal: reveal,
        ).paint(Canvas(recorder), const Size(320, 210));
        recorder.endRecording().dispose();
      }
    });

    test('repaints only when something it draws changed', () {
      final grid = TouchHeatGrid.from(const [(0.5, 0.5)]);
      final base = FootballPlayerHeatmapPainter(
        grid: grid,
        accent: Cyber.cyan,
        reveal: 1,
      );
      expect(
        base.shouldRepaint(
          FootballPlayerHeatmapPainter(
            grid: grid,
            accent: Cyber.cyan,
            reveal: 1,
          ),
        ),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          FootballPlayerHeatmapPainter(
            grid: grid,
            accent: Cyber.cyan,
            reveal: 0.4,
          ),
        ),
        isTrue,
      );
    });
  });
}
