import 'package:hooksman/commands/git_hook_runner.dart';
import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/compiler.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';
import 'package:hooksman/models/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';

Future<int> main(List<String> arguments) async {
  final args = Args.parse(arguments);

  final logger = Logger();

  if (args['loud'] case true) {
    logger.level = Level.verbose;
  } else if (args['quiet'] case true) {
    logger.level = Level.error;
  }

  return runScoped(
    _run,
    values: {
      argsProvider.overrideWith(() => args),
      loggerProvider..overrideWith(() => logger),
      fsProvider,
      gitProvider,
      processProvider,
      compilerProvider,
    },
  );
}

Future<int> _run() async {
  final exitCode = await const GitHookRunner().run();

  return exitCode;
}
