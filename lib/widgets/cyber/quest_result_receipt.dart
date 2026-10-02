import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/game_ladder.dart';
import '../../config/theme.dart';
import '../unlock_celebration_host.dart';
import 'cyber_widgets.dart';

/// Result-local confirmation, matched to the exact settlement that earned it.
/// The cinematic remains queued until the player returns to the shell.
class QuestResultReceipt extends StatefulWidget {
  const QuestResultReceipt({
    required this.game,
    required this.sourceId,
    super.key,
  });
  final ArcadeGame game;
  final String? sourceId;

  @override
  State<QuestResultReceipt> createState() => _QuestResultReceiptState();
}

class _QuestResultReceiptState extends State<QuestResultReceipt> {
  bool _continuing = false;

  @override
  void didUpdateWidget(QuestResultReceipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game ||
        oldWidget.sourceId != widget.sourceId) {
      _continuing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GameBloc?>();
    if (bloc == null || widget.sourceId == null) return const SizedBox.shrink();
    final id = '${widget.game.name}:${widget.sourceId}';
    return BlocBuilder<GameBloc, GameState>(
      bloc: bloc,
      buildWhen: (before, after) =>
          before.questReceipts[id] != after.questReceipts[id],
      builder: (context, state) {
        final receipt = state.questReceipts[id];
        if (receipt == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: CyberPanel(
              accent: Cyber.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MISSION COMPLETE · +$beginnerQuestStepXp XP',
                    style: Cyber.display(12, color: Cyber.gold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${receipt.completed} of ${receipt.total} missions complete',
                    style: Cyber.bodyFor(context, 13),
                  ),
                  if (receipt.graduated) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Daily Quests unlocked',
                      style: Cyber.bodyFor(context, 13, color: Cyber.success),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    receipt.questCompleted
                        ? '+$beginnerQuestCompleteOz Oz · Sport quest complete'
                        : '${receipt.nextGame!.title} unlocked',
                    style: Cyber.bodyFor(context, 13),
                  ),
                  const SizedBox(height: 12),
                  CyberObjectiveAction(
                    label: 'CONTINUE QUEST',
                    icon: Icons.arrow_forward,
                    onTap:
                        _continuing ||
                            UnlockRevealGate.instance.continueQuest == null
                        ? null
                        : () {
                            setState(() => _continuing = true);
                            UnlockRevealGate.instance.continueQuest?.call();
                          },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
