// pre_commit.dart
import 'package:hooksman/hooksman.dart';

Hook main() {
  return PreCommitHook(
    tasks: [
      ReRegisterHooks(),
      ShellTask(
        name: 'Lint & Format',
        include: [Glob('**.dart')],
        exclude: [Glob('**.g.dart')],
        commands: (filePaths) => [
          'dart analyze --fatal-infos ${filePaths.join(' ')}',
          'dart format ${filePaths.join(' ')}',
        ],
      ),
      ShellTask(
        name: 'Build Runner',
        include: [Glob('lib/models/**.dart')],
        exclude: [Glob('**.g.dart')],
        commands: (filePaths) => ['sip run build_runner build'],
      ),
      ShellTask(
        name: 'Tests',
        include: [Glob('**.dart')],
        exclude: [Glob('hooks/**')],
        commands: (filePaths) => ['sip test --concurrent --bail'],
      ),
    ],
  );
}
