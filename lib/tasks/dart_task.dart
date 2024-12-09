import 'dart:async';

import 'package:hooksman/tasks/hook_task.dart';

typedef Run = FutureOr<int> Function(List<String> files);

class DartTask extends HookTask {
  DartTask({
    required super.include,
    required Run run,
    super.exclude,
    this.name,
  }) : _run = run;

  final Run _run;

  @override
  final String? name;

  @override
  Future<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  }) async {
    startTask(this);
    final result = await _run(files);

    completeTask(this, result);

    return result;
  }
}
