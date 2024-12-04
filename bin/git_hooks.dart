import 'package:file/local.dart';
import 'package:git_hooks/commands/git_hook_runner.dart';
import 'package:git_hooks/models/compiler.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

Future<int> main(List<String> providedArgs) async {
  final args = [...providedArgs];
  const fs = LocalFileSystem();
  final logger = Logger();

  if (args.contains('--loud')) {
    logger.level = Level.verbose;
  } else if (args.contains('--quiet')) {
    logger.level = Level.error;
  }

  args
    ..remove('--loud')
    ..remove('--quiet');

  final gitHook = GitHookRunner(
    fs: fs,
    logger: logger,
    git: GitService(
      logger: logger,
      fs: fs,
    ),
    compiler: const Compiler(),
  );

  final exitCode = await gitHook.run(args);

  return exitCode ?? 0;
}
