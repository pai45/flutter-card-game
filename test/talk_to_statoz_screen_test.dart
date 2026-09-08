import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/profile/talk_to_statoz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('talk to StatOz offers support and follow options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: TalkToStatozScreen(onNavigate: (_) {}),
      ),
    );

    expect(find.text('Feedback & Enhancements'), findsNothing);
    expect(find.text('FOLLOW US ON'), findsOneWidget);
    expect(find.text('INSTAGRAM'), findsOneWidget);
    expect(find.text('REDDIT'), findsOneWidget);
    expect(find.text('YOUTUBE'), findsOneWidget);
    expect(find.text('CHANNEL 03'), findsOneWidget);
    expect(find.text('CHANNEL 04'), findsOneWidget);
  });
}
