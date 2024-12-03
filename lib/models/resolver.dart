import 'package:equatable/equatable.dart';
import 'package:file/file.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/hook_command.dart';
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
    Iterable<HookCommand> commands() sync* {
      final commandsToResolve = [...hook.commands];

      for (final file in files) {
        if (commandsToResolve.isEmpty) {
          break;
        }

        for (final command in hook.commands) {
          if (command.pathPatterns.any((e) => e.matches(file))) {
            commandsToResolve.remove(command);

            yield command;
            break;
          }
        }
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
