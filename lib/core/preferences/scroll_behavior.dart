import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        // REMOVED PointerDeviceKind.mouse to prevent click interception on Linux
        PointerDeviceKind.trackpad,
      };
}