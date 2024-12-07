import 'package:glob/glob.dart';
import 'package:hooksman/models/shell_task.dart';

final class ReRegisterHooks extends ShellTask {
  ReRegisterHooks({String? pathToHooksDir})
      : super(
          include: [
            if (pathToHooksDir case final String path)
              Glob('$path/*.dart')
            else
              Glob('hooks/*.dart'),
          ],
          commands: (_) {
            final changeDir = switch (pathToHooksDir) {
              String() => 'cd $pathToHooksDir &&',
              _ => '',
            };

            return [
              '$changeDir dart run hooksman register',
            ];
          },
        );
}
