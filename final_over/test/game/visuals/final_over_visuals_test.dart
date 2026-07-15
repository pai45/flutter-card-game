import 'package:final_over/game/visuals/final_over_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timing thresholds match the visual feedback contract', () {
    expect(timingVisualGradeForError(50), TimingVisualGrade.perfect);
    expect(timingVisualGradeForError(-50), TimingVisualGrade.perfect);
    expect(timingVisualGradeForError(51), TimingVisualGrade.good);
    expect(timingVisualGradeForError(115), TimingVisualGrade.good);
    expect(timingVisualGradeForError(190), TimingVisualGrade.earlyLate);
    expect(timingVisualGradeForError(275), TimingVisualGrade.poor);
    expect(timingVisualGradeForError(276), TimingVisualGrade.miss);
  });

  testWidgets('visual gallery renders to a golden-friendly image', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const boundaryKey = ValueKey<String>('visual-gallery');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: FinalOverPalette.navy,
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(width: 360, height: 800, child: _VisualGallery()),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    expect(image.width, 360);
    expect(image.height, 800);
    image.dispose();
  });

  testWidgets('all articulated character poses paint without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: FinalOverPalette.navy,
          body: SingleChildScrollView(
            child: Wrap(
              children: <Widget>[
                for (final pose in BatterPose.values)
                  SizedBox(
                    width: 90,
                    height: 130,
                    child: FinalOverBatterRig(pose: pose, progress: .64),
                  ),
                for (final pose in BowlerPose.values)
                  SizedBox(
                    width: 90,
                    height: 130,
                    child: FinalOverBowlerRig(pose: pose, progress: .64),
                  ),
                for (final signal in UmpireSignal.values)
                  SizedBox(
                    width: 90,
                    height: 130,
                    child: FinalOverUmpireRig(signal: signal, progress: .8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byType(FinalOverBatterRig),
      findsNWidgets(BatterPose.values.length),
    );
    expect(
      find.byType(FinalOverBowlerRig),
      findsNWidgets(BowlerPose.values.length),
    );
    expect(
      find.byType(FinalOverUmpireRig),
      findsNWidgets(UmpireSignal.values.length),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every effect and fielder state accepts edge progress values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              for (var i = 0; i < FielderVisualState.values.length; i++)
                Positioned(
                  left: i * 42,
                  top: 10,
                  width: 40,
                  height: 40,
                  child: FielderDot(
                    state: FielderVisualState.values[i],
                    progress: i.isEven ? 0 : 1,
                    facingAngle: i * .3,
                  ),
                ),
              const Positioned(
                left: 0,
                top: 60,
                width: 100,
                height: 100,
                child: ImpactEffect(progress: 0, seed: 4),
              ),
              const Positioned(
                left: 100,
                top: 60,
                width: 100,
                height: 100,
                child: BoundaryPulse(kind: BoundaryEffectKind.six, progress: 1),
              ),
              const Positioned(
                left: 200,
                top: 60,
                width: 100,
                height: 100,
                child: CatchRing(progress: 1, success: true),
              ),
              const Positioned(
                left: 0,
                top: 170,
                width: 300,
                height: 80,
                child: ResultCallout(
                  callout: ResultCalloutVisual.victory,
                  subtitle: '14 chased in 5 balls',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

class _VisualGallery extends StatelessWidget {
  const _VisualGallery();

  @override
  Widget build(BuildContext context) {
    return StadiumBackdrop(
      animationProgress: .85,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned(
            left: 20,
            right: 20,
            top: 20,
            height: 150,
            child: FinalOverWordmark(progress: 1),
          ),
          const Positioned(
            left: 35,
            right: 35,
            top: 165,
            bottom: 205,
            child: PerspectivePitch(showGuide: true, ballProgress: .58),
          ),
          const Positioned(
            left: 35,
            top: 265,
            width: 125,
            height: 210,
            child: FinalOverBatterRig(
              pose: BatterPose.loftStraight,
              progress: .67,
            ),
          ),
          const Positioned(
            right: 40,
            top: 205,
            width: 105,
            height: 185,
            child: FinalOverBowlerRig(pose: BowlerPose.release, progress: .7),
          ),
          const Positioned(
            right: 102,
            top: 355,
            width: 52,
            height: 85,
            child: StumpsVisual(),
          ),
          const Positioned(
            left: 40,
            right: 40,
            bottom: 130,
            height: 70,
            child: TimingMeter(errorMilliseconds: 43),
          ),
          const Positioned(
            left: 50,
            bottom: 40,
            width: 64,
            height: 64,
            child: ShotDirectionIcon(
              direction: ShotDirectionVisual.off,
              selected: true,
            ),
          ),
          const Positioned(
            left: 148,
            bottom: 40,
            width: 64,
            height: 64,
            child: ShotDirectionIcon(
              direction: ShotDirectionVisual.straight,
              selected: true,
            ),
          ),
          const Positioned(
            right: 50,
            bottom: 40,
            width: 64,
            height: 64,
            child: ShotElevationIcon(
              elevation: ShotElevationVisual.loft,
              selected: true,
            ),
          ),
          const Positioned(
            left: 80,
            right: 80,
            top: 225,
            bottom: 245,
            child: TrajectoryTrail(
              points: <Offset>[
                Offset(.1, .8),
                Offset(.3, .48),
                Offset(.56, .2),
                Offset(.82, .34),
              ],
              progress: .72,
            ),
          ),
        ],
      ),
    );
  }
}
