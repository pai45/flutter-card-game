/// Bundled portraits for tennis athletes with supplied player art.
///
/// The map is intentionally partial: athletes without a supplied portrait keep
/// the UI's existing icon fallback rather than pointing at a missing asset.
const tennisPortraitAssets = <String, String>{
  'jannik-sinner': 'assets/tennis_player_images/jannik-sinner.webp',
  'carlos-alcaraz': 'assets/tennis_player_images/carlos-alcaraz.webp',
  'felix-auger-aliassime':
      'assets/tennis_player_images/felix-auger-aliassime.webp',
  'ben-shelton': 'assets/tennis_player_images/ben-shelton.webp',
  'novak-djokovic': 'assets/tennis_player_images/novak-djokovic.webp',
  'daniil-medvedev': 'assets/tennis_player_images/daniil-medvedev.webp',
  'flavio-cobolli': 'assets/tennis_player_images/flavio-cobolli.webp',
  'alexander-bublik': 'assets/tennis_player_images/alexander-bublik.png',
  'jiri-lehecka': 'assets/tennis_player_images/jiri-lehecka.png',
  'casper-ruud': 'assets/tennis_player_images/casper-ruud.png',
  'lorenzo-musetti': 'assets/tennis_player_images/lorenzo-musetti.png',
  'learner-tien': 'assets/tennis_player_images/learner-tien.png',
  'andrey-rublev': 'assets/tennis_player_images/andrey-rublev.png',
  'frances-tiafoe': 'assets/tennis_player_images/frances-tiafoe.png',
  'luciano-darderi': 'assets/tennis_player_images/luciano-darderi.png',
  'jakub-mensik': 'assets/tennis_player_images/jakub-mensik.png',
  'alejandro-davidovich-fokina':
      'assets/tennis_player_images/alejandro-davidovich-fokina.png',
  'valentin-vacherot': 'assets/tennis_player_images/valentin-vacherot.webp',
  'francisco-cerundolo': 'assets/tennis_player_images/francisco-cerundolo.webp',
  'arthur-fils': 'assets/tennis_player_images/arthur-fils.webp',
  'tommy-paul': 'assets/tennis_player_images/tommy-paul.webp',
  'rafael-jodar': 'assets/tennis_player_images/rafael-jodar.webp',
  'karen-khachanov': 'assets/tennis_player_images/karen-khachanov.webp',
  'joao-fonseca': 'assets/tennis_player_images/joao-fonseca.webp',
  'arthur-rinderknech': 'assets/tennis_player_images/arthur-rinderknech.webp',
  'ugo-humbert': 'assets/tennis_player_images/ugo-humbert.webp',
  'tomas-martin-etcheverry':
      'assets/tennis_player_images/tomas-martin-etcheverry.webp',
  'alejandro-tabilo': 'assets/tennis_player_images/alejandro-tabilo.webp',
  'brandon-nakashima': 'assets/tennis_player_images/brandon-nakashima.webp',
  'ignacio-buse': 'assets/tennis_player_images/ignacio-buse.webp',
  'matteo-arnaldi': 'assets/tennis_player_images/matteo-arnaldi.webp',
  'zizou-bergs': 'assets/tennis_player_images/zizou-bergs.webp',
  'arthur-fery': 'assets/tennis_player_images/arthur-fery.webp',
  'alexander-blockx': 'assets/tennis_player_images/alexander-blockx.webp',
  'cameron-norrie': 'assets/tennis_player_images/cameron-norrie.webp',
  'denis-shapovalov': 'assets/tennis_player_images/denis-shapovalov.webp',
  'corentin-moutet': 'assets/tennis_player_images/corentin-moutet.webp',
  'jan-lennard-struff': 'assets/tennis_player_images/jan-lennard-struff.webp',
  'raphael-collignon': 'assets/tennis_player_images/raphael-collignon.webp',
  'matteo-berrettini': 'assets/tennis_player_images/matteo-berrettini.webp',
  'jaume-munar': 'assets/tennis_player_images/jaume-munar.webp',
  'juan-manuel-cerundolo':
      'assets/tennis_player_images/juan-manuel-cerundolo.webp',
  'alex-michelsen': 'assets/tennis_player_images/alex-michelsen.webp',
  'ethan-quinn': 'assets/tennis_player_images/ethan-quinn.webp',
  'mariano-navone': 'assets/tennis_player_images/mariano-navone.webp',
  'adrian-mannarino': 'assets/tennis_player_images/adrian-mannarino.webp',
  'terence-atmane': 'assets/tennis_player_images/terence-atmane.webp',
};

String? tennisPortraitAssetFor(String athleteId) =>
    tennisPortraitAssets[athleteId];
