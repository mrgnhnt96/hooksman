import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/compiler.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';
import 'package:hooksman/models/args.dart';
import 'package:hooksman/models/compiler.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:hooksman/utils/process/process.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:test/test.dart';

void testScoped(
  String description,
  FutureOr<void> Function() fn, {
  FileSystem Function()? fileSystem,
  Logger Function()? logger,
  Args Function()? args,
  Compiler Function()? compiler,
  GitService Function()? git,
  Process Function()? process,
  Object? skip,
}) {
  test(description, skip: skip, () async {
    final mockLogger = _MockLogger();
    when(() => mockLogger.level).thenReturn(Level.quiet);
    when(() => mockLogger.progress(any())).thenReturn(_MockProgress());

    final testProviders = {
      if (process?.call() case final process?)
        processProvider.overrideWith(() => process)
      else
        processProvider,
      if (git?.call() case final git?)
        gitProvider.overrideWith(() => git)
      else
        gitProvider,
      if (compiler?.call() case final compiler?)
        compilerProvider.overrideWith(() => compiler)
      else
        compilerProvider,
      loggerProvider.overrideWith(() => logger?.call() ?? mockLogger),
      if (args?.call() case final args?)
        argsProvider.overrideWith(() => args)
      else
        argsProvider,
      if (fileSystem?.call() case final FileSystem fs)
        fsProvider.overrideWith(() => fs)
      else
        fsProvider.overrideWith(MemoryFileSystem.test),
    };

    await runScoped(values: testProviders, () async {
      switch (fn) {
        case final Future<void> Function() fn:
          await fn();
        case final void Function() fn:
          fn();
      }
    });
  });
}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}
