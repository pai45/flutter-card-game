import 'package:card_game/blocs/friends/friends_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/tennis/tennis_cubit.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/profile/profile_screen.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('confirmed logout reaches the shell callback', (tester) async {
    var logoutCalls = 0;
    final storage = SecureGameStorage();
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => GameBloc(storage)),
          BlocProvider(create: (_) => FriendsCubit(storage)),
          BlocProvider(
            create: (_) => PredictionCubit(MockPredictionRepository(), storage),
          ),
          BlocProvider(
            create: (_) => PicksCubit(MockPickRepository(), storage),
          ),
          BlocProvider(create: (_) => TennisCubit(storage)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProfileScreen(
            onNavigate: (_) {},
            onLogout: () async {
              logoutCalls++;
            },
            onChallenge: (_, _) {},
            onOpenSportGames: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final settings = find.text('Settings');
    await tester.ensureVisible(settings);
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pump(const Duration(milliseconds: 300));

    final logout = find.text('LOG OUT');
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('SWITCH PLAYER PROFILE?'), findsOneWidget);

    await tester.tap(find.text('CONTINUE >'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(logoutCalls, 1);
    expect(find.text('SWITCH PLAYER PROFILE?'), findsNothing);
  });
}
