import 'package:card_game/data/final_over_kits.dart';
import 'package:card_game/models/deck.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finalOver kit pricing marks voltage free and others at 100 coins', () {
    final free = finalOverKitById(finalOverFreeKitId);
    final paid = finalOverKitById('ember');

    expect(isFinalOverKitFree(free), isTrue);
    expect(finalOverKitPrice(free), 0);
    expect(isFinalOverKitFree(paid), isFalse);
    expect(finalOverKitPrice(paid), finalOverKitCoinPrice);
  });

  test('normalizeOwnedFinalOverKitIds always includes the free kit', () {
    expect(normalizeOwnedFinalOverKitIds(const ['ember']), contains('voltage'));
  });

  test('finalOverBatsmen persists in deck slot json', () {
    const slot = StoredDeckSlot(
      id: 'slot-test',
      name: 'Test',
      attackers: [],
      defenders: [],
      actions: [],
      finalOverBatsmen: [
        'ind-virat-kohli',
        'eng-joe-root',
        'pak-babar-azam',
      ],
    );

    final restored = StoredDeckSlot.fromJson(slot.toJson());

    expect(restored.finalOverBatsmen, slot.finalOverBatsmen);
  });

  test('legacy batsmen json migrates into finalOverBatsmen', () {
    final restored = StoredDeckSlot.fromJson({
      'id': 'slot-legacy',
      'name': 'Legacy',
      'attackers': <String>[],
      'defenders': <String>[],
      'actions': <String>[],
      'batsmen': ['ind-virat-kohli', 'eng-joe-root', 'afg-rahmanullah-gurbaz'],
    });

    expect(
      restored.finalOverBatsmen,
      ['ind-virat-kohli', 'eng-joe-root', 'afg-rahmanullah-gurbaz'],
    );
  });
}
