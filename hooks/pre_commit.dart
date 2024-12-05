import 'package:git_hooks/git_hooks.dart';

Hook main() {
  return Hook(
    commands: [
      ReRegisterHooks(),
      ShellScript(
        pathPatterns: [Glob('**.dart')],
        excludePatterns: [Glob('**.g.dart')],
        commands: (files) => [
          'dart analyze --fatal-infos ${files.join(' ')}',
        ],
      ),
      ShellScript(
        pathPatterns: [Glob('**/models/**.dart')],
        excludePatterns: [Glob('**.g.dart')],
        commands: (files) => [
          'sip run build_runner build',
        ],
      ),
      ShellScript(
        pathPatterns: [Glob('**.dart')],
        commands: (files) => [
          'sip test --concurrent --bail',
        ],
      ),
    ],
  );
}
