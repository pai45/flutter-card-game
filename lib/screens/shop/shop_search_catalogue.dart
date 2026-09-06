part of 'shop_screen.dart';

/// Search metadata only; purchases use the original Shop tiles.
class ShopSearchItem {
  const ShopSearchItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sport,
    required this.index,
    required this.terms,
  });
  final String id;
  final String name;
  final int category;
  final Sport? sport;
  final int index;
  final List<String> terms;
  String get categoryLabel => const [
    'AVATAR',
    'FRAME',
    'BANNER',
    'KITS',
    'COINS',
    'PACKS',
    'CARDS',
  ][category];
  String get sportLabel =>
      sport == null ? 'ALL SPORTS' : _shopSportCode(sport!);
}

List<String> _cardSearchTerms(PlayerCard card) => [
  card.name,
  card.shortName,
  card.country,
  card.countryCode,
  card.position,
  card.role.name,
  card.trait,
  card.tier.name,
  if (_cardSport(card) == Sport.tennis)
    TennisCountryMap.countryNameFor(card.countryCode) ?? '',
  if (_cardSport(card) == Sport.motorsport) f1TeamCode(card.position),
];

final List<ShopSearchItem> shopSearchCatalogue = List.unmodifiable(
  _buildShopSearchCatalogue(),
);
List<ShopSearchItem> _buildShopSearchCatalogue() {
  final result = <ShopSearchItem>[];
  void add(
    int category,
    Sport? sport,
    int index,
    String id,
    String name,
    List<String> terms,
  ) {
    result.add(
      ShopSearchItem(
        id: '$category:$id',
        name: name,
        category: category,
        sport: sport,
        index: index,
        terms: [
          name,
          ...terms,
          const [
            'avatar portrait',
            'frame',
            'banner',
            'kit jersey livery',
            'coins',
            'pack',
            'card',
          ][category],
          if (sport != null) ...[_shopSportCode(sport), sport.name],
        ],
      ),
    );
  }

  final portraits = allPlayerCards.where(_isShopAvatarCard).toList();
  for (var i = 0; i < portraits.length; i++) {
    final card = portraits[i];
    add(0, _cardSport(card), i, card.id, card.name, _cardSearchTerms(card));
  }
  for (var i = 0; i < avatarFrameOptions.length; i++) {
    final frame = avatarFrameOptions[i];
    final sports = _shopSports.where(
      (sport) => frame.sports.contains(_shopSportCode(sport)),
    );
    if (sports.isEmpty) continue;
    final teams = followableLeagues
        .where((league) => league.league.id == frame.leagueId)
        .expand((league) => league.teams)
        .where((team) => team.id == frame.teamId);
    add(1, sports.first, i, frame.id, frame.label, [
      frame.teamId,
      frame.leagueId,
      ...frame.sports,
      for (final team in teams) ...[team.name, team.shortName],
    ]);
  }
  for (var i = 0; i < _bannerPlaceholders.length; i++) {
    final item = _bannerPlaceholders[i];
    add(
      2,
      _shopSports.firstWhere((sport) => _shopSportCode(sport) == item.sport),
      i,
      item.id,
      item.label,
      [item.id.replaceAll('_', ' ')],
    );
  }
  for (var i = 0; i < finalOverKits.length; i++) {
    final item = finalOverKits[i];
    add(3, Sport.cricket, i, 'cricket:${item.id}', item.name, [item.id]);
  }
  for (var i = 0; i < basketballTeams.length; i++) {
    final item = basketballTeams[i];
    add(3, Sport.basketball, i, 'basketball:${item.id}', item.name, [item.id]);
  }
  for (var i = 0; i < grandPrixLiveries.length; i++) {
    final item = grandPrixLiveries[i];
    add(3, Sport.motorsport, i, 'racing:${item.livery.name}', item.name, [
      item.livery.name,
    ]);
  }
  for (var i = 0; i < coinTiers.length; i++) {
    final item = coinTiers[i];
    add(4, null, i, item.id, item.name, [
      'oz coins',
      '${item.coins}',
      item.tag ?? '',
    ]);
  }
  for (var i = 0; i < shopPacks.length; i++) {
    final item = shopPacks[i];
    add(5, null, i, item.id, item.name, [
      item.guarantee,
      'football cricket basketball tennis',
    ]);
  }
  for (var i = 0; i < racingShopPacks.length; i++) {
    final item = racingShopPacks[i];
    add(5, Sport.motorsport, i, item.id, item.name, [item.guarantee]);
  }
  for (var i = 0; i < allPlayerCards.length; i++) {
    final card = allPlayerCards[i];
    add(6, _cardSport(card), i, card.id, card.name, _cardSearchTerms(card));
  }
  return result;
}

List<ShopSearchItem> searchShopCatalogue(String query) {
  final results = shopSearchCatalogue
      .where((item) => catalogueMatches(query, item.terms))
      .toList();
  results.sort((a, b) {
    final category = a.category.compareTo(b.category);
    if (category != 0) return category;
    final sport = (a.sport == null ? -1 : _shopSports.indexOf(a.sport!))
        .compareTo(b.sport == null ? -1 : _shopSports.indexOf(b.sport!));
    if (sport != 0) return sport;
    final priority = catalogueMatchPriority(
      a.name,
      query,
    ).compareTo(catalogueMatchPriority(b.name, query));
    return priority != 0 ? priority : a.index.compareTo(b.index);
  });
  return results;
}
