import 'package:hooksman/hooksman.dart';

Hook main() {
  return DebugHook(
    tasks: [
      // ReRegisterHooks(),
      // ShellTask(
      //   include: [Glob('**.dart')],
      //   exclude: [
      //     Glob('**.g.dart'),
      //     Glob('hooks/**'),
      //   ],
      //   commands: (files) => [
      //     'dart analyze --fatal-infos ${files.join(' ')}',
      //   ],
      // ),
      // ShellTask(
      //   include: [Glob('lib/models/**.dart')],
      //   exclude: [Glob('**.g.dart')],
      //   commands: (files) => [
      //     'sip run build_runner build',
      //   ],
      // ),
      // ShellTask(
      //   include: [Glob('**.dart')],
      //   commands: (files) => [
      //     'dart format ${files.join(' ')}',
      //   ],
      // ),
      // ShellTask(
      //   include: [Glob('**.dart')],
      //   exclude: [Glob('hooks/**')],
      //   commands: (files) => [
      //     'sip test --concurrent --bail',
      //   ],
      // ),
      ShellTask.always(
        commands: (_) => [
          'sleep 30',
        ],
      ),
      SequentialTasks(
        name: 'stuff',
        tasks: [
          DartTask(
            name: 'first dart task',
            include: [Glob('**.dart')],
            exclude: [Glob('hooks/**')],
            run: (files) async {
              await Future<void>.delayed(const Duration(seconds: 5));

              return 0;
            },
          ),
          SequentialTasks(
            name: 'more stuff',
            tasks: [
              DartTask(
                name: 'second dart task',
                include: [Glob('**.dart')],
                exclude: [Glob('hooks/**')],
                run: (files) async {
                  await Future<void>.delayed(const Duration(seconds: 5));

                  return 0;
                },
              ),
              SequentialTasks(
                name: 'one more stuff',
                tasks: [
                  DartTask(
                    name: 'third dart task',
                    include: [Glob('**.dart')],
                    exclude: [Glob('hooks/**')],
                    run: (files) async {
                      await Future<void>.delayed(const Duration(seconds: 5));

                      return 0;
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
