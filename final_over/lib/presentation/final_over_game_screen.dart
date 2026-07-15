import 'dart:async';
import 'dart:math';

import 'package:final_over/app/theme.dart';
import 'package:final_over/presentation/gameplay_screen.dart';
import 'package:final_over/presentation/home_screen.dart';
import 'package:final_over/presentation/result_screen.dart';
import 'package:final_over/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Route-oriented Final Over entry point for a host Flutter application.
///
/// The standalone [MaterialApp] remains in `main.dart`; this screen owns only
/// the match/result loop and its private `final_over.*` settings. Package-mode
/// asset lookup is enabled without changing any host theme, storage, or audio.
class FinalOverGameScreen extends StatefulWidget {
  const FinalOverGameScreen({
    super.key,
    this.onExit,
    this.initialSeed,
    this.settingsService,
    this.audioBackend,
    this.hapticDriver,
  });

  final VoidCallback? onExit;
  final int? initialSeed;
  final LocalSettingsService? settingsService;
  final AudioBackend? audioBackend;
  final HapticDriver? hapticDriver;

  @override
  State<FinalOverGameScreen> createState() => _FinalOverGameScreenState();
}

class _FinalOverGameScreenState extends State<FinalOverGameScreen> {
  static const _assetPackage = 'final_over';

  LocalSettingsService? _settingsService;
  AudioService? _audio;
  HapticsService? _haptics;
  FinalOverSettings? _settings;
  GameResultSummary? _result;
  bool _matchActive = false;
  Object? _initializationError;
  late int _seed;

  @override
  void initState() {
    super.initState();
    _seed = widget.initialSeed ?? _newSeed();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(_initialize());
  }

  int _newSeed() => Random.secure().nextInt(0x7fffffff);

  Future<void> _initialize() async {
    try {
      final service =
          widget.settingsService ?? await LocalSettingsService.create();
      final settings = service.load();
      final audio = AudioService(
        backend: widget.audioBackend,
        assetPackage: _assetPackage,
        enabled: settings.soundEnabled,
      );
      final haptics = HapticsService(
        driver: widget.hapticDriver,
        enabled: settings.vibrationEnabled,
      );
      await audio.preload();
      if (!mounted) {
        await audio.dispose();
        return;
      }
      setState(() {
        _settingsService = service;
        _settings = settings;
        _audio = audio;
        _haptics = haptics;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _initializationError = error);
    }
  }

  Future<void> _setSound(bool value) async {
    final service = _settingsService;
    final audio = _audio;
    final settings = _settings;
    if (service == null || audio == null || settings == null) return;
    setState(() => _settings = settings.copyWith(soundEnabled: value));
    await service.setSoundEnabled(value);
    await audio.setEnabled(value);
  }

  Future<void> _setVibration(bool value) async {
    final service = _settingsService;
    final haptics = _haptics;
    final settings = _settings;
    if (service == null || haptics == null || settings == null) return;
    setState(() => _settings = settings.copyWith(vibrationEnabled: value));
    await service.setVibrationEnabled(value);
    haptics.setEnabled(value);
  }

  Future<void> _showResult(GameResultSummary summary) async {
    await _settingsService?.updateBest(
      score: summary.points,
      stars: summary.stars,
    );
    if (!mounted) return;
    setState(() {
      _settings = _settingsService?.load() ?? _settings;
      _result = summary;
    });
  }

  void _playAgain() {
    setState(() {
      _seed = _newSeed();
      _result = null;
      _matchActive = true;
    });
  }

  void _startMatch() {
    setState(() {
      _seed = widget.initialSeed ?? _newSeed();
      _result = null;
      _matchActive = true;
    });
  }

  void _returnHome() {
    setState(() {
      _result = null;
      _matchActive = false;
    });
  }

  void _exit() {
    final callback = widget.onExit;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    unawaited(_audio?.dispose());
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildFinalOverTheme(assetPackage: _assetPackage),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_initializationError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_cricket_rounded,
                  color: FinalOverPalette.cyan,
                  size: 52,
                ),
                const SizedBox(height: 14),
                const Text(
                  'FINAL OVER COULD NOT START',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _exit,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('BACK TO GAMES'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final settings = _settings;
    final audio = _audio;
    final haptics = _haptics;
    if (settings == null || audio == null || haptics == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: FinalOverPalette.cyan),
        ),
      );
    }

    final result = _result;
    if (result != null) {
      return ResultScreen(
        summary: result,
        assetPackage: _assetPackage,
        onPlayAgain: _playAgain,
        onHome: _returnHome,
      );
    }

    if (!_matchActive) {
      return HomeScreen(
        settings: settings,
        assetPackage: _assetPackage,
        onPlay: _startMatch,
        onSoundChanged: _setSound,
        onVibrationChanged: _setVibration,
      );
    }

    return GameplayScreen(
      key: ValueKey<int>(_seed),
      seed: _seed,
      settings: settings,
      audio: audio,
      haptics: haptics,
      assetPackage: _assetPackage,
      onSoundChanged: _setSound,
      onVibrationChanged: _setVibration,
      onResult: _showResult,
      onExit: _returnHome,
    );
  }
}
