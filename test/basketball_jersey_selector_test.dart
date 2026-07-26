import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/basketball/widgets/basketball_jersey_selector.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AudioController.instance.muted.value = true);

  testWidgets('Hoop Duel jersey selector shows free jersey and owned paid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedId = 'statoz';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Cyber.bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setState) => BasketballJerseySelector(
                selectedId: selectedId,
                ownedTeamIds: const ['statoz', 'lakers'],
                onSelected: (id) => setState(() => selectedId = id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('FREE JERSEYS'), findsOneWidget);
    expect(find.text('YOUR JERSEYS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('basketball-jersey-statoz')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('basketball-jersey-lakers')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('basketball-jersey-bulls')),
      findsNothing,
    );
    expect(find.text('STATOZ // EQUIPPED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('basketball-jersey-lakers')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(selectedId, 'lakers');
    expect(find.text('LOS ANGELES // EQUIPPED'), findsOneWidget);
  });
}
