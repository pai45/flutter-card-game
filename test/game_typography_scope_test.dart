import 'package:card_game/design_system/typography.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared Material roles and body weights match the product contract', () {
    final theme = AppTheme.darkTheme;
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodySmall?.fontSize, 12);
    expect(theme.textTheme.titleLarge?.fontSize, 18);
    expect(theme.textTheme.headlineLarge?.fontSize, 24);
    expect(theme.textTheme.displayLarge?.fontSize, 28);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Space Grotesk');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Orbitron');
    expect(Cyber.body(14, weight: FontWeight.w900).fontWeight, FontWeight.w700);
    expect(StatOzTypography.control.fontWeight, FontWeight.w600);
    expect(
      theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
      'Space Grotesk',
    );
  });

  testWidgets('shared body and control preserve platform text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Column(
              children: [
                const Text('Scaled body', style: StatOzTypography.body),
                FilledButton(
                  onPressed: () {},
                  child: const Text('Scaled control'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.text('Scaled body'));
    expect(MediaQuery.textScalerOf(context).scale(14), 28);
    expect(tester.takeException(), isNull);
  });
  testWidgets('game routes share body typography and keep Orbitron display', (
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
