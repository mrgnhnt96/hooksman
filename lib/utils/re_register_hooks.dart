import 'package:git_hooks/git_hooks.dart';

class ReRegisterHooks extends ShellScript {
  ReRegisterHooks({String? pathToHooksDir})
      : super(
          pathPatterns: [
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
