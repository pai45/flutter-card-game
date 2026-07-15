import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/screens/deck/all_cards_screen.dart';
import 'package:card_game/services/card_share_service.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('player share copy includes card identity and role context', () {
    final card = attackers.first;

    final copy = playerCardShareText(card);

    expect(copy, contains(card.name));
    expect(copy, contains('${card.rating} OVR'));
    expect(copy, contains(card.trait));
    expect(copy, contains('ATK'));
  });

  test('action share copy includes power, effect, and risky status', () {
    final card = actionCards.firstWhere((card) => card.risky);

    final copy = actionCardShareText(card);

    expect(copy, contains(card.title));
    expect(copy, contains('${card.power > 0 ? '+' : ''}${card.power} PWR'));
    expect(copy, contains(card.effect));
    expect(copy, contains('High risk, high reward'));
  });

  testWidgets('player card detail exposes share button and uses exporter', (
    tester,
  ) async {
    final share = _FakeShareController();
    final card = attackers.first;
    final bloc = _TestGameBloc(_stateFor(player: card));
    addTearDown(bloc.close);

    await tester.pumpWidget(_AllCardsHarness(bloc: bloc, share: share));

    await tester.tap(find.byType(CyberPlayerCardTile).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.ios_share), findsOneWidget);

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();

    expect(share.playerShares, 1);
    expect(share.lastPlayer, card);
    expect(find.text(card.name.toUpperCase()), findsOneWidget);
  });

  testWidgets('action card detail exposes share button and uses exporter', (
    tester,
  ) async {
    final share = _FakeShareController();
    final card = actionCards.first;
    final bloc = _TestGameBloc(_stateFor(action: card));
    addTearDown(bloc.close);

    await tester.pumpWidget(_AllCardsHarness(bloc: bloc, share: share));

    await tester.tap(find.text('ACTIONS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CyberActionCardTile).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.ios_share), findsOneWidget);

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();

    expect(share.actionShares, 1);
    expect(share.lastAction, card);
    expect(find.text(card.title.toUpperCase()), findsAtLeastNWidgets(1));
  });

  testWidgets('cricket cards appear in their own collection tab', (
    tester,
  ) async {
    final share = _FakeShareController();
    final cricketCard = cricketPlayerCards.firstWhere(
      (card) => card.role == PlayerRole.batsman,
    );
    final bloc = _TestGameBloc(_stateFor(player: cricketCard));
    addTearDown(bloc.close);

    await tester.pumpWidget(_AllCardsHarness(bloc: bloc, share: share));
    await tester.tap(find.text('CRICKET'));
    await tester.pumpAndSettle();

    expect(find.byType(CyberPlayerCardTile), findsOneWidget);

    await tester.tap(find.byType(CyberPlayerCardTile).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(cricketCard.name.toUpperCase()), findsOneWidget);
  });
}

GameState _stateFor({PlayerCard? player, ActionCard? action}) {
  return GameState.initial().copyWith(
    loading: false,
    ownedCardIds: [if (player != null) player.id],
    ownedActionCardIds: [if (action != null) action.id],
  );
}

class _AllCardsHarness extends StatelessWidget {
  const _AllCardsHarness({required this.bloc, required this.share});

  final GameBloc bloc;
  final CardShareController share;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocProvider<GameBloc>.value(
        value: bloc,
        child: AllCardsScreen(onNavigate: (_) {}, shareController: share),
      ),
    );
  }
}

class _TestGameBloc extends GameBloc {
  _TestGameBloc(GameState seed) : super(SecureGameStorage()) {
    emit(seed);
  }
}

class _FakeShareController extends CardShareController {
  PlayerCard? lastPlayer;
  ActionCard? lastAction;
  int playerShares = 0;
  int actionShares = 0;

  @override
  Future<void> sharePlayer(
    BuildContext context,
    PlayerCard card, {
    Rect? sharePositionOrigin,
  }) async {
    playerShares++;
    lastPlayer = card;
  }

  @override
  Future<void> shareAction(
    BuildContext context,
    ActionCard card, {
    Rect? sharePositionOrigin,
  }) async {
    actionShares++;
    lastAction = card;
  }
}
