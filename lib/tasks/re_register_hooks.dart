import 'package:glob/glob.dart';
import 'package:hooksman/tasks/shell_task.dart';

final class ReRegisterHooks extends ShellTask {
  ReRegisterHooks({String? pathToHooksDir})
      : super(
          name: 'Re-register hooks',
          include: [
            if (pathToHooksDir case final String path)
              Glob('$path/**.dart')
            else
              Glob('hooks/**.dart'),
          ],
          commands: (_) {
            final changeDir = switch (pathToHooksDir) {
              String() => 'cd $pathToHooksDir || exit 1;',
              _ => '',
            };

            const package = 'hooksman';

            return [
              '''
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
