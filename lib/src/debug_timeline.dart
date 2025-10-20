import 'dart:developer';
import 'package:flutter/foundation.dart';

/// Helper function to build timeline arguments only in debug mode
///
/// This function optimizes performance by only executing the argument builder
/// function when running in debug mode. In release mode, it returns an empty map.
///
/// [value] - Function that returns the arguments map
/// Returns the arguments map in debug mode, empty map in release mode
Map<String, dynamic> argumentBuilder2(Map<String, dynamic> Function() value) {
  if (kDebugMode) return value();
  return {};
}

/// Type definition for argument builder functions
///
/// Used to define functions that build timeline event arguments
typedef ArgumentBuilder = Map<String, dynamic> Function();

/// Debug timeline wrapper for Flutter's Timeline API
///
/// DebugTimeline provides a convenient wrapper around Flutter's TimelineTask
/// that automatically handles debug mode checks and provides a cleaner API
/// for timeline events. It's designed to have zero overhead in release builds.
///
/// Usage:
/// ```dart
/// final timeline = DebugTimeline(filterKey: 'svga_decode');
/// timeline.start('decode_start', () => {'file': 'animation.svga'});
/// // ... do work ...
/// timeline.finish(() => {'duration': '100ms'});
/// ```
class DebugTimeline {
  /// The filter key used to identify this timeline in profiling tools
  final String filterKey;

  /// Optional parent timeline task for nested operations
  final TimelineTask? parent;

  /// The underlying Flutter TimelineTask (only created in debug mode)
  TimelineTask? task;

  /// Creates a new debug timeline with the specified filter key
  ///
  /// [filterKey] - Unique identifier for this timeline in profiling tools
  /// [parent] - Optional parent timeline for nested operations
  DebugTimeline({required this.filterKey, this.parent}) {
    // Only create the actual TimelineTask in debug mode for performance
    if (kDebugMode) task = TimelineTask(filterKey: filterKey, parent: parent);
  }

  /// Finishes the timeline task with optional arguments
  ///
  /// This should be called when the operation being timed is complete.
  /// The arguments function is only executed in debug mode.
  ///
  /// [arguments] - Optional function that returns arguments for the timeline event
  finish([ArgumentBuilder? arguments]) {
    if (kDebugMode) {
      if (task != null) {
        task!.finish(arguments: arguments?.call());
      }
    }
  }

  /// Records an instant timeline event
  ///
  /// Instant events mark a specific point in time without duration.
  /// Useful for marking milestones or specific events during execution.
  ///
  /// [name] - Name of the instant event
  /// [arguments] - Optional function that returns arguments for the event
  instant(String name, ArgumentBuilder? arguments) {
    if (kDebugMode) {
      if (task != null) {
        task!.instant(name, arguments: arguments?.call());
      }
    }
  }

  /// Starts a named timeline event
  ///
  /// This begins timing a specific operation within the overall timeline.
  /// Should be paired with a corresponding finish() call.
  ///
  /// [name] - Name of the operation being started
  /// [arguments] - Optional function that returns arguments for the event
  start(String name, ArgumentBuilder? arguments) {
    if (kDebugMode) {
      if (task != null) {
        task!.start(name, arguments: arguments?.call());
      }
    }
  }
}
