import 'package:hooksman/commands/register_command.dart';
import 'package:hooksman/commands/uninstall_command.dart';
import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/logger.dart';

const _usage = '''
Usage: hooksman <command>

Generate git hooks and tasks using Dart scripts and Shell commands.

Commands:
  [register]   Register git hooks (default)
  uninstall    Unset core.hooksPath and remove managed hooks/_ shims
''';

class GitHookRunner {
  const GitHookRunner();

  Future<int> run() async {
    switch (args.path) {
      case [] || ['register']:
        return const RegisterCommand().run();
      case ['uninstall']:
        return const UninstallCommand().run();
    }

    logger.write(_usage);

    return 1;
  }
}
