import 'dart:async';

import 'package:git_hooks/models/hook_task.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'dart_task.g.dart';

final class DartTask extends HookTask {
  const DartTask({
    required super.include,
    required this.run,
    super.exclude,
    super.name,
  });

  DartTask.always({
    required this.run,
    super.name,
  }) : super(include: [AllFiles()]);

  final FutureOr<int> Function(Iterable<String> files) run;

  @override
  List<Object?> get props => _$props;
}
