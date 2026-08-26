/// Bundled portraits for Hoop Duel athletes with supplied player art.
///
/// The map is deliberately partial. Athletes without supplied art retain the
/// collectible-card icon fallback rather than pointing at a missing asset.
const basketballPortraitAssets = <String, String>{
  'atl-trae-young': 'assets/basketball_player_images/trae_young.webp',
  'atl-kristaps-porzingis':
      'assets/basketball_player_images/kristaps_porzingis.webp',
  'bos-jayson-tatum': 'assets/basketball_player_images/jayson_tatum.webp',
  'bos-jaylen-brown': 'assets/basketball_player_images/jaylen_brown.webp',
  'bos-derrick-white': 'assets/basketball_player_images/derrick_white.webp',
  'bkn-michael-porter-jr':
      'assets/basketball_player_images/michael_porter_jr.webp',
  'bkn-nic-claxton': 'assets/basketball_player_images/nic_claxton.webp',
  'chi-coby-white': 'assets/basketball_player_images/coby_white.webp',
  'chi-nikola-vucevic': 'assets/basketball_player_images/nikola_vucevic.webp',
  'cle-donovan-mitchell':
      'assets/basketball_player_images/donovan_mitchell.webp',
  'cle-evan-mobley': 'assets/basketball_player_images/evan_mobley.webp',
  'cle-darius-garland': 'assets/basketball_player_images/darius_garland.webp',
  'cle-jarrett-allen': 'assets/basketball_player_images/jarrett_allen.webp',
  'dal-kyrie-irving': 'assets/basketball_player_images/kyrie_irving.webp',
  'dal-klay-thompson': 'assets/basketball_player_images/klay_thompson.webp',
  'den-jamal-murray': 'assets/basketball_player_images/jamal_murray.webp',
  'den-aaron-gordon': 'assets/basketball_player_images/aaron_gordon.webp',
  'det-cade-cunningham': 'assets/basketball_player_images/cade_cunningham.webp',
  'det-jaden-ivey': 'assets/basketball_player_images/jaden_ivey.webp',
  'det-tobias-harris': 'assets/basketball_player_images/tobias_harris.webp',
  'det-jalen-duren': 'assets/basketball_player_images/jalen_duren.webp',
  'gsw-jimmy-butler': 'assets/basketball_player_images/jimmy_butler.webp',
  'gsw-draymond-green': 'assets/basketball_player_images/draymond_green.webp',
  'hou-kevin-durant': 'assets/basketball_player_images/kevin_durant.webp',
  'hou-alperen-sengun': 'assets/basketball_player_images/alperen_sengun.webp',
  'ind-tyrese-haliburton':
      'assets/basketball_player_images/tyrese_haliburton.webp',
  'ind-pascal-siakam': 'assets/basketball_player_images/pascal_siakam.webp',
  'lac-kawhi-leonard': 'assets/basketball_player_images/kawhi_leonard.webp',
  'lac-bradley-beal': 'assets/basketball_player_images/bradley_beal.webp',
  'lal-luka-doncic': 'assets/basketball_player_images/luka_doncic.webp',
  'lal-lebron-james': 'assets/basketball_player_images/lebron_james.webp',
  'mia-giannis-antetokounmpo':
      'assets/basketball_player_images/giannis_antetokounmpo.webp',
  'mia-tyler-herro': 'assets/basketball_player_images/tyler_herro.webp',
  'min-anthony-edwards': 'assets/basketball_player_images/anthony_edwards.webp',
  'min-julius-randle': 'assets/basketball_player_images/julius_randle.webp',
  'min-rudy-gobert': 'assets/basketball_player_images/rudy_gobert.webp',
  'nop-zion-williamson': 'assets/basketball_player_images/zion_williamson.webp',
  'nyk-jalen-brunson': 'assets/basketball_player_images/jalen_brunson.webp',
  'nyk-karl-anthony-towns':
      'assets/basketball_player_images/karl_anthony_towns.webp',
  'nyk-mikal-bridges': 'assets/basketball_player_images/mikal_bridges.webp',
  'nyk-og-anunoby': 'assets/basketball_player_images/og_anunoby.webp',
  'okc-jalen-williams': 'assets/basketball_player_images/jalen_williams.webp',
  'orl-paolo-banchero': 'assets/basketball_player_images/paolo_banchero.webp',
  'orl-franz-wagner': 'assets/basketball_player_images/franz_wagner.webp',
  'phi-joel-embiid': 'assets/basketball_player_images/joel_embiid.webp',
  'phi-paul-george': 'assets/basketball_player_images/paul_george.webp',
  'phx-devin-booker': 'assets/basketball_player_images/devin_booker.webp',
  'sac-domantas-sabonis':
      'assets/basketball_player_images/domantas_sabonis.webp',
  'sac-zach-lavine': 'assets/basketball_player_images/zach_lavine.webp',
  'sac-keegan-murray': 'assets/basketball_player_images/keegan_murray.webp',
  'sas-deaaron-fox': 'assets/basketball_player_images/deaaron_fox.webp',
  'tor-scottie-barnes': 'assets/basketball_player_images/scottie_barnes.webp',
  'tor-brandon-ingram': 'assets/basketball_player_images/brandon_ingram.webp',
  'tor-rj-barrett': 'assets/basketball_player_images/rj_barrett.webp',
  'tor-immanuel-quickley':
      'assets/basketball_player_images/immanuel_quickley.webp',
  'bos-payton-pritchard':
      'assets/basketball_player_images/payton_pritchard.webp',
  'cha-lamelo-ball': 'assets/basketball_player_images/lamelo_ball.webp',
  'cha-brandon-miller': 'assets/basketball_player_images/brandon_miller.webp',
  'cha-miles-bridges': 'assets/basketball_player_images/miles_bridges.webp',
  'dal-dereck-lively-ii':
      'assets/basketball_player_images/dereck_lively_ii.webp',
  'gsw-jonathan-kuminga':
      'assets/basketball_player_images/jonathan_kuminga.webp',
  'lal-austin-reaves': 'assets/basketball_player_images/austin_reaves.webp',
  'lal-rui-hachimura': 'assets/basketball_player_images/rui_hachimura.webp',
  'mil-kyle-kuzma': 'assets/basketball_player_images/kyle_kuzma.webp',
  'mil-bobby-portis': 'assets/basketball_player_images/bobby_portis.webp',
  'phx-jalen-green': 'assets/basketball_player_images/jalen_green.webp',
  'phx-grayson-allen': 'assets/basketball_player_images/grayson_allen.webp',
  'por-jerami-grant': 'assets/basketball_player_images/jerami_grant.webp',
  'was-deandre-ayton': 'assets/basketball_player_images/deandre_ayton.webp',
};

String? basketballPortraitAssetFor(String athleteId) =>
    basketballPortraitAssets[athleteId];
