import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../data/rival_roster.dart';
import '../../widgets/catalogue_search_scaffold.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/staggered_card_entrance.dart';
import '../friends/widgets/rival_search_result_card.dart';
import 'leaderboard_screen.dart' show showRivalDossier;

class UserSearchScreen extends StatelessWidget {
  const UserSearchScreen({this.onChallenge, super.key});
  final void Function(String opponentName, int opponentLevel)? onChallenge;
  @override
  Widget build(BuildContext context) => CatalogueSearchScaffold(
    title: 'USER SEARCH',
    hint: 'Search username',
    introduction:
        'Find your next rival. Search all available players by username.',
    resultsBuilder: (context, query) {
      final results = searchRivals(query);
      return ListView.separated(
        key: ValueKey(query),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: results.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return results.isEmpty
                ? const CyberNoDataState(
                    icon: Icons.person_search_rounded,
                    title: 'NO PLAYERS FOUND',
                    message:
                        'Try another username or a shorter part of the name.',
                  )
                : Text(
                    '${results.length} PLAYERS FOUND',
                    style: Cyber.label(10, color: Cyber.cyan),
                  );
          }
          final seed = results[index - 1];
          return StaggeredCardEntrance(
            index: (index - 1).clamp(0, 5),
            animate: true,
            child: RivalSearchResultCard(
              key: ValueKey(seed.name),
              seed: seed,
              onView: () {
                FocusManager.instance.primaryFocus?.unfocus();
                HapticFeedback.selectionClick();
                showRivalDossier(context, seed.name, onChallenge: onChallenge);
              },
            ),
          );
        },
      );
    },
  );
}
