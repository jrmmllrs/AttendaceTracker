
import 'package:flutter/foundation.dart';

class AttendanceSync {
  AttendanceSync._();

  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static void notifyChanged() {
    version.value++;
  }
}
