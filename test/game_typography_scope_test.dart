import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('game route changes body text and keeps Orbitron display', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text('Matches body', style: Cyber.bodyFor(context, 14)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    gamePageRoute<void>(builder: (_) => const _GameProbe()),
                  ),
                  child: const Text('Open game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Matches body')).style?.fontFamily,
      Cyber.bodyFont,
    );
    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Game body')).style?.fontFamily,
      Cyber.gameBodyFont,
    );
    expect(
      tester.widget<Text>(find.text('Game display')).style?.fontFamily,
      Cyber.displayFont,
    );
    expect(
      tester.widget<Text>(find.text('Game utility')).style?.fontFamily,
      Cyber.gameBodyFont,
    );
    expect(
      tester.widget<Text>(find.text('Game title')).style?.fontFamily,
      Cyber.displayFont,
    );
  });
}

class _GameProbe extends StatelessWidget {
  const _GameProbe();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Game body', style: Cyber.bodyFor(context, 14)),
        Text('Game display', style: Cyber.display(14)),
        Text(
          'Game utility',
          style: Theme.of(context).listTileTheme.titleTextStyle,
        ),
        Text('Game title', style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
