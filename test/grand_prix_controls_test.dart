import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/grand_prix/widgets/grand_prix_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'three fingers can steer, accelerate and deploy; cancel releases only its owner',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var steering = 0.0;
      var throttle = false;
      var deploy = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: GrandPrixControls(
                  onLeft: (_) {},
                  onRight: (_) {},
                  onBrake: (_) {},
                  onSteer: (v) => steering = v,
                  onThrottle: (v) => throttle = v,
                  onDeploy: (v) => deploy = v,
                ),
              ),
            ),
          ),
        ),
      );
      final steer = await tester.startGesture(
        tester.getCenter(find.text('STEER')),
        pointer: 1,
      );
      await steer.moveBy(const Offset(28, 0));
      final accel = await tester.startGesture(
        tester.getCenter(find.text('ACCEL')),
        pointer: 2,
      );
      final ers = await tester.startGesture(
        tester.getCenter(find.text('ERS')),
        pointer: 3,
      );
      expect(steering, greaterThan(0));
      expect(throttle && deploy, isTrue);
      await steer.cancel();
      expect(steering, 0);
      expect(throttle && deploy, isTrue);
      await ers.up();
      expect(deploy, isFalse);
      expect(throttle, isTrue);
      // Pause removes controls and releases a held accelerator.
      await tester.pumpWidget(const SizedBox());
      expect(throttle, isFalse);
      await accel.up();
      expect(tester.takeException(), isNull);
    },
  );
}
