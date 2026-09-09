import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_cta_button.dart';

/// Local account-entry preview. Never stores or authenticates the entered email.
class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({required this.onContinue, super.key});

  final VoidCallback onContinue;

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final _email = TextEditingController();
  bool _edited = false;
  bool _continuing = false;

  bool get _valid =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim());

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(HapticFeedback.lightImpact());
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted) widget.onContinue();
  }

  void _policy(String title) {
    showCyberConfirmDialog(
      context,
      title: title,
      message:
          '$title is unavailable in this prototype. '
          'No account is created and your email is not saved.',
      confirmLabel: 'GOT IT',
      cancelLabel: 'CLOSE',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the hero stable while the keyboard opens; the page itself scrolls.
    final media = MediaQuery.of(context);
    final heroHeight = (media.size.height * .48).clamp(260.0, 460.0);
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: heroHeight,
                    child: const OnboardingVideoHero(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("LET'S GET STARTED", style: Cyber.display(24)),
                        const SizedBox(height: 24),
                        Text(
                          'Enter Your Email',
                          style: Cyber.body(16, color: Cyber.muted),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('onboarding-email'),
                          controller: _email,
                          enabled: !_continuing,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: Cyber.body(16),
                          onChanged: (_) => setState(() => _edited = true),
                          onSubmitted: (_) {
                            setState(() => _edited = true);
                            if (_valid) _continue();
                          },
                          decoration: InputDecoration(
                            hintText: 'champion@arena.com',
                            hintStyle: Cyber.body(16, color: Cyber.muted),
                            filled: true,
                            fillColor: Cyber.bg2,
                            contentPadding: const EdgeInsets.all(20),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Cyber.border),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Cyber.cyan),
                            ),
                            errorText: _edited && !_valid
                                ? 'Enter a valid email to continue.'
                                : null,
                            errorStyle: Cyber.body(12, color: Cyber.danger),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Cyber.line)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text('OR', style: Cyber.display(20)),
                            ),
                            const Expanded(child: Divider(color: Cyber.line)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        HudCtaButton(
                          key: const ValueKey('onboarding-google'),
                          label: 'SIGN IN WITH GOOGLE',
                          outlined: true,
                          labelStyle: Cyber.label(20),
                          icon: Icons.login,
                          glow: false,
                          enabled: !_continuing,
                          onTap: _continue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'By continuing, you agree to our',
                          style: Cyber.body(14, color: Cyber.muted),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PolicyLink(
                              label: 'Terms of Service',
                              onTap: () => _policy('Terms of Service'),
                            ),
                            Text(
                              ' & ',
                              style: Cyber.body(14, color: Cyber.muted),
                            ),
                            _PolicyLink(
                              label: 'Privacy Policy',
                              onTap: () => _policy('Privacy Policy'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        HudCtaButton(
                          key: const ValueKey('onboarding-continue'),
                          label: _continuing
                              ? 'ENTERING SETUP'
                              : 'LOGIN / SIGNUP',
                          labelStyle: Cyber.label(20),
                          icon: Icons.arrow_forward,
                          enabled: _valid && !_continuing,
                          glow: _valid && !_continuing,
                          onTap: _continue,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Preview — no account will be created',
                          textAlign: TextAlign.center,
                          style: Cyber.body(11, color: Cyber.muted),
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
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: Cyber.body(
            14,
            color: Cyber.cyan,
          ).copyWith(decoration: TextDecoration.underline),
        ),
      ),
    ),
  );
}

/// Bundled cinematic with a permanent poster underneath every playback state.
class OnboardingVideoHero extends StatefulWidget {
  const OnboardingVideoHero({super.key});

  @override
  State<OnboardingVideoHero> createState() => _OnboardingVideoHeroState();
}

class _OnboardingVideoHeroState extends State<OnboardingVideoHero>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _reduceMotion = false;
  bool _foreground = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_reduceMotion && _controller == null && !_failed) {
      unawaited(_initialize());
    } else {
      unawaited(_syncPlayback());
    }
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(
      'assets/backgrounds/onboarding_login.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      if (!mounted) return;
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {});
      await _syncPlayback();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _failed) {
      return;
    }
    try {
      if (_foreground && !_reduceMotion) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncPlayback());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/backgrounds/onboarding_login_poster.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Cyber.bg2,
            child: Icon(Icons.sports_soccer, color: Cyber.cyan, size: 64),
          ),
        ),
        if (_controller != null && !_failed && !_reduceMotion)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller!,
            builder: (_, value, _) => value.isInitialized && !value.hasError
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: value.size.width,
                        height: value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Cyber.bg.withValues(alpha: 0), Cyber.bg],
              stops: const [.66, 1],
            ),
          ),
        ),
      ],
    ),
  );
}
