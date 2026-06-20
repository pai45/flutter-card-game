import 'package:card_game/blocs/friends/friends_cubit.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('loads an empty friends list by default', () async {
    final cubit = FriendsCubit(SecureGameStorage());
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.friends, isEmpty);
  });

  test('add / remove updates state and membership checks', () async {
    final cubit = FriendsCubit(SecureGameStorage());
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.addFriend('jarvis');
    expect(cubit.isFriend('jarvis'), isTrue);
    expect(cubit.state.friends, ['jarvis']);

    // Adding the same rival twice is a no-op.
    await cubit.addFriend('jarvis');
    expect(cubit.state.friends, ['jarvis']);

    await cubit.removeFriend('jarvis');
    expect(cubit.isFriend('jarvis'), isFalse);
    expect(cubit.state.friends, isEmpty);
  });

  test('toggle returns new membership and round-trips through storage',
      () async {
    final storage = SecureGameStorage();
    final cubit = FriendsCubit(storage);
    addTearDown(cubit.close);
    await cubit.load();

    expect(await cubit.toggleFriend('Vortex'), isTrue);
    expect(await cubit.toggleFriend('Vortex'), isFalse);
    expect(await cubit.toggleFriend('Vortex'), isTrue);

    // A fresh cubit hydrates the persisted friend.
    final restored = FriendsCubit(storage);
    addTearDown(restored.close);
    await restored.load();
    expect(restored.state.friends, ['Vortex']);
  });
}
