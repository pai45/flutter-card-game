import 'dart:convert';

import 'package:card_game/data/super_over_batter_profiles.dart';
import 'package:card_game/data/super_over_jerseys.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/super_over.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fictional Super Over batter adapter', () {
    test('keeps shared mechanics but exposes only mode-local identity', () {
      final cards = cricketBattingCards.take(12).toList(growable: false);
      final profiles = SuperOverBatterProfiles.fromBattingOrder(cards.take(3));

      expect(profiles, hasLength(3));
      for (var index = 0; index < profiles.length; index++) {
        final card = cards[index];
        final profile = profiles[index];
        final presentation = profile.toPresentationJson();
        final encoded = jsonEncode(presentation).toLowerCase();

        expect(profile.cardId, card.id);
        expect(profile.rating, card.rating);
        expect(profile.battingPosition, index + 1);
        expect(profile.displayName, matches(RegExp(r'^[A-Z]+ [0-9]{2}$')));
        expect(presentation.values, isNot(contains(card.name)));
        expect(presentation.values, isNot(contains(card.shortName)));
        expect(presentation.values, isNot(contains(card.country)));
        expect(presentation.values, isNot(contains(card.countryCode)));
        if (card.resolvedPortraitAsset case final portrait?) {
          expect(encoded, isNot(contains(portrait.toLowerCase())));
        }
        expect(
          presentation.keys,
          unorderedEquals([
            'displayName',
            'rating',
            'archetype',
            'battingPosition',
            'jerseyNumber',
            'visualSeed',
          ]),
        );
      }
    });

    test(
      'identity is stable by shared ID and never depends on real metadata',
      () {
        final card = cricketBattingCards.first;
        final first = SuperOverBatterProfiles.fromCard(card, orderIndex: 0);
        final again = SuperOverBatterProfiles.fromCard(card, orderIndex: 2);

        expect(again.displayName, first.displayName);
        expect(again.jerseyNumber, first.jerseyNumber);
        expect(again.visualSeed, first.visualSeed);
        expect(again.rating, first.rating);
        expect(first.battingPosition, 1);
        expect(again.battingPosition, 3);
      },
    );

    test('shared traits map to the three gameplay archetypes', () {
      final anchor = cricketBattingCards.firstWhere(
        (card) => card.trait == 'Batsman',
      );
      final power = cricketBattingCards.firstWhere(
        (card) => card.trait == 'All-rounder',
      );
      final improviser = cricketBattingCards.firstWhere(
        (card) => card.trait == 'Wicket-keeper',
      );

      expect(
        SuperOverBatterProfiles.fromCard(anchor, orderIndex: 0).archetype,
        CricketBattingStyle.anchor,
      );
      expect(
        SuperOverBatterProfiles.fromCard(power, orderIndex: 1).archetype,
        CricketBattingStyle.powerHitter,
      );
      expect(
        SuperOverBatterProfiles.fromCard(improviser, orderIndex: 2).archetype,
        CricketBattingStyle.improviser,
      );
    });
  });

  group('original Super Over jerseys', () {
    test('ships exactly six neutral colorways with stable IDs', () {
      expect(cricketJerseys, hasLength(6));
      expect(cricketJerseys.map((jersey) => jersey.id), [
        'nightCyan',
        'violetPulse',
        'goldStrike',
        'emberRed',
        'tealVector',
        'monoIce',
      ]);
      expect(cricketJerseys.map((jersey) => jersey.name), [
        'NIGHT CYAN',
        'VIOLET PULSE',
        'GOLD STRIKE',
        'EMBER RED',
        'TEAL VECTOR',
        'MONO ICE',
      ]);
      expect(
        cricketJerseys.map((jersey) => jersey.primary.toARGB32()).toSet(),
        hasLength(6),
      );
      expect(
        cricketJerseys.map((jersey) => jersey.accent.toARGB32()).toSet(),
        hasLength(6),
      );
    });

    test('all legacy IPL enum names migrate deterministically', () {
      expect(superOverJerseyFromStoredId('mumbai'), CricketJersey.nightCyan);
      expect(superOverJerseyFromStoredId('chennai'), CricketJersey.goldStrike);
      expect(superOverJerseyFromStoredId('bangalore'), CricketJersey.emberRed);
      expect(superOverJerseyFromStoredId('kolkata'), CricketJersey.violetPulse);
      expect(superOverJerseyFromStoredId('delhi'), CricketJersey.nightCyan);
      expect(
        superOverJerseyFromStoredId('rajasthan'),
        CricketJersey.violetPulse,
      );
      expect(superOverJerseyFromStoredId('punjab'), CricketJersey.emberRed);
      expect(
        superOverJerseyFromStoredId('hyderabad'),
        CricketJersey.tealVector,
      );
      expect(superOverJerseyFromStoredId('lucknow'), CricketJersey.monoIce);
      expect(superOverJerseyFromStoredId('gujarat'), CricketJersey.tealVector);
      expect(
        superOverJerseyFromStoredId('Violet Pulse'),
        CricketJersey.violetPulse,
      );
      expect(
        superOverJerseyFromStoredId('retired-value'),
        CricketJersey.nightCyan,
      );
    });

    test('presentation contains no official team names or badge codes', () {
      final text = cricketJerseys
          .expand((jersey) => [jersey.name, jersey.shortName])
          .join(' ')
          .toUpperCase();
      for (final banned in [
        'MUMBAI INDIANS',
        'CHENNAI KINGS',
        'ROYAL BANGALORE',
        'KOLKATA RIDERS',
        'DELHI CAPITALS',
        'RAJASTHAN ROYALS',
        'PUNJAB KINGS',
        'SUNRISERS',
        'LUCKNOW GIANTS',
        'GUJARAT TITANS',
      ]) {
        expect(text, isNot(contains(banned)));
      }
      expect(
        cricketJerseys.map((jersey) => jersey.shortName),
        isNot(containsAll(['MI', 'CSK', 'RCB', 'KKR', 'DC'])),
      );
    });
  });
}
