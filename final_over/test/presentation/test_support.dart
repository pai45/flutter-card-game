import 'package:final_over/app/theme.dart';
import 'package:final_over/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class RecordingAudioBackend implements AudioBackend {
  final List<String> effects = <String>[];
  final List<String> loops = <String>[];
  var stopCount = 0;
  var disposeCount = 0;

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {
    effects.add(assetPath);
  }

  @override
  Future<void> startLoop(String assetPath) async {
    loops.add(assetPath);
  }

  @override
  Future<void> stopAll() async {
    stopCount++;
  }
}

final class RecordingHapticDriver implements HapticDriver {
  var lightCount = 0;
  var mediumCount = 0;
  var heavyCount = 0;

  @override
  Future<void> heavy() async {
    heavyCount++;
  }

  @override
  Future<void> light() async {
    lightCount++;
  }

  @override
  Future<void> medium() async {
    mediumCount++;
  }
}

Widget finalOverTestApp({required Widget home}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildFinalOverTheme(),
    home: home,
  );
}

void useTestViewport(WidgetTester tester, Size logicalSize) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = logicalSize;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
}

void expectNoBuildException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
