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
          commands: (_) => [
            'dart run git_hooks register',
          ],
        );
}
