import 'package:equatable/equatable.dart';
import 'package:file/file.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/hook_task.dart';
import 'package:git_hooks/models/resolved_hook.dart';

part 'resolver.g.dart';

class Resolver extends Equatable {
  const Resolver({
    required this.hook,
    required this.fs,
  });

  final Hook hook;
  final FileSystem fs;

  ResolvedHook resolve(Iterable<String> files) {
    Iterable<String> filesFor(HookTask command) sync* {
      for (final file in files) {
        if (command.excludePatterns.any((e) => e.allMatches(file).isNotEmpty)) {
          continue;
        }

        if (command.pathPatterns.any((e) => e.allMatches(file).isNotEmpty)) {
          yield file;
        }
      }
    }

    Iterable<(Iterable<String>, HookTask)> commands() sync* {
      for (final command in hook.commands) {
        yield (filesFor(command).toList(), command);
      }
    }

    return ResolvedHook(
      files: files.toList(),
      commands: commands().toList(),
    );
  }

  @override
  List<Object?> get props => _$props;
}
