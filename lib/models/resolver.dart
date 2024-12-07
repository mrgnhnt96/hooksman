import 'package:equatable/equatable.dart';
import 'package:file/file.dart';
import 'package:hooksman/models/hook.dart';
import 'package:hooksman/models/resolved_hook.dart';
import 'package:hooksman/models/resolved_hook_task.dart';

part 'resolver.g.dart';

class Resolver extends Equatable {
  const Resolver({
    required this.hook,
    required this.fs,
  });

  final Hook hook;
  final FileSystem fs;

  ResolvedHook resolve(Iterable<String> files) {
    Iterable<ResolvedHookTask> commands() sync* {
      for (final task in hook.tasks) {
        final filtered = task.filterFiles(files);

        yield ResolvedHookTask(
          files: filtered.toList(),
          original: task,
          index: hook.tasks.indexOf(task),
          label: task.label(filtered),
        );
      }
    }

    return ResolvedHook(
      files: files.toList(),
      tasks: commands().toList(),
    );
  }

  @override
  List<Object?> get props => _$props;
}
