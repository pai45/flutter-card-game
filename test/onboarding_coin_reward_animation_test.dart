import 'package:card_game/screens/onboarding/widgets/onboarding_coin_reward_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reduced motion shows the settled credited state', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 700),
            disableAnimations: true,
          ),
          child: OnboardingCoinRewardAnimation(
            amount: 1000,
            balanceAfter: 1250,
            onComplete: () => completed++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('WELCOME BONUS'), findsOneWidget);
    final amountText = tester.widget<Text>(
      find.byKey(const ValueKey('onboarding-reward-amount')),
    );
    expect(amountText.data, '+1,000');
    expect(find.text('COINS CREDITED TO WALLET'), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-reward-tap-target')),
    );
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('first tap settles and second tap completes exactly once', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 568)),
          child: OnboardingCoinRewardAnimation(
            amount: 1000,
            balanceAfter: 1000,
            onComplete: () => completed++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    final target = find.byKey(const ValueKey('onboarding-reward-tap-target'));
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 220));
    final amountText = tester.widget<Text>(
      find.byKey(const ValueKey('onboarding-reward-amount')),
    );
    expect(amountText.data, '+1,000');
    expect(tester.takeException(), isNull);
    expect(completed, 0);

    await tester.tap(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
    expect(completed, 1);
  });
}
