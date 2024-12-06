import 'package:git_hooks/git_hooks.dart';

Hook main() {
  return Hook(
    commands: [
      ReRegisterHooks(),
      ShellTask(
        pathPatterns: [Glob('**.dart')],
        excludePatterns: [
          Glob('**.g.dart'),
          Glob('hooks/**'),
        ],
        commands: (files) => [
          'dart analyze --fatal-infos ${files.join(' ')}',
        ],
      ),
      ShellTask(
        pathPatterns: [Glob('lib/models/**.dart')],
        excludePatterns: [Glob('**.g.dart')],
        commands: (files) => [
          'sip run build_runner build',
        ],
      ),
      ShellTask(
        pathPatterns: [Glob('**.dart')],
        commands: (files) => [
          'dart format ${files.join(' ')}',
        ],
      ),
      ShellTask(
        pathPatterns: [Glob('**.dart')],
        excludePatterns: [Glob('hooks/**')],
        commands: (files) => [
          'sip test --concurrent --bail',
        ],
      ),
    ],
  );
}
