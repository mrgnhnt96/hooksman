import 'package:file/memory.dart';
import 'package:git_hooks/entrypoint/execute_hook.dart';
import 'package:git_hooks/models/dart_script.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/models/shell_script.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart';

void main() async {
  final logger = Logger();
  final fs = MemoryFileSystem();

  final hook = Hook(
    commands: [
      DartScript(
        pathPatterns: [RegExp(r'.*\.dart$')],
        script: (files) async {
          await Future<void>.delayed(const Duration(seconds: 3));
          return 0;
        },
      ),
      ShellScript(
        pathPatterns: [RegExp('no-match')],
        commands: (files) {
          return [
            'echo "Hello, World!"',
          ];
        },
      ),
      ShellScript(
        pathPatterns: [Glob('*.sh')],
        commands: (files) {
          return [
            'echo "Hello, World!"',
            'echo "Hello, World!"',
            'echo "Hello, World!"',
          ];
        },
      ),
      ShellScript(
        name: 'Markdown',
        pathPatterns: [Glob('*.md')],
        commands: (files) {
          return [
            'dart analyze --fatal-infos --fatal-warnings .' * 8,
          ];
        },
      ),
    ],
  );

  await run(
    hook,
    hookName: 'pre-commit',
    logger: logger,
    gitService: _GitService(
      logger: logger,
      fs: fs,
    ),
    resolver: Resolver(hook: hook, fs: fs),
  );
}

class _GitService extends GitService {
  const _GitService({
    required super.fs,
    required super.logger,
  });

  @override
  Future<List<String>?> getChangedFiles(List<String> diff) async {
    return [
      'lib/entrypoint/execute_hook.dart',
      'lib/entrypoint/fake_execute_hook.dart',
      'README.md',
      'script1.sh',
      'script2.sh',
      'script3.sh',
    ];
  }
}
