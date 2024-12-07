import 'package:git_hooks/models/shell_task.dart';
import 'package:glob/glob.dart';

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
              '$changeDir dart run git_hooks register',
            ];
          },
        );
}
