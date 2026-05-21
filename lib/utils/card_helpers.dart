import '../models/cards.dart';

List<PlayerCard> cardsByIds(List<PlayerCard> source, List<String> ids) => ids
    .map((id) => source.where((card) => card.id == id).firstOrNull)
    .whereType<PlayerCard>()
    .toList();

List<ActionCard> actionCardsByIds(List<String> ids) => ids
    .map((id) => actionCards.where((card) => card.id == id).firstOrNull)
    .whereType<ActionCard>()
    .toList();
