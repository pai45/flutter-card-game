import 'package:card_game/blocs/referral/referral_cubit.dart';
import 'package:card_game/models/referral.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('referral entry round trips through json', () {
    final entry = ReferralEntry(
      id: 'ref-1',
      friendName: 'Vortex',
      status: ReferralStatus.rewarded,
      createdAt: DateTime(2026, 6, 22),
      reward: 500,
    );

    final restored = ReferralEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.friendName, entry.friendName);
    expect(restored.status, ReferralStatus.rewarded);
    expect(restored.createdAt, entry.createdAt);
    expect(restored.reward, 500);
  });

  test(
    'first load seeds demo referrals and later loads do not reseed',
    () async {
      final storage = SecureGameStorage();
      final cubit = ReferralCubit(storage);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loading, isFalse);
      expect(
        cubit.state.referralLink,
        startsWith('https://play.statoz.app/invite?ref='),
      );
      expect(cubit.state.referrals, hasLength(2));
      expect(cubit.state.referrals[0].friendName, 'NovaQ');
      expect(cubit.state.referrals[0].status, ReferralStatus.invited);
      expect(cubit.state.referrals[1].friendName, 'Vortex');
      expect(cubit.state.referrals[1].status, ReferralStatus.pending);

      await storage.saveReferralEntries([cubit.state.referrals.last]);
      final restored = ReferralCubit(storage);
      addTearDown(restored.close);
      await restored.load();

      expect(restored.state.referrals, hasLength(1));
      expect(restored.state.referrals.single.friendName, 'Vortex');
    },
  );

  test('simulation rewards Vortex once and persists the result', () async {
    final storage = SecureGameStorage();
    final cubit = ReferralCubit(storage);
    addTearDown(cubit.close);
    await cubit.load();

    final first = await cubit.simulateFriendJoined();
    final second = await cubit.simulateFriendJoined();

    expect(first?.friendName, 'Vortex');
    expect(first?.status, ReferralStatus.rewarded);
    expect(first?.reward, 500);
    expect(second, isNull);
    expect(cubit.state.rewardedCount, 1);
    expect(cubit.state.coinsEarned, 500);

    final persisted = await storage.loadReferralEntries();
    expect(persisted?.last.status, ReferralStatus.rewarded);
    expect(persisted?.last.reward, 500);
  });

  test('rapid simulation calls can only reward one pending referral', () async {
    final cubit = ReferralCubit(SecureGameStorage());
    addTearDown(cubit.close);
    await cubit.load();

    final results = await Future.wait([
      cubit.simulateFriendJoined(),
      cubit.simulateFriendJoined(),
    ]);

    expect(results.whereType<ReferralEntry>(), hasLength(1));
    expect(cubit.state.rewardedCount, 1);
    expect(cubit.state.coinsEarned, 500);
  });
}
