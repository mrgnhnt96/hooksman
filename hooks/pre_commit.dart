import 'package:hooksman/hooksman.dart';

Hook main() {
  return Hook(
    tasks: [
      ReRegisterHooks(),
      ShellTask(
        include: [Glob('**.dart')],
        exclude: [
          Glob('**.g.dart'),
          Glob('hooks/**'),
        ],
        commands: (files) => [
          'dart analyze --fatal-infos ${files.join(' ')}',
        ],
      ),
      ShellTask(
        include: [Glob('lib/models/**.dart')],
        exclude: [Glob('**.g.dart')],
        commands: (files) => [
          'sip run build_runner build',
        ],
      ),
      ShellTask(
        include: [Glob('**.dart')],
        commands: (files) => [
          'dart format ${files.join(' ')}',
        ],
      ),
      ShellTask(
        include: [Glob('**.dart')],
        exclude: [Glob('hooks/**')],
        commands: (files) => [
          'sip test --concurrent --bail',
        ],
      ),
    ],
  );
}
