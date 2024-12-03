import 'package:equatable/equatable.dart';
import 'package:file/file.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolved_hook.dart';

part 'resolver.g.dart';

class Resolver extends Equatable {
  const Resolver({
    required this.hooks,
    required this.fs,
  });

  final List<Hook> hooks;
  final FileSystem fs;

  Iterable<ResolvedHook> resolve(Iterable<String> files) sync* {
    final resolvedHooks = <Hook>[];
    final hooksToResolve = [...hooks];

    for (final file in files) {
      if (hooksToResolve.isEmpty) {
        break;
      }

      for (final hook in hooks) {
        if (hook.pathPatterns.any((e) => e.matches(file))) {
          resolvedHooks.add(hook);
          hooksToResolve.remove(hook);
          break;
        }
      }
    }

    for (final hook in hooksToResolve) {
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
