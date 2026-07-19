import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/final_over/widgets/final_over_kit_picker.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AudioController.instance.muted.value = true);

  testWidgets('Final Over kit locker shows and equips named batter kits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedId = 'voltage';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Cyber.bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setState) => FinalOverKitPicker(
                selectedId: selectedId,
                onSelected: (id) => setState(() => selectedId = id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    for (final id in [
      'voltage',
      'ember',
      'meridian',
      'sovereign',
      'monsoon',
      'saffron',
      'obsidian',
      'coral',
    ]) {
      expect(find.byKey(ValueKey('final-over-kit-$id')), findsOneWidget);
    }
    expect(find.text('VOLTAGE // EQUIPPED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('final-over-kit-coral')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(selectedId, 'coral');
    expect(find.text('CORAL // EQUIPPED'), findsOneWidget);
  });
}
