import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/shootout/shootout_bloc.dart';
import '../../../blocs/shootout/shootout_event.dart';
import '../../../blocs/shootout/shootout_state.dart';
import '../../../models/progression.dart';
import '../../../models/avatar_frame_option.dart';
import '../../../models/avatar_option.dart';
import '../../../services/secure_storage_service.dart';
import '../../../widgets/matchmaking/game_matchmaking_config.dart';
import '../../../widgets/matchmaking/game_matchmaking_view.dart';
import 'shootout_arena_background.dart';

/// Cinematic matchmaking beat that reveals the player's identity first, scans
/// the global queue, then mirrors the locked rival across a live VS medallion.
class ShootoutOpponentRevealPhase extends StatefulWidget {
  const ShootoutOpponentRevealPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final ShootoutState state;
  final VoidCallback onQuit;

  @override
  State<ShootoutOpponentRevealPhase> createState() =>
      _ShootoutOpponentRevealPhaseState();
}

class _ShootoutOpponentRevealPhaseState
    extends State<ShootoutOpponentRevealPhase> {
  final SecureGameStorage _storage = SecureGameStorage();
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatarId = await _storage.loadSelectedAvatarId();
    if (!mounted) return;
    setState(() => _selectedAvatarId = avatarId);
  }

  void _onMatched() {
    if (!mounted) return;
    context.read<ShootoutBloc>().add(ShootoutOpponentRevealCompleted());
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameBloc>().state;
    final playerAvatar = avatarOptionById(_selectedAvatarId);
    final opponentAvatar = avatarForName(widget.state.opponentName);
    final equippedFrame = avatarFrameOptionById(game.equippedAvatarFrameId);

    final config = GameMatchmakingConfig(
      title: 'PENALTY SHOOTOUT',
      queueLabel: 'SCANNING GLOBAL PENALTY QUEUE',
      backgroundAsset: ShootoutArenaBackground.assetPath,
      player: MatchmakingFighter(
        name: 'PLAYER ONE',
        avatarAsset: playerAvatar.assetPath,
        frame: equippedFrame,
        badge: 'LV ${game.progression.levelFor(ProgressTrack.shootout)}',
      ),
      opponent: MatchmakingFighter(
        name: widget.state.opponentName,
        avatarAsset: opponentAvatar.assetPath,
        badge: 'LV ${widget.state.cpuLevel}',
      ),
    );

    return GameMatchmakingView(
      config: config,
      onMatched: _onMatched,
      onCancel: widget.onQuit,
    );
  }
}
