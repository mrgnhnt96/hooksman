import 'dart:async';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/task_label.dart';
import 'package:hooksman/utils/all_files.dart';

part 'dart_task.g.dart';

typedef Run = FutureOr<int> Function(List<String> files);

class DartTask extends HookTask {
  const DartTask({
    required super.include,
    required Run run,
    super.exclude,
    super.name,
  }) : _run = run;

  DartTask.always({
    required Run run,
    super.name,
  })  : _run = run,
        super(include: [AllFiles()]);

  final Run _run;

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(int) completeSubTask,
  }) =>
      _run(files);

  @override
  TaskLabel label(Iterable<String> files, [int? index]) => TaskLabel(
        resolvedName,
        fileCount: files.length,
      );

  @override
  List<Object?> get props => _$props;
}
