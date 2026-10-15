import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/game_discovery.g.dart';
import 'package:card_game/widgets/cyber/game_launch_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 18 persistent game ids retain their Flutter accents', () {
    final accents = [
      AppTheme.gamePitchDuel,
      AppTheme.gamePenalty,
      AppTheme.gameFootballQuiz,
      AppTheme.gameFootballMystery,
      AppTheme.gameFootballBingo,
      AppTheme.gameFootballChess,
      AppTheme.gameFinalOver,
      AppTheme.gameCricketQuiz,
      AppTheme.gameCricketMystery,
      AppTheme.gameHoopDuel,
      AppTheme.gameBasketballQuiz,
      AppTheme.gameBasketballMystery,
      AppTheme.gameGrandPrix,
      AppTheme.gameMotorsportQuiz,
      AppTheme.gameDriverMystery,
      AppTheme.gameTennisRally,
      AppTheme.gameTennisQuiz,
      AppTheme.gameWinnerMystery,
    ];
    final games = (gameDiscoveryData['games'] as Map<String, dynamic>).values
        .toList();
    expect(games.length, ArcadeGame.values.length);
    for (var i = 0; i < games.length; i++) {
      expect(
        (games[i]['accent'] as String).toUpperCase(),
        '#${accents[i].toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      );
      final frames = games[i]['layers'][2]['frames'] as List<dynamic>;
      final first = sampleDiscoveryMotion(frames, 0),
          last = sampleDiscoveryMotion(frames, 1);
      expect(
        [first.x, first.y, first.rotate, first.scale, first.opacity],
        [last.x, last.y, last.rotate, last.scale, last.opacity],
      );
      expect(
        sampleDiscoveryMotion(frames, .28).opacity,
        inInclusiveRange(0, 1),
      );
    }
    // A non-keyframe phase catches evaluator/easing drift against the web generator.
    final pose = sampleDiscoveryMotion(
      games.first['layers'][2]['frames'] as List<dynamic>,
      .28,
    );
    final u = (.28 - .12) / (.4 - .12), eased = u * u * (3 - 2 * u);
    expect(pose.x, closeTo(39 * eased, 1e-10));
    expect(pose.y, closeTo(-19 * eased, 1e-10));
  });

  testWidgets('every game has contained filled SVGs at a fixed review pose', (
    tester,
  ) async {
    for (final game in ArcadeGame.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 180,
              height: 132,
              child: CyberGameIllustration(
                art: CyberGameArt.tactics,
                game: game,
                accent: AppTheme.gamePitchDuel,
                phase: .28,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: game.name);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });

  testWidgets('offscreen scrolling and app lifecycle stop and resume loops', (
    tester,
  ) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: const [
            SizedBox(
              height: 180,
              child: CyberGameIllustration(
                art: CyberGameArt.cricket,
                accent: AppTheme.gameFinalOver,
              ),
            ),
            SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    scroll.jumpTo(900);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    scroll.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
