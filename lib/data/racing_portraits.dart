import 'racing_drivers.dart';

/// F1 drivers with shipped portrait art on disk (`assets/racing_driver_images/`).
const Set<String> kRacingPortraitArtIds = {
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

const _racingPortraitRoot = 'assets/racing_driver_images';

/// Canonical portrait path for every motorsport driver (art or placeholder slot).
String racingPortraitAsset(String driverId) => '$_racingPortraitRoot/$driverId.png';

/// True when a real image file is committed for this driver id.
bool racingPortraitHasArt(String driverId) =>
    kRacingPortraitArtIds.contains(driverId);

/// Count of F1 drivers with real portrait art (full grid when all 22 ship).
int get racingPortraitArtCount => kRacingPortraitArtIds.length;

/// All driver ids in the motorsport roster.
Iterable<String> get allRacingPortraitDriverIds =>
    allRacingDrivers.map((driver) => driver.id);
