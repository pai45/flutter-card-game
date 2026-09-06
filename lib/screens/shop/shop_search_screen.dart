part of 'shop_screen.dart';

/// A separate route preserves the Shop's sport/category and scroll state.
class ShopSearchScreen extends StatefulWidget {
  const ShopSearchScreen({super.key});
  @override
  State<ShopSearchScreen> createState() => _ShopSearchScreenState();
}

class _ShopSearchScreenState extends State<ShopSearchScreen> {
  Widget? _overlay;
  int? _celebrationCoins;
  String? _shaking;
  String? _flashing;
  void _acquired({
    required Widget preview,
    required String name,
    required Color accent,
    required int coinsSpent,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(
      () => _overlay = ShopAcquireOverlay(
        preview: preview,
        name: name,
        accent: accent,
        coinsSpent: coinsSpent,
        onDismissed: () {
          if (mounted) setState(() => _overlay = null);
        },
      ),
    );
  }

  void _celebrate(int amount) {
    setState(() => _celebrationCoins = amount);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _celebrationCoins = null);
    });
  }

  void _cardFeedback(String id, {bool insufficient = false}) {
    setState(() {
      if (insufficient) {
        _shaking = id;
      } else {
        _flashing = id;
      }
    });
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() {
          if (_shaking == id) _shaking = null;
          if (_flashing == id) _flashing = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CatalogueSearchScaffold(
        title: 'SHOP SEARCH',
        hint: 'Player, team, country or item',
        introduction:
            'Find your next upgrade across every sport. Search a player, team, country, or item.',
        resultsBuilder: (context, query) => BlocBuilder<GameBloc, GameState>(
          builder: (context, state) => _results(query, state),
        ),
      ),
      if (_celebrationCoins != null)
        Positioned.fill(child: _CelebrationOverlay(amount: _celebrationCoins!)),
      if (_overlay != null) Positioned.fill(child: _overlay!),
    ],
  );

  Widget _results(String query, GameState state) {
    final results = searchShopCatalogue(query);
    final groups = <String, List<ShopSearchItem>>{};
    for (final item in results) {
      groups
          .putIfAbsent('${item.categoryLabel} // ${item.sportLabel}', () => [])
          .add(item);
    }
    return CustomScrollView(
      key: ValueKey(query),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverToBoxAdapter(
            child: results.isEmpty
                ? const CyberNoDataState(
                    icon: Icons.search_off_rounded,
                    title: 'NO ITEMS FOUND',
                    message:
                        'Try a player surname, team code, country or item name.',
                  )
                : Text(
                    '${results.length} ITEMS FOUND',
                    style: Cyber.label(10, color: Cyber.cyan),
                  ),
          ),
        ),
        for (final group in groups.entries) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(group.key, style: Cyber.label(10)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final category = group.value.first.category;
                final wideTile = category == 2 || category == 3;
                final width = constraints.crossAxisExtent;
                final columns = wideTile
                    ? (width >= 900 ? 2 : 1)
                    : (width >= 720
                          ? 4
                          : width >= 480
                          ? 3
                          : 2);
                final tileWidth = (width - (columns - 1) * 12) / columns;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: wideTile
                        ? 148
                        : tileWidth /
                              (category == 6 || category == 5 ? 0.68 : 0.60),
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = group.value[index];
                    return StaggeredCardEntrance(
                      key: ValueKey(item.id),
                      index: index.clamp(0, 5),
                      animate: true,
                      child: _tile(item, state),
                    );
                  }, childCount: group.value.length),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(ShopSearchItem item, GameState state) {
    final i = item.index;
    switch (item.category) {
      case 0:
        final avatar = _playerAvatarItems[i];
        return _AvatarShopTile(
          item: avatar,
          owned: state.ownedAvatarIds.contains(avatar.shortName),
          onAcquired: _acquired,
        );
      case 1:
        final frame = avatarFrameOptions[i];
        return _FrameShopTile(
          frame: frame,
          owned: state.ownedAvatarFrameIds.contains(frame.id),
          equipped: state.equippedAvatarFrameId == frame.id,
          onAcquired: _acquired,
        );
      case 2:
        final banner = _bannerPlaceholders[i];
        return _BannerShopTile(
          item: banner,
          owned: state.ownedBannerIds.contains(banner.id),
          onAcquired: _acquired,
        );
      case 3:
        if (item.sport == Sport.cricket) {
          final kit = finalOverKits[i];
          return _FinalOverKitShopTile(
            kit: kit,
            index: i,
            owned: isFinalOverKitOwned(kit.id, state.ownedFinalOverKitIds),
            price: finalOverKitPrice(kit),
            onAcquired: _acquired,
          );
        }
        if (item.sport == Sport.basketball) {
          final team = basketballTeams[i];
          return _BasketballTeamShopTile(
            team: team,
            index: i,
            owned: isBasketballTeamOwned(team.id, state.ownedBasketballTeamIds),
            price: basketballTeamPrice(team),
            onAcquired: _acquired,
          );
        }
        final spec = grandPrixLiveries[i];
        return _GrandPrixLiveryShopTile(
          spec: spec,
          index: i,
          owned: isGrandPrixLiveryOwned(
            spec.livery.name,
            state.ownedGrandPrixLiveryIds,
          ),
          price: grandPrixLiveryPrice(spec.livery),
          onAcquired: _acquired,
        );
      case 4:
        return _CoinTierTile(tier: coinTiers[i], onPurchased: _celebrate);
      case 5:
        return _PackTile(
          pack: item.sport == Sport.motorsport
              ? racingShopPacks[i]
              : shopPacks[i],
        );
      default:
        final card = allPlayerCards[i];
        return _PurchasableCardTile(
          card: card,
          owned: state.ownedCardIds.contains(card.id),
          shake: _shaking == card.id,
          flash: _flashing == card.id,
          onInsufficient: () => _cardFeedback(card.id, insufficient: true),
          onPurchased: () => _cardFeedback(card.id),
          onAcquired: _acquired,
        );
    }
  }
}
