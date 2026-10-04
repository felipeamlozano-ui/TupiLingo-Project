import 'package:tupi_lingo/features/runtime_scheduler/task_priority.dart';

/// Battery state and power saving policy monitor.
class BatteryAwareScheduler {
  bool isLowPowerMode = false;
  int batteryLevelPercent = 100;

  /// Returns true if a task with [priority] is allowed to run under current power conditions.
  bool shouldRun(TaskPriority priority) {
    if (priority == TaskPriority.critical || priority == TaskPriority.high) {
      return true;
    }
    // In low power mode or battery < 15%, defer normal and idle tasks
    if (isLowPowerMode || batteryLevelPercent < 15) {
      return false;
    }
    return true;
  }
}
