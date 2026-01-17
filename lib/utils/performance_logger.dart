import 'dart:developer' as developer;

/// Performance logging utility to track slow operations and identify bottlenecks
class PerformanceLogger {
  static final Map<String, Stopwatch> _timers = {};
  static final List<PerformanceEvent> _events = [];
  static const int _maxEvents = 100; // Keep last 100 events
  
  /// Start timing an operation
  static void start(String operation) {
    _timers[operation] = Stopwatch()..start();
  }
  
  /// End timing an operation and log if it exceeds threshold
  static void end(String operation, {Duration? threshold}) {
    final timer = _timers.remove(operation);
    if (timer == null) return;
    
    timer.stop();
    final duration = timer.elapsed;
    final thresholdMs = threshold?.inMilliseconds ?? 100; // Default 100ms threshold
    
    final event = PerformanceEvent(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
    );
    
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
    
    if (duration.inMilliseconds > thresholdMs) {
      developer.log(
        '⚠️ SLOW OPERATION: $operation took ${duration.inMilliseconds}ms (threshold: ${thresholdMs}ms)',
        name: 'Performance',
      );
    } else {
      developer.log(
        '✓ $operation: ${duration.inMilliseconds}ms',
        name: 'Performance',
      );
    }
  }
  
  /// Log a performance event without timing
  static void log(String message, {String level = 'info'}) {
    developer.log(
      message,
      name: 'Performance',
      level: level == 'error' ? 1000 : 800,
    );
  }
  
  /// Get recent slow operations
  static List<PerformanceEvent> getSlowEvents({Duration? threshold}) {
    final thresholdMs = threshold?.inMilliseconds ?? 100;
    return _events.where((e) => e.duration.inMilliseconds > thresholdMs).toList();
  }
  
  /// Clear all events
  static void clear() {
    _events.clear();
    _timers.clear();
  }
}

class PerformanceEvent {
  final String operation;
  final Duration duration;
  final DateTime timestamp;
  
  PerformanceEvent({
    required this.operation,
    required this.duration,
    required this.timestamp,
  });
  
  @override
  String toString() => '${operation}: ${duration.inMilliseconds}ms at ${timestamp.toIso8601String()}';
}
