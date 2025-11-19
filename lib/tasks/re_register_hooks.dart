import 'package:glob/glob.dart';
import 'package:hooksman/tasks/shell_task.dart';

/// The `ReRegisterHooks` task automates the process of re-registering Git hooks
/// whenever any hook files are created, modified, or deleted. This ensures that
/// changes to your hooks are applied, as Dart files are compiled into
/// executables
/// and copied to the `.git/hooks` directory.
///
/// Example usage:
///
/// ```dart
/// Hook main() {
///   return Hook(
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
