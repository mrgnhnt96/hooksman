import 'package:glob/glob.dart';
import 'package:hooksman/tasks/shell_task.dart';

/// The `ReRegisterHooks` task automates the process of re-registering Git hooks
/// whenever any hook files are created, modified, or deleted. This ensures that
/// changes to your hooks are applied: Dart sources are compiled into
/// executables under `.dart_tool/hooksman/`, and thin shims are written to
/// `hooks/_` (Git's `core.hooksPath`).
///
/// Example usage:
///
/// ```dart
/// Hook main() {
///   return PreCommitHook(
///     tasks: [
///       ReRegisterHooks(),
///     ],
///   );
/// }
/// ```
///
/// If your `hooks` directory is not found in the root of your project, you can
/// specify the path to the `hooks` directory:
///
/// ```dart
/// ReRegisterHooks(pathToHooksDir: 'path/to/hooks'),
/// ```
final class ReRegisterHooks extends ShellTask {
  ReRegisterHooks({String? pathToHooksDir})
    : super(
        name: 'Re-register hooks',
        include: [
          if (pathToHooksDir case final String path)
            Glob('$path/**.{dart,sh}')
          else
            Glob('hooks/**.{dart,sh}'),
        ],
        exclude: [
          if (pathToHooksDir case final String path)
            Glob('$path/_/**')
          else
            Glob('hooks/_/**'),
        ],
        commands: (_) {
          final changeDir = switch (pathToHooksDir) {
            String() => 'cd $pathToHooksDir || exit 1;',
            _ => '',
          };

          const package = 'hooksman';

          return [
            '''
# Running hooksman register
$changeDir
if dart pub deps | grep -q "$package "; then
  dart run hooksman register
elif dart pub global list | grep -q "^$package "; then
  dart run hooksman register
else
  echo "Not installed"
  exit 1
fi
''',
          ];
        },
      );
}
