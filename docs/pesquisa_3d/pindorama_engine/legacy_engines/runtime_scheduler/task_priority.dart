/// Execution priority levels for asynchronous background tasks.
enum TaskPriority {
  critical, // Direct user input or current frame animation
  high,     // Question generation, lesson evaluation
  normal,   // Prefetching next screen, cache write-through
  idle;     // Telemetry flush, background sync, log rotation

  int get weight {
    switch (this) {
      case TaskPriority.critical:
        return 100;
      case TaskPriority.high:
        return 75;
      case TaskPriority.normal:
        return 50;
      case TaskPriority.idle:
        return 10;
    }
  }
}
