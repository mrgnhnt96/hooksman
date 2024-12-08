import 'package:hooksman/hooksman.dart';

Hook main() {
  return Hook(
    tasks: [
      // ReRegisterHooks(),
      // ShellTask(
      //   name: 'Lint & Format',
      //   include: [Glob('**.dart')],
      //   exclude: [
      //     Glob('**.g.dart'),
      //   ],
      //   commands: (files) => [
      //     'dart analyze --fatal-infos ${files.join(' ')}',
      //     'dart format ${files.join(' ')}',
      //   ],
      // ),
      // ShellTask(
      //   name: 'Build Runner',
      //   include: [Glob('lib/models/**.dart')],
      //   exclude: [Glob('**.g.dart')],
      //   commands: (files) => [
      //     'sip run build_runner build',
      //   ],
      // ),
      ParallelTasks(
        name: 'Build Runner',
        include: [Glob('**.dart')],
        tasks: [
          ShellTask(
            include: [AllFiles()],
            commands: (files) => [
              'exit 1',
            ],
          ),
          ShellTask(
            include: [AllFiles()],
            commands: (files) => [
              'sleep 1',
            ],
          ),
          ShellTask(
            include: [AllFiles()],
            commands: (files) => [
              'sleep 1',
            ],
          ),
          ShellTask(
            include: [AllFiles()],
            commands: (files) => [
              'sleep 1',
            ],
          ),
        ],
      ),
      // ShellTask(
      //   name: 'Tests',
      //   include: [Glob('**.dart')],
      //   exclude: [Glob('hooks/**')],
      //   commands: (files) => [
      //     'sip test --concurrent --bail',
      //   ],
      // ),
    ],
  );
}
