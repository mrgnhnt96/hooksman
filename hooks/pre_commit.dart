import 'package:git_hooks/git_hooks.dart';

Hook main() {
  return Hook(
    commands: [
      ReRegisterHooks(),
      ShellScript(
        pathPatterns: [Glob('**.dart')],
        excludePatterns: [
          Glob('**.g.dart'),
          Glob('hooks/**'),
        ],
        commands: (files) => [
          'dart analyze --fatal-infos ${files.join(' ')}',
        ],
      ),
      ShellScript(
        pathPatterns: [Glob('**/models/**.dart')],
        excludePatterns: [
          Glob('**.g.dart'),
          Glob('hooks/**'),
          Glob('test/**'),
        ],
        commands: (files) => [
          'sip run build_runner build',
        ],
      ),
      ShellScript(
        pathPatterns: [Glob('**.dart')],
        excludePatterns: [Glob('hooks/**')],
        commands: (files) => [
          'sip test --concurrent --bail',
        ],
      ),
    ],
  );
}
