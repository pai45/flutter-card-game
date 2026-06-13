import 'package:card_game/widgets/staggered_card_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const childKey = ValueKey('entrance-child');

  testWidgets('starts offset left and transparent, then settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(
        child: StaggeredCardEntrance(
          index: 0,
          animate: true,
          child: SizedBox(key: childKey, width: 20, height: 20),
        ),
      ),
    );

    expect(_opacityFor(tester, childKey).opacity, 0);
    expect(_translationXFor(tester, childKey), lessThan(0));

    await tester.pumpAndSettle();

    expect(_opacityFor(tester, childKey).opacity, 1);
    expect(_translationXFor(tester, childKey), 0);
  });

  testWidgets('renders child directly when animation is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(
        child: StaggeredCardEntrance(
          index: 0,
          animate: false,
          child: SizedBox(key: childKey, width: 20, height: 20),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    expect(find.byType(Transform), findsNothing);
  });
}

Opacity _opacityFor(WidgetTester tester, Key childKey) {
  return tester.widget<Opacity>(
    find.ancestor(of: find.byKey(childKey), matching: find.byType(Opacity)),
  );
}

double _translationXFor(WidgetTester tester, Key childKey) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.byKey(childKey), matching: find.byType(Transform)),
  );
  return transform.transform.getTranslation().x;
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }
}
