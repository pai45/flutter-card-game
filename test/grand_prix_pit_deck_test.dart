import 'package:card_game/blocs/grand_prix/grand_prix_cubit.dart';
import 'package:card_game/data/grand_prix_liveries.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('selectLivery rejects unowned liveries', () async {
    final cubit = GrandPrixCubit(SecureGameStorage());
    await cubit.load();
    cubit.selectLivery(
      GrandPrixLivery.scarlet,
      ownedLiveryIds: defaultOwnedGrandPrixLiveryIds(),
    );
    expect(cubit.state.livery, GrandPrixLivery.gridLine);
    await cubit.close();
  });

  test('selectLivery persists owned picks', () async {
    final cubit = GrandPrixCubit(SecureGameStorage());
    await cubit.load();
    cubit.selectLivery(
      GrandPrixLivery.papaya,
      ownedLiveryIds: ['gridLine', 'papaya'],
    );
    expect(cubit.state.livery, GrandPrixLivery.papaya);
    await Future<void>.delayed(Duration.zero);
    final revived = await SecureGameStorage().loadGrandPrixStats();
    expect(revived.lastLivery, GrandPrixLivery.papaya);
    await cubit.close();
  });

  test('ensureEquippedLiveryOwned clamps saved unowned livery', () async {
    final storage = SecureGameStorage();
    await storage.saveGrandPrixStats(
      const GrandPrixStats(lastLivery: GrandPrixLivery.scarlet),
    );
    final cubit = GrandPrixCubit(storage);
    await cubit.load();
    cubit.ensureEquippedLiveryOwned(defaultOwnedGrandPrixLiveryIds());
    expect(cubit.state.livery, GrandPrixLivery.gridLine);
    await cubit.close();
  });
}
