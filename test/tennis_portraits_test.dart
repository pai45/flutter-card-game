import 'package:flutter/services.dart';
import 'package:card_game/data/tennis_athletes.dart';
import 'package:card_game/data/tennis_portraits.dart';
import 'package:flutter_test/flutter_test.dart';

const _suppliedTennisPortraitIds = <String>{
  'alex-de-minaur',
  'alexander-zverev',
  'amanda-anisimova',
  'anhelina-kalinina',
  'ann-li',
  'anna-kalinskaya',
  'antonia-ruzic',
  'aryna-sabalenka',
  'barbora-krejcikova',
  'belinda-bencic',
  'caty-mcnally',
  'clara-tauson',
  'coco-gauff',
  'cristina-bucsa',
  'diana-shnaider',
  'donna-vekic',
  'ekaterina-alexandrova',
  'elena-rybakina',
  'elina-svitolina',
  'emma-raducanu',
  'hailey-baptiste',
  'iga-swiatek',
  'iva-jovic',
  'janice-tjen',
  'jaqueline-cristian',
  'jasmine-paolini',
  'jelena-ostapenko',
  'jessica-pegula',
  'karolina-muchova',
  'katerina-siniakova',
  'leylah-fernandez',
  'linda-noskova',
  'magdalena-frech',
  'maja-chwalinska',
  'maria-sakkari',
  'marie-bouzkova',
  'marta-kostyuk',
  'mccartney-kessler',
  'mirra-andreeva',
  'naomi-osaka',
  'nikola-bartunkova',
  'paula-badosa',
  'petra-marcinko',
  'peyton-stearns',
  'sara-bejlek',
  'sorana-cirstea',
  'taylor-fritz',
  'talia-gibson',
  'tereza-valentova',
  'victoria-mboko',
  'viktorija-golubic',
  'wang-xinyu',
  'zeynep-sonmez',
};

void main() {
  test('supplied tennis portraits map to real roster athletes', () {
    final rosterIds = tennisTop100.map((athlete) => athlete.id).toSet();

    expect(tennisPortraitAssets, hasLength(100));
    expect(tennisPortraitAssets.keys, everyElement(isIn(rosterIds)));
    expect(_suppliedTennisPortraitIds, hasLength(53));
    expect(
      _suppliedTennisPortraitIds,
      everyElement(isIn(tennisPortraitAssets.keys)),
    );
    expect(
      tennisPortraitAssetFor('alexander-bublik'),
      'assets/tennis_player_images/alexander-bublik.png',
    );
    expect(
      tennisPortraitAssetFor('jannik-sinner'),
      'assets/tennis_player_images/jannik-sinner.webp',
    );
    expect(
      tennisPortraitAssetFor('alexander-zverev'),
      'assets/tennis_player_images/alexander-zverev.webp',
    );
    expect(
      tennisPortraitAssetFor('diana-shnaider'),
      'assets/tennis_player_images/diana-shnaider.webp',
    );
  });

  testWidgets('every mapped tennis portrait is bundled', (tester) async {
    for (final assetPath in tennisPortraitAssets.values) {
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
