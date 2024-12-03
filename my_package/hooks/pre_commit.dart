import 'package:git_hooks/git_hooks.dart';

Hook main() {
  return Hook(
    commands: [
      HookCommand(
        pathPatterns: [Glob('*.dart')],
        commands: (files) => ['dart analyze --fatal-infos ${files.join(' ')}'],
      ),
    ],
  );
}
