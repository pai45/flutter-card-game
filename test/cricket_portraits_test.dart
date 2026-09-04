import 'package:card_game/models/cards.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _suppliedCricketPortraitNames = <String>{
  'Devdutt Padikkal',
  'Romario Shepherd',
  'Shardul Thakur',
  'Jamie Overton',
  'Washington Sundar',
  'Ayush Badoni',
  'Tom Banton',
  'Finn Allen',
  'Marco Jansen',
  'Nitish Rana',
  'Krunal Pandya',
  'Mitchell Santner',
  'Rahul Tripathi',
  'Glenn Phillips',
  'Jason Holder',
  'Matthew Short',
  'Azmatullah Omarzai',
  'Shashank Singh',
  'Ben Duckett',
  'Dhruv Jurel',
  'Vaibhav Sooryavanshi',
  'Kamindu Mendis',
  'Rovman Powell',
  'Jitesh Sharma',
  'Josh Inglis',
  'Jonny Bairstow',
  'Sanju Samson',
  'Yashasvi Jaiswal',
  'MS Dhoni',
  'Travis Head',
  'Akeal Hosein',
  'Dewald Brevis',
  'Matt Henry',
  'Spencer Johnson',
  'Ashutosh Sharma',
  'Dushmantha Chameera',
  'Lungisani Ngidi',
  'Mukesh Kumar',
  'Ishant Sharma',
  'Kagiso Rabada',
  'Prasidh Krishna',
  'Shahrukh Khan',
  'Ajinkya Rahane',
  'Angkrish Raghuvanshi',
  'Harshit Rana',
  'Ramandeep Singh',
  'Vaibhav Arora',
  'Mohsin Khan',
  'Shahbaz Ahmed',
  'Ryan Rickelton',
  'Trent Boult',
  'Harpreet Brar',
  'Lockie Ferguson',
  'Nehal Wadhera',
  'Prabhsimran Singh',
  'Xavier Bartlett',
  'Yash Thakur',
  'Nuwan Thushara',
  'Suyash Sharma',
  'Yash Dayal',
  'Akash Deep',
  'Nandre Burger',
  'Tushar Deshpande',
  'Brydon Carse',
  'Shivam Mavi',
};

void main() {
  test('supplied cricket portraits resolve to their matching player cards', () {
    final cardsByName = {
      for (final card in cricketPlayerCards) card.name: card,
    };

    expect(_suppliedCricketPortraitNames, hasLength(65));
    expect(_suppliedCricketPortraitNames, everyElement(isIn(cardsByName)));
    for (final name in _suppliedCricketPortraitNames) {
      expect(
        cardsByName[name]!.resolvedPortraitAsset,
        cricketPortraitAssetForName(name),
        reason: name,
      );
    }
  });

  testWidgets('every supplied cricket portrait is bundled', (tester) async {
    for (final name in _suppliedCricketPortraitNames) {
      final assetPath = cricketPortraitAssetForName(name);
      final asset = await rootBundle.load(assetPath);
      expect(asset.lengthInBytes, greaterThan(0), reason: assetPath);
    }
  });
}
