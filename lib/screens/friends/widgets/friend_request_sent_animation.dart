import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Shows the short outbound-signal payoff used after a rival is added.
Future<void> showFriendRequestSentAnimation(
  BuildContext context, {
  required String friendName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Friend request sent',
    barrierColor: Cyber.bg.withValues(alpha: 0.82),
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, _) => FriendRequestSentAnimation(
      friendName: friendName,
      onComplete: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

/// A compact transmission animation: the send glyph crosses the link, then a
/// single confirmation tick resolves on the destination node.
class FriendRequestSentAnimation extends StatefulWidget {
  const FriendRequestSentAnimation({
    required this.friendName,
    required this.onComplete,
    this.enableFeedback = true,
    super.key,
  });

  final String friendName;
  final VoidCallback onComplete;
  final bool enableFeedback;

  @override
  State<FriendRequestSentAnimation> createState() =>
      _FriendRequestSentAnimationState();
}

class _FriendRequestSentAnimationState extends State<FriendRequestSentAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableFeedback) playSound(SoundEffect.whoosh);
    _controller
      ..addListener(_handleProgress)
      ..addStatusListener(_handleStatus)
      ..forward();
  }

  void _handleProgress() {
    if (_confirmed || _controller.value < 0.3) return;
    _confirmed = true;
    if (!widget.enableFeedback) return;
    playSound(SoundEffect.uiConfirm);
    HapticFeedback.mediumImpact();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onComplete();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleProgress)
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const IgnorePointer(child: CyberTextureOverlay()),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    final entry = Curves.easeOutBack.transform(
                      (t / 0.2).clamp(0.0, 1.0),
                    );
                    final travel = Curves.easeInOutCubic.transform(
                      ((t - 0.08) / 0.24).clamp(0.0, 1.0),
                    );
                    final confirm = Curves.elasticOut.transform(
                      ((t - 0.27) / 0.22).clamp(0.0, 1.0),
                    );
                    final copyIn = Curves.easeOut.transform(
                      ((t - 0.3) / 0.15).clamp(0.0, 1.0),
                    );
                    final exit = t < 0.84
                        ? 1.0
                        : (1 - (t - 0.84) / 0.16).clamp(0.0, 1.0);

                    return Opacity(
                      opacity: exit,
                      child: Transform.scale(
                        scale: 0.88 + entry * 0.12,
                        child: Semantics(
                          liveRegion: true,
                          label: 'Friend request sent to ${widget.friendName}',
                          child: ExcludeSemantics(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: CyberPanel(
                                accent: Cyber.cyan,
                                glow: true,
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '// OUTBOUND SOCIAL LINK',
                                        style: Cyber.label(
                                          9,
                                          color: Cyber.muted,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _TransmissionTrack(
                                      travel: travel,
                                      confirm: confirm,
                                    ),
                                    const SizedBox(height: 20),
                                    Opacity(
                                      opacity: copyIn,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'REQUEST SENT',
                                            style: Cyber.display(
                                              20,
                                              color: Cyber.cyan,
                                              letterSpacing: 2.2,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            widget.friendName.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Cyber.label(
                                              11,
                                              color: Cyber.muted,
                                              letterSpacing: 1.6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransmissionTrack extends StatelessWidget {
  const _TransmissionTrack({required this.travel, required this.confirm});

  final double travel;
  final double confirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 72,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const nodeSize = 52.0;
          final distance = constraints.maxWidth - nodeSize;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: nodeSize / 2,
                right: nodeSize / 2,
                child: Container(
                  height: 2,
                  color: Cyber.line.withValues(alpha: 0.7),
                ),
              ),
              Positioned(
                left: nodeSize / 2,
                child: Container(
                  width: distance * travel,
                  height: 2,
                  color: Cyber.cyan,
                ),
              ),
              const _SignalNode(icon: Icons.person_outline),
              Positioned(
                left: distance * travel,
                child: Opacity(
                  opacity: 1 - confirm.clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.send_rounded,
                    size: 22,
                    color: Cyber.cyan,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Transform.scale(
                  scale: confirm,
                  child: const _SignalNode(
                    icon: Icons.check_rounded,
                    confirmed: true,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignalNode extends StatelessWidget {
  const _SignalNode({required this.icon, this.confirmed = false});

  final IconData icon;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: confirmed ? Cyber.cyan.withValues(alpha: 0.14) : Cyber.panel2,
        border: Border.all(
          color: confirmed ? Cyber.cyan : Cyber.line,
          width: confirmed ? 2 : 1,
        ),
        boxShadow: confirmed
            ? Cyber.glow(Cyber.cyan, alpha: 0.26, blur: 16)
            : null,
      ),
      child: Icon(icon, size: 26, color: confirmed ? Cyber.cyan : Cyber.muted),
    );
  }
}
