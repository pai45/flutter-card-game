import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:final_over/presentation/gameplay_screen.dart';
import 'package:final_over/presentation/home_screen.dart';
import 'package:final_over/presentation/result_screen.dart';
import 'package:final_over/presentation/splash_screen.dart';
import 'package:final_over/services/services.dart';
import 'theme.dart';

class FinalOverApp extends StatefulWidget {
  const FinalOverApp({super.key, required this.settingsService});

  final LocalSettingsService settingsService;

  @override
  State<FinalOverApp> createState() => _FinalOverAppState();
}

class _FinalOverAppState extends State<FinalOverApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ValueNotifier<FinalOverSettings> _settings;
  late final AudioService _audio;
  late final HapticsService _haptics;

  @override
  void initState() {
    super.initState();
    final loaded = widget.settingsService.load();
    _settings = ValueNotifier(loaded);
    _audio = AudioService(enabled: loaded.soundEnabled);
    _haptics = HapticsService(enabled: loaded.vibrationEnabled);
    unawaited(_audio.preload());
  }

  @override
  void dispose() {
    _audio.dispose();
    _settings.dispose();
    super.dispose();
  }

  Future<void> _setSound(bool value) async {
    _settings.value = _settings.value.copyWith(soundEnabled: value);
    await widget.settingsService.setSoundEnabled(value);
    await _audio.setEnabled(value);
  }

  Future<void> _setVibration(bool value) async {
    _settings.value = _settings.value.copyWith(vibrationEnabled: value);
    await widget.settingsService.setVibrationEnabled(value);
    _haptics.setEnabled(value);
  }

  Widget _home() {
    return ValueListenableBuilder(
      valueListenable: _settings,
      builder: (context, settings, _) {
        return HomeScreen(
          settings: settings,
          onPlay: () => _openGameplay(context),
          onSoundChanged: _setSound,
          onVibrationChanged: _setVibration,
        );
      },
    );
  }

  void _openGameplay(BuildContext context) {
    final seed = Random.secure().nextInt(0x7fffffff);
    Navigator.of(context).push(_gameplayRoute(seed));
  }

  MaterialPageRoute<void> _gameplayRoute(int seed) {
    return MaterialPageRoute<void>(
      builder: (routeContext) => ValueListenableBuilder(
        valueListenable: _settings,
        builder: (context, settings, _) => GameplayScreen(
          seed: seed,
          settings: settings,
          audio: _audio,
          haptics: _haptics,
          onSoundChanged: _setSound,
          onVibrationChanged: _setVibration,
          onResult: (summary) => _showResult(routeContext, summary),
        ),
      ),
    );
  }

  Future<void> _showResult(
    BuildContext context,
    GameResultSummary summary,
  ) async {
    await widget.settingsService.updateBest(
      score: summary.points,
      stars: summary.stars,
    );
    _settings.value = widget.settingsService.load();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (resultContext) => ResultScreen(
          summary: summary,
          onPlayAgain: () {
            Navigator.of(resultContext).pushReplacement(
              _gameplayRoute(Random.secure().nextInt(0x7fffffff)),
            );
          },
          onHome: () =>
              Navigator.of(resultContext).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Final Over',
      debugShowCheckedModeBanner: false,
      theme: buildFinalOverTheme(),
      home: SplashScreen(
        onComplete: () {
          _navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute<void>(builder: (_) => _home()),
          );
        },
      ),
    );
  }
}
