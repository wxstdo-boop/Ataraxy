import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/widgets/press_scale.dart';

void main() {
  testWidgets('press feedback stays shallow and recoils smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PressScale(scale: 0.88, child: Text('Tap'))),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tap')),
    );
    await tester.pump();

    var scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 0.96);

    await gesture.up();
    await tester.pump();

    scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, const Duration(milliseconds: 300));
  });
}
