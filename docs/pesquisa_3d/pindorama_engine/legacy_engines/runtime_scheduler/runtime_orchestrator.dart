import 'dart:async';
import 'package:tupi_lingo/features/runtime_scheduler/task_priority.dart';
import 'package:tupi_lingo/features/runtime_scheduler/battery_aware_scheduler.dart';
import 'package:tupi_lingo/core/concurrency/ten_isolates_engine.dart';

class _ScheduledTask<T> {
  final String id;
  final TaskPriority priority;
  final FutureOr<T> Function() action;
  final Completer<T> completer;

  _ScheduledTask({
    required this.id,
    required this.priority,
    required this.action,
    required this.completer,
  });
}

/// Runtime Orchestrator coordinating task prioritization and Isolate execution (Chapter 35).
class RuntimeOrchestrator {
  static final RuntimeOrchestrator instance = RuntimeOrchestrator._internal();
  RuntimeOrchestrator._internal();

  final BatteryAwareScheduler batteryScheduler = BatteryAwareScheduler();
  final List<_ScheduledTask<dynamic>> _queue = [];
  bool _isProcessing = false;

  /// Submits a task to the orchestrator with explicit priority.
  Future<T> submit<T>({
    required String taskId,
    TaskPriority priority = TaskPriority.normal,
    required FutureOr<T> Function() action,
  }) {
    final completer = Completer<T>();
    final task = _ScheduledTask<T>(
      id: taskId,
      priority: priority,
      action: action,
      completer: completer,
    );

    _queue.add(task);
    _sortQueue();
    _processNext();

    return completer.future;
  }

  /// Submits a compute-heavy task to the TenIsolatesEngine pool.
  Future<IsolateTaskResponse> submitToIsolatePool({
    required IsolateRole role,
    required String action,
    Map<String, dynamic>? metadata,
    TaskPriority priority = TaskPriority.high,
  }) async {
    return submit<IsolateTaskResponse>(
      taskId: 'isolate_${role.name}_${DateTime.now().microsecondsSinceEpoch}',
      priority: priority,
      action: () => TenIsolatesEngine.instance.dispatch(
        role: role,
        action: action,
        metadata: metadata,
      ),
    );
  }

  void _sortQueue() {
    _queue.sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final task = _queue.first;

      // Check battery scheduler
      if (!batteryScheduler.shouldRun(task.priority)) {
        // Deferred until conditions improve
        break;
      }

      _queue.removeAt(0);

      try {
        final result = await task.action();
        task.completer.complete(result);
      } catch (e, st) {
        task.completer.completeError(e, st);
      }
    }

    _isProcessing = false;
  }
}
