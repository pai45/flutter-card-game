import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/data/basketball_portraits.dart';
import 'package:card_game/models/cards.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _suppliedBasketballPortraitIds = <String>{
  'uta-ace-bailey',
  'ind-aaron-nesmith',
  'hou-amen-thompson',
  'ind-andrew-nembhard',
  'det-ausar-thompson',
  'chi-ayo-dosunmu',
  'bos-baylor-scheierman',
  'ind-bennedict-mathurin',
  'gsw-brandin-podziemski',
  'den-cam-johnson',
  'bkn-cam-thomas',
  'den-christian-braun',
  'dal-cooper-flagg',
  'dal-daniel-gafford',
  'cle-deandre-hunter',
  'hou-jabari-smith-jr',
  'atl-jalen-johnson',
  'lac-james-harden',
  'chi-josh-giddey',
  'den-julian-strawther',
  'cha-kon-knueppel',
  'cha-kylan-boswell',
  'chi-matas-buzelis',
  'cle-max-strus',
  'gsw-moses-moody',
  'cha-moussa-diabate',
  'bos-neemias-queta',
  'atl-nickeil-alexander-walker',
  'den-nikola-jokic',
  'bkn-noah-clowney',
  'ind-obi-toppin',
  'atl-onyeka-okongwu',
  'dal-pj-washington',
  'hou-reed-sheppard',
  'det-ron-holland',
  'gsw-stephen-curry',
  'hou-steven-adams',
  'bkn-terance-mann',
  'chi-tobe-awaka',
  'bkn-tyler-bilodeau',
  'atl-zaccharie-risacher',
  'mil-alex-antetokounmpo',
  'okc-alex-caruso',
  'orl-anthony-black',
  'mia-bam-adebayo',
  'lac-bogdan-bogdanovic',
  'okc-brooks-barnhizer',
  'mem-cameron-boozer',
  'okc-chet-holmgren',
  'mil-cole-anthony',
  'mia-davion-mitchell',
  'nop-dejounte-murray',
  'orl-desmond-bane',
  'orl-goga-bitadze',
  'nop-herb-jones',
  'lac-ivica-zubac',
  'mem-ja-morant',
  'min-jaden-mcdaniels',
  'mia-jaime-jaquez-jr',
  'orl-jalen-suggs',
  'phi-jared-mccain',
  'mem-jaren-jackson-jr',
  'lal-jaxson-hayes',
  'nop-jordan-hawkins',
  'nyk-jose-alvarado',
  'nyk-josh-hart',
  'mia-kelel-ware',
  'uta-keyonte-george',
  'uta-lauri-markkanen',
  'mil-kevin-porter-jr',
  'okc-lu-dort',
  'lal-marcus-smart',
  'mil-nate-ament',
  'min-naz-reid',
  'lac-nicolas-batum',
  'min-rob-dillingham',
  'mem-santi-aldama',
  'mem-scotty-pippen-jr',
  'okc-shai-gilgeous-alexander',
  'nop-trey-murphy-iii',
  'phi-tyrese-maxey',
  'nop-yves-missi',
  'mem-zach-edey',
  'uta-tamar-bates',
  'uta-trey-alexander',
  'uta-walker-kessler',
  'was-alex-sarr',
  'was-anthony-davis',
  'was-bilal-coulibaly',
  'was-bub-carrington',
  'was-tre-johnson',
  'sac-demar-derozan',
  'sac-precious-achiuwa',
  'sac-darius-acuff-jr',
  'sas-victor-wembanyama',
  'sas-stephon-castle',
  'sas-devin-vassell',
  'sas-harrison-barnes',
  'sas-bismack-biyombo',
  'tor-jakob-poeltl',
  'tor-gradey-dick',
  'phi-adem-bona',
  'phi-dominick-barlow',
  'phx-dillon-brooks',
  'phx-ryan-dunn',
  'phx-oso-ighodaro',
  'por-deni-avdija',
  'por-scoot-henderson',
  'por-shaedon-sharpe',
  'por-donovan-clingan',
  'por-robert-williams-iii',
};

void main() {
  test('supplied basketball portraits map to current roster athletes', () {
    final rosterIds = basketballAthletes.map((athlete) => athlete.id).toSet();

    expect(basketballPortraitAssets, hasLength(180));
    expect(basketballPortraitAssets.keys, everyElement(isIn(rosterIds)));
    expect(_suppliedBasketballPortraitIds, hasLength(111));
    expect(
      _suppliedBasketballPortraitIds,
      everyElement(isIn(basketballPortraitAssets.keys)),
    );
    final cardPortraits = {
      for (final card in basketballPlayerCards) card.id: card.portraitAsset,
    };
    basketballPortraitAssets.forEach((athleteId, assetPath) {
      expect(cardPortraits[athleteId], assetPath, reason: athleteId);
    });
    expect(
      basketballPortraitAssetFor('lal-lebron-james'),
      'assets/basketball_player_images/lebron_james.webp',
    );
    expect(
      basketballPortraitAssetFor('lal-austin-reaves'),
      'assets/basketball_player_images/austin_reaves.webp',
    );
    expect(
      basketballPortraitAssetFor('gsw-stephen-curry'),
      'assets/basketball_player_images/stephen_curry.webp',
    );
    expect(
      basketballPortraitAssetFor('dal-cooper-flagg'),
      'assets/basketball_player_images/cooper_flagg.webp',
    );
  });

  testWidgets('every mapped basketball portrait is bundled', (tester) async {
    for (final assetPath in basketballPortraitAssets.values) {
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
