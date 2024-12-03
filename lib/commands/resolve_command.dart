import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:glob/glob.dart';
import 'package:mason_logger/mason_logger.dart';

class ResolveCommand extends Command<int> {
  ResolveCommand({
    required this.fs,
    required this.logger,
    required this.git,
  });

  final FileSystem fs;
  final Logger logger;
  final GitService git;

  @override
  String get name => 'resolve';

  @override
  String get description => 'Does something, I dunno';

  @override
  FutureOr<int>? run() async {
    final files = await git.getChangedFiles();

    if (files == null) {
      return 1;
    }

    final resolver = Resolver(
      fs: fs,
      hooks: [
        Hook(
          pathPatterns: [Glob('*.dart')],
          commands: (files) => ['echo "Hello, World!"'],
        ),
        Hook(
          pathPatterns: [Glob('**/application/**')],
          workingDirectory: 'application',
          commands: (files) => ['sip r br b application'],
        ),
      ],
    );

    final resolvedHooks = resolver.resolve(files).toList();

    print(files.length);
    return 0;
  }
}
