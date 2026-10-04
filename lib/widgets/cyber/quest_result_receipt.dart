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
              cornerCuts: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Cyber.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'MISSION CLEARED',
                              style: Cyber.display(13, color: Cyber.success),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '+$beginnerQuestStepXp XP',
                        style: Cyber.display(13, color: Cyber.gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'QUEST PROGRESS',
                          style: Cyber.label(9, color: Cyber.muted),
                        ),
                      ),
                      Text(
                        '${receipt.completed}/${receipt.total}',
                        style: Cyber.display(12, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  CyberProgressBar(
                    value: receipt.completed / receipt.total,
                    accent: Cyber.success,
                    height: 5,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        receipt.questCompleted
                            ? Icons.toll_rounded
                            : receipt.graduated
                            ? Icons.lock_open_rounded
                            : Icons.arrow_forward_rounded,
                        color: receipt.questCompleted
                            ? Cyber.gold
                            : receipt.graduated
                            ? Cyber.success
                            : Cyber.cyan,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          receipt.questCompleted
                              ? '+$beginnerQuestCompleteOz OZ EARNED · SPORT CLEARED'
                              : receipt.graduated
                              ? 'DAILY QUESTS UNLOCKED'
                              : 'NEXT: CHOOSE A GAME',
                          style: Cyber.label(
                            10,
                            color: receipt.questCompleted
                                ? Cyber.gold
                                : receipt.graduated
                                ? Cyber.success
                                : Cyber.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
