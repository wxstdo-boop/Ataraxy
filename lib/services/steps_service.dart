import 'dart:async';

import 'package:pedometer/pedometer.dart';

/// Счётчик шагов. На платформах без датчика (например, Windows-десктоп)
/// поток завершается ошибкой — потребитель должен это обработать.
class StepsService {
  static Stream<int> get stream {
    late StreamController<int> controller;
    controller = StreamController<int>.broadcast(
      onListen: () {
        try {
          Pedometer.stepCountStream.listen(
            (e) => controller.add(e.steps),
            onError: (e) {
              if (!controller.isClosed) controller.addError(e);
            },
            cancelOnError: false,
          );
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }
      },
      onCancel: () => controller.close(),
    );
    return controller.stream;
  }
}
