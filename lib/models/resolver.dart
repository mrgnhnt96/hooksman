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

  Iterable<ResolvedHook> resolve(Iterable<String> files) sync* {
    final resolvedHooks = <HookCommand>[];
    final commandsToResolve = [...hook.commands];

    for (final file in files) {
      if (commandsToResolve.isEmpty) {
        break;
      }

      for (final command in hook.commands) {
        if (command.pathPatterns.any((e) => e.matches(file))) {
          resolvedHooks.add(command);
          commandsToResolve.remove(command);
          break;
        }
      }
    }

    for (final hook in commandsToResolve) {
      final resolvedHook = ResolvedHook(
        commands: hook.commands(files),
        workingDirectory: hook.workingDirectory ?? fs.currentDirectory.path,
      );

      yield resolvedHook;
    }
  }

  @override
  List<Object?> get props => _$props;
}
