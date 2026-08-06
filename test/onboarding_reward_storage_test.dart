import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('onboarding reward status persists pending and seen', () async {
    final storage = SecureGameStorage();

    expect(await storage.loadOnboardingRewardStatus(), isNull);

    await storage.saveOnboardingRewardStatus(OnboardingRewardStatus.pending);
    expect(
      await storage.loadOnboardingRewardStatus(),
      OnboardingRewardStatus.pending,
    );

    await storage.saveOnboardingRewardStatus(OnboardingRewardStatus.seen);
    expect(
      await storage.loadOnboardingRewardStatus(),
      OnboardingRewardStatus.seen,
    );
  });

  test('profile reset preserves the reward status', () async {
    final storage = SecureGameStorage();
    await storage.saveOnboardingRewardStatus(OnboardingRewardStatus.seen);

    await storage.resetProfileSetup();

    expect(await storage.loadOnboardingComplete(), isFalse);
    expect(
      await storage.loadOnboardingRewardStatus(),
      OnboardingRewardStatus.seen,
    );
  });
}
