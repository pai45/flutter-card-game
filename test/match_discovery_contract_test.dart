import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/design_system/match_discovery.generated.dart';

void main() {
  test(
    'local generated contract has no stale layout, type or cycle values',
    () {
      final spec =
          jsonDecode(File('design/match-discovery.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(spec['sports'], MatchDiscoveryTokens.sportOrder);
      expect(spec['status'], MatchDiscoveryTokens.statusLabels);
      expect(spec['cycle'], MatchDiscoveryTokens.cycleCounts);
      expect(spec['layout']['page'], MatchDiscoveryTokens.page);
      expect(spec['layout']['card'], MatchDiscoveryTokens.card);
      expect(spec['layout']['gridGap'], MatchDiscoveryTokens.gridGap);
      expect(spec['layout']['moduleGap'], MatchDiscoveryTokens.moduleGap);
      expect(
        spec['layout']['collapseTextScale'],
        MatchDiscoveryTokens.collapseTextScale,
      );
      expect(spec['type']['question'], MatchDiscoveryTokens.question);
      expect(
        spec['type']['questionWeight'],
        MatchDiscoveryTokens.questionWeight,
      );
      expect(spec['type']['score'], MatchDiscoveryTokens.score);
    },
  );
}
