import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/widgets/themed_time_picker.dart';

void main() {
  testWidgets('time picker opens as a bottom PLATE, not a centred dialog', (
    tester,
  ) async {
    TimeOfDay? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showThemedTimePicker(
                    context,
                    initialTime: const TimeOfDay(hour: 20, minute: 15),
                  );
                },
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    // The plate is a modal bottom sheet (a ModalBottomSheetRoute), NOT an
    // AlertDialog/`Dialog` — that is the "плашка, а не отдельное окно" change.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    // Both wheels are present: 24 hours and 60 minutes.
    expect(find.byType(ListWheelScrollView), findsNWidgets(2));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 20, minute: 15));
  });

  testWidgets('time picker returns null when dismissed', (tester) async {
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await showThemedTimePicker(
                    context,
                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                  );
                  popped = true;
                },
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
