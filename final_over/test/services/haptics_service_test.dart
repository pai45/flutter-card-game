import 'package:final_over/services/haptics_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHaptics implements HapticDriver {
  final calls = <String>[];

  @override
  Future<void> heavy() async => calls.add('heavy');

  @override
  Future<void> light() async => calls.add('light');

  @override
  Future<void> medium() async => calls.add('medium');
}

void main() {
  test('haptics maps cues and respects enabled state', () async {
    final driver = _FakeHaptics();
    final service = HapticsService(driver: driver);
    await service.play(HapticCue.tap);
    await service.play(HapticCue.perfectContact);
    await service.play(HapticCue.six);
    service.setEnabled(false);
    await service.play(HapticCue.wicket);
    expect(driver.calls, ['light', 'medium', 'heavy']);
  });
}
