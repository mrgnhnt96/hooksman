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
        // Scoped to test/ on purpose. sip discovers tests with a
        // `**/*_test.dart` glob from the package root and offers no way to
        // exclude a directory, so an unscoped run walks into the gitignored
        // gen/ tree and tries to compile the vendored packages' own tests.
        // Those never resolve here, and the whole run reports zero tests.
        commands: (filePaths) => ['sip test --concurrent --bail test/'],
      ),
    ],
  );
}
