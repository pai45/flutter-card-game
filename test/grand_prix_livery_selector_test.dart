import 'package:card_game/config/theme.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:card_game/screens/grand_prix/widgets/grand_prix_livery_selector.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AudioController.instance.muted.value = true);

  testWidgets('Grand Prix livery selector shows free livery and owned paid liveries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selected = GrandPrixLivery.gridLine;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Cyber.bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setState) => GrandPrixLiverySelector(
                selected: selected,
                ownedLiveryIds: const ['gridLine', 'scarlet'],
                onSelected: (livery) => setState(() => selected = livery),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('FREE LIVERIES'), findsOneWidget);
    expect(find.text('YOUR LIVERIES'), findsOneWidget);
    expect(find.byKey(const ValueKey('gp-livery-gridLine')), findsOneWidget);
    expect(find.byKey(const ValueKey('gp-livery-scarlet')), findsOneWidget);
    expect(find.byKey(const ValueKey('gp-livery-papaya')), findsNothing);
    expect(find.text('GRID LINE // EQUIPPED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gp-livery-scarlet')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(selected, GrandPrixLivery.scarlet);
    expect(find.text('SCARLET // EQUIPPED'), findsOneWidget);
  });
}
