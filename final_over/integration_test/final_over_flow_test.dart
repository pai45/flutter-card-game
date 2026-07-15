import 'package:final_over/app/theme.dart';
import 'package:final_over/presentation/gameplay_screen.dart';
import 'package:final_over/presentation/home_screen.dart';
import 'package:final_over/presentation/result_screen.dart';
import 'package:final_over/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home to live match and back is an offline deterministic flow', (
    tester,
  ) async {
    final audio = _FakeAudioBackend();
    final haptics = _FakeHapticDriver();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildFinalOverTheme(),
        home: _FlowHarness(
          audio: AudioService(backend: audio),
          haptics: HapticsService(driver: haptics),
        ),
      ),
    );

    expect(find.text('PLAY FINAL OVER'), findsOneWidget);
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pumpAndSettle();
    expect(find.text('GOT IT'), findsOneWidget);
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY FINAL OVER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('THE CHASE'), findsOneWidget);

    await tester.tap(find.text('CHASE NOW'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('QUIT TO HOME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PLAY FINAL OVER'), findsOneWidget);
    expect(audio.loopStarts, 1);
    expect(audio.effectPaths, isNotEmpty);
    expect(haptics.lightCount, greaterThan(0));
  });
}

class _FlowHarness extends StatefulWidget {
  const _FlowHarness({required this.audio, required this.haptics});

  final AudioService audio;
  final HapticsService haptics;

  @override
  State<_FlowHarness> createState() => _FlowHarnessState();
}

class _FlowHarnessState extends State<_FlowHarness> {
  FinalOverSettings _settings = const FinalOverSettings();

  void _openMatch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameplayScreen(
          seed: 2406,
          settings: _settings,
          audio: widget.audio,
          haptics: widget.haptics,
          onSoundChanged: (enabled) {
            setState(() {
              _settings = _settings.copyWith(soundEnabled: enabled);
            });
            widget.audio.setEnabled(enabled);
          },
          onVibrationChanged: (enabled) {
            setState(() {
              _settings = _settings.copyWith(vibrationEnabled: enabled);
            });
            widget.haptics.setEnabled(enabled);
          },
          onResult: _showResult,
        ),
      ),
    );
  }

  Future<void> _showResult(GameResultSummary summary) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (resultContext) => ResultScreen(
          summary: summary,
          onPlayAgain: () => Navigator.of(resultContext).pop(),
          onHome: () => Navigator.of(resultContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      settings: _settings,
      onPlay: _openMatch,
      onSoundChanged: (enabled) {
        setState(() {
          _settings = _settings.copyWith(soundEnabled: enabled);
        });
      },
      onVibrationChanged: (enabled) {
        setState(() {
          _settings = _settings.copyWith(vibrationEnabled: enabled);
        });
      },
    );
  }
}

final class _FakeAudioBackend implements AudioBackend {
  final List<String> effectPaths = <String>[];
  var loopStarts = 0;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playEffect(String assetPath) async {
    effectPaths.add(assetPath);
  }

  @override
  Future<void> startLoop(String assetPath) async {
    loopStarts++;
  }

  @override
  Future<void> stopAll() async {}
}

final class _FakeHapticDriver implements HapticDriver {
  var lightCount = 0;

  @override
  Future<void> heavy() async {}

  @override
  Future<void> light() async {
    lightCount++;
  }

  @override
  Future<void> medium() async {}
}
