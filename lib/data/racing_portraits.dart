import 'racing_drivers.dart';

/// F1 drivers with shipped PNG portrait art on disk.
const Set<String> kRacingPngPortraitArtIds = {
  'alexander-albon',
  'arvid-lindblad',
  'carlos-sainz',
  'charles-leclerc',
  'esteban-ocon',
  'fernando-alonso',
  'franco-colapinto',
  'gabriel-bortoleto',
  'george-russell',
  'isack-hadjar',
  'kimi-antonelli',
  'lance-stroll',
  'lando-norris',
  'lewis-hamilton',
  'liam-lawson',
  'max-verstappen',
  'nico-hulkenberg',
  'oliver-bearman',
  'oscar-piastri',
  'pierre-gasly',
  'sergio-perez',
  'valtteri-bottas',
};

/// F2, NASCAR and IndyCar drivers with supplied WebP portrait art on disk.
const Set<String> kRacingWebpPortraitArtIds = {
  'aj-allmendinger',
  'alex-bowman',
  'alex-dunne',
  'alex-palou',
  'alexander-rossi',
  'austin-cindric',
  'austin-dillon',
  'brad-keselowski',
  'bubba-wallace',
  'caio-collet',
  'carson-hocevar',
  'chase-briscoe',
  'chase-elliott',
  'chris-buescher',
  'christian-lundgaard',
  'christian-rasmussen',
  'christopher-bell',
  'cian-shields',
  'cody-ware',
  'cole-custer',
  'colton-herta',
  'connor-zilisch',
  'daniel-suarez',
  'david-malukas',
  'dennis-hauger',
  'denny-hamlin',
  'dino-beganovic',
  'emerson-fittipaldi-jr',
  'erik-jones',
  'felix-rosenqvist',
  'gabriele-mini',
  'graham-rahal',
  'joey-logano',
  'john-bennett',
  'john-hunter-nemechek',
  'josh-berry',
  'joshua-durksen',
  'kush-maini',
  'kyle-busch',
  'kyle-kirkwood',
  'kyle-larson',
  'laurens-van-hoepen',
  'louis-foster',
  'marcus-armstrong',
  'marcus-ericsson',
  'mari-boya',
  'martinius-stenshorne',
  'michael-mcdowell',
  'mick-schumacher',
  'nico-varrone',
  'nikola-tsolov',
  'noah-gragson',
  'noel-leon',
  'nolan-siegel',
  'oliver-goethe',
  'pato-oward',
  'rafael-camara',
  'rafael-villagomez',
  'ricky-stenhouse-jr',
  'riley-herbst',
  'rinus-veekay',
  'ritomo-miyata',
  'romain-grosjean',
  'roman-bilinski',
  'ross-chastain',
  'ryan-blaney',
  'ryan-preece',
  'santino-ferrucci',
  'scott-dixon',
  'sebastian-montoya',
  'shane-van-gisbergen',
  'sting-ray-robb',
  'tasanapol-inthraphuvasak',
  'todd-gilliland',
  'ty-dillon',
  'ty-gibbs',
  'tyler-reddick',
  'will-power',
  'william-byron',
  'zane-smith',
};

/// Every motorsport driver with shipped portrait art on disk.
const Set<String> kRacingPortraitArtIds = {
  ...kRacingPngPortraitArtIds,
  ...kRacingWebpPortraitArtIds,
};

const _racingPortraitRoot = 'assets/racing_driver_images';

/// Canonical portrait path for every motorsport driver (art or placeholder slot).
String racingPortraitAsset(String driverId) {
  final extension = kRacingWebpPortraitArtIds.contains(driverId)
      ? 'webp'
      : 'png';
  return '$_racingPortraitRoot/$driverId.$extension';
}

/// True when a real image file is committed for this driver id.
bool racingPortraitHasArt(String driverId) =>
    kRacingPortraitArtIds.contains(driverId);

/// Count of F1 drivers with real portrait art (full grid when all 22 ship).
int get racingPortraitArtCount => kRacingPortraitArtIds.length;

/// All driver ids in the motorsport roster.
Iterable<String> get allRacingPortraitDriverIds =>
    allRacingDrivers.map((driver) => driver.id);
