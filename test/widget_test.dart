import 'package:card_game/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets('Pitch Duel home renders primary actions', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const PitchDuelApp());
    await tester.pumpAndSettle();

    expect(find.text('PITCH DUEL'), findsOneWidget);
    expect(find.text('PLAY MATCH'), findsOneWidget);
    expect(find.text('DECK BUILDER'), findsOneWidget);
  });
}
