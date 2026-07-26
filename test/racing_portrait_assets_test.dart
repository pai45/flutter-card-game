import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('F1 portrait PNGs are bundled in the asset manifest', () async {
    const samples = [
      'assets/racing_driver_images/max-verstappen.png',
      'assets/racing_driver_images/lando-norris.png',
      'assets/racing_driver_images/charles-leclerc.png',
    ];
    for (final asset in samples) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
