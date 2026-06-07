import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../models/avatar_option.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({required this.onComplete, super.key});

  final ValueChanged<String> onComplete;

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  String _selectedAvatarId = avatarOptions.first.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: Column(
              children: [
                _AvatarHeader(
                  onSkip: () => widget.onComplete(avatarOptions.first.id),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 104),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'CHOOSE YOUR AVATAR',
                              style: Cyber.display(26, letterSpacing: 1.1),
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: GridView.builder(
                                itemCount: avatarOptions.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 1,
                                    ),
                                itemBuilder: (context, index) {
                                  final avatar = avatarOptions[index];
                                  return _AvatarTile(
                                    avatar: avatar,
                                    selected: avatar.id == _selectedAvatarId,
                                    onTap: () => setState(
                                      () => _selectedAvatarId = avatar.id,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: HudCtaButton(
                    label: 'FINALISE',
                    icon: Icons.check,
                    onTap: () => widget.onComplete(_selectedAvatarId),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff0b1120), Color(0xff070b14)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xff1e2538))),
      ),
      child: Row(
        children: [
          const _StatozLogo(),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Cyber.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'SKIP',
              style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatozLogo extends StatelessWidget {
  const _StatozLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.cyan.withValues(alpha: 0.14),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.65)),
          ),
          child: Text(
            'S',
            style: Cyber.display(16, color: Cyber.cyan, letterSpacing: 0),
          ),
        ),
        const SizedBox(width: 8),
        Text('STATOZ', style: Cyber.display(16, letterSpacing: 1.4)),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Cyber.lime : Cyber.line;
    return Semantics(
      button: true,
      selected: selected,
      label: avatar.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.18, blur: 14, spread: -2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                avatar.assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              if (selected) const _SelectedCorner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCorner extends StatelessWidget {
  const _SelectedCorner();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Cyber.lime),
        child: const Icon(Icons.check, color: Cyber.bg, size: 22),
      ),
    );
  }
}
