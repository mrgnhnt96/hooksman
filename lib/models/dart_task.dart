import 'dart:async';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/utils/all_files.dart';

part 'dart_task.g.dart';

typedef Run = FutureOr<int> Function(List<String> files);

class DartTask extends HookTask {
  DartTask({
    required super.include,
    required Run run,
    super.exclude,
    this.name,
  }) : _run = run;

  DartTask.always({
    required Run run,
    this.name,
  })  : _run = run,
        super(include: [AllFiles()]);

  final Run _run;

  @override
  final String? name;

  @override
  Future<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask) completeTask,
  }) async {
    try {
      final result = await _run(files);

      completeTask(this);

      return result;
    } catch (e) {
      print('Error when running $resolvedName');
      print('$e');

      return 1;
    }
  }

  @override
  List<Object?> get props => _$props;
}
