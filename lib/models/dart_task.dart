import 'dart:async';

import 'package:git_hooks/models/hook_task.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'dart_task.g.dart';

final class DartTask extends HookTask {
  const DartTask({
    required super.pathPatterns,
    required this.script,
    super.excludePatterns,
    super.name,
  });

  DartTask.always({
    required this.script,
    super.name,
  }) : super(pathPatterns: [AllFiles()]);

  final FutureOr<int> Function(Iterable<String> files) script;

  @override
  List<Object?> get props => _$props;
}
