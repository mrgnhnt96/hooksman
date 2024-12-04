import 'package:git_hooks/git_hooks.dart';

Hook main() {
  return Hook(
    commands: [
      ReRegisterHooks(),
      ShellScript(
        pathPatterns: [Glob('**.dart')],
        commands: (files) => [
          'dart analyze --fatal-infos ${files.join(' ')}',
        ],
      ),
      ShellScript(
        pathPatterns: [Glob('**.dart')],
        commands: (files) => [
          'sleep 3',
          'sip run build_runner build',
        ],
      ),
    ],
  );
}
