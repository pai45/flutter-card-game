import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/shop/shop_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('motorsport AvatarsTab shows series chips and driver tiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(gameBloc.close);

    await tester.pumpWidget(
      BlocProvider<GameBloc>.value(
        value: gameBloc,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            backgroundColor: Cyber.bg,
            body: AvatarsTab(
              sport: Sport.motorsport,
              onAcquired:
                  ({
                    required preview,
                    required name,
                    required accent,
                    required coinsSpent,
                  }) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('F1'), findsOneWidget);
    expect(find.text('NASCAR'), findsOneWidget);
    expect(find.text('M VERSTAPPEN'), findsOneWidget);
    expect(find.text('L NORRIS'), findsOneWidget);

    await tester.tap(find.text('F2'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('M VERSTAPPEN'), findsNothing);
  });
}
