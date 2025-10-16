import 'dart:developer';
import 'package:flutter/foundation.dart';

Map<String, dynamic> argumentBuilder2(Map<String, dynamic> Function() value) {
  if (kDebugMode) return value();
  return {};
}

typedef ArgumentBuilder = Map<String, dynamic> Function();

class DebugTimeline {
  final String filterKey;
  final TimelineTask? parent;
  late TimelineTask? task;
  DebugTimeline({required this.filterKey, this.parent}) {
    if (kDebugMode) task = TimelineTask(filterKey: filterKey, parent: parent);
  }
  finish([ArgumentBuilder? arguments]) {
    if (kDebugMode) {
      if (task != null) {
        task!.finish(arguments: arguments?.call());
      }
    }
  }

  instant(String name, ArgumentBuilder? arguments) {
    if (kDebugMode) {
      if (task != null) {
        task!.instant(name, arguments: arguments?.call());
      }
    }
  }

  start(String name, ArgumentBuilder? arguments) {
    if (kDebugMode) {
      if (task != null) {
        task!.start(name, arguments: arguments?.call());
      }
    }
  }
}
