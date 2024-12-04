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
    Iterable<String> filesFor(HookCommand command) sync* {
      for (final file in files) {
        if (command.pathPatterns.any((e) => e.allMatches(file).isNotEmpty)) {
          yield file;
        }
      }
    }

    Iterable<(List<String>, HookCommand)> commands() sync* {
      final commandsToResolve = [...hook.commands];

      for (final file in files) {
        if (commandsToResolve.isEmpty) {
          break;
        }

        void Function()? remove;

        for (final command in commandsToResolve) {
          if (!commandsToResolve.contains(command)) break;

          if (command.pathPatterns.any((e) => e.allMatches(file).isNotEmpty)) {
            remove = () => commandsToResolve.remove(command);
            final files = filesFor(command).toList();
            yield (files, command);

            break;
          }
        }

        remove?.call();
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
