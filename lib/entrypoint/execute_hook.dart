import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/compiler.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/hook_context.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';
import 'package:hooksman/deps/stdout.dart';
import 'package:hooksman/entrypoint/hook_execution/hook_executor.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/models/args.dart';
import 'package:hooksman/models/hook_context.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';

/// Whether hooksman should no-op based on environment variables.
///
/// - `HOOKSMAN=0` → skip
/// - `SKIP=1` or `SKIP=true` → skip
bool shouldSkipHooks([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  if (env['HOOKSMAN'] == '0') return true;
  final skip = env['SKIP'];
  return skip == '1' || skip == 'true';
}

Future<String> _readStdin() async {
  try {
    if (stdin.hasTerminal) return '';
    return await utf8.decoder.bind(stdin).join();
  } catch (_) {
    return '';
  }
}

String normalizeHookName(String name) => name.replaceAll('_', '-');

/// Binds Git hook args into remote / message-file fields and a [HookContext].
({
  String? remoteName,
  String? remoteUrl,
  String? messageFile,
  Hook boundHook,
  HookContext context,
})
bindHookInvocation({
  required String name,
  required Hook hook,
  required List<String> args,
  String stdinContent = '',
}) {
  final normalized = normalizeHookName(name);

  String? remoteName;
  String? remoteUrl;
  String? messageFile;

  // pre-push: Git passes <remote-name> <remote-url>
  if (normalized == 'pre-push' && args.length >= 2) {
    remoteName = args[0];
    remoteUrl = args[1];
  } else if (args case [
    final String remote,
    final String url,
  ] when hook is PrePushHook) {
    remoteName = remote;
    remoteUrl = url;
  }

  // commit-msg / prepare-commit-msg: $1 is the message file path
  if (args.isNotEmpty &&
      (hook is CommitMsgHook ||
          normalized == 'commit-msg' ||
          normalized == 'prepare-commit-msg')) {
    messageFile = args.first;
  }

  final boundHook = switch (hook) {
    final CommitMsgHook commitMsg => commitMsg.bindMessageFile(messageFile),
    _ => hook,
  };

  final context = HookContext(
    args: List.unmodifiable(args),
    stdin: stdinContent,
    messageFile:
        messageFile ??
        (boundHook is CommitMsgHook ? boundHook.messageFile : null),
  );

  return (
    remoteName: remoteName,
    remoteUrl: remoteUrl,
    messageFile: messageFile,
    boundHook: boundHook,
    context: context,
  );
}

Future<void> executeHook(String name, Hook hook, List<String> args) async {
  if (shouldSkipHooks()) {
    exit(0);
  }

  final stdinContent = await _readStdin();
  final bound = bindHookInvocation(
    name: name,
    hook: hook,
    args: args,
    stdinContent: stdinContent,
  );
  final remoteName = bound.remoteName;
  final remoteUrl = bound.remoteUrl;
  final boundHook = bound.boundHook;
  final context = bound.context;

  final logger = Logger();
  if (boundHook.verbose) {
    logger.level = Level.verbose;
  } else {
    logger.level = Level.error;
  }

  return runScoped(
    () => _run(name, boundHook),
    values: {
      argsProvider.overrideWith(
        () => Args(
          args: {'loud': boundHook.verbose, 'quiet': !boundHook.verbose},
        ),
      ),
      loggerProvider.overrideWith(() => logger),
      gitProvider.overrideWith(
        () => GitService(remoteName: remoteName, remoteUrl: remoteUrl),
      ),
      hookContextProvider.overrideWith(() => context),
      fsProvider,
      processProvider,
      compilerProvider,
      stdoutProvider,
    },
  );
}

Future<int> _run(String name, Hook hook) async {
  try {
    final executor = HookExecutor(hook, hookName: name);

    final canRun = await executor.runChecks();

    if (!canRun) {
      exitCode = 1;
    } else {
      exitCode = await executor.run();
    }
  } catch (e, stack) {
    logger
      ..err('Error running hook')
      ..detail('Error: $e')
      ..detail('Stack:\n$stack');
    exitCode = 1;
  }

  exit(exitCode);
}
