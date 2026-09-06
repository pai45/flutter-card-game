import 'package:card_game/screens/friends/widgets/friend_request_sent_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('friend request animation confirms and completes', (
    tester,
  ) async {
    var completed = false;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FriendRequestSentAnimation(
          friendName: 'NovaQ',
          enableFeedback: false,
          onComplete: () => completed = true,
        ),
      ),
    );

    expect(find.text('REQUEST SENT'), findsOneWidget);
    expect(find.text('NOVAQ'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Friend request sent to NovaQ'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 1400));

    expect(completed, isTrue);
  });
}
