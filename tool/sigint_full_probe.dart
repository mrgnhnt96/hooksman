import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:hooksman/app/data/steps.dart';
import 'package:hooksman/app/hooksman_app.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';
import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:hooksman/hooksman.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:nocterm/nocterm.dart' hide Logger;
import 'package:scoped_deps/scoped_deps.dart';

/// Full HookExecutor-like path: runApp + PendingHook + long sleep.
Future<void> main() async {
  await runScoped(
    () async {
      // Signal readiness before TUI takes over stderr/stdout.
      stderr.writeln('full-probe: pid=$pid ready');

      final hook = PreCommitHook(
        tasks: [
          ShellTask(
            name: 'Long sleep',
            include: [AllFiles()],
            commands: (_) => ['sleep 30'],
          ),
        ],
      );

      final pendingHook = PendingHook(
        hook.resolve(['lib/hooksman.dart']),
        logger: logger,
      );
      final steps = Steps();

      final runner = CancelableOperation.fromFuture(
        runApp(
          HooksmanApp(
            pendingHook: pendingHook,
            nameOfHook: 'pre-commit',
            debug: false,
            steps: steps,
          ),
          enableHotReload: false,
        ),
      );

      steps.current = Step.running;
      unawaited(pendingHook.start());
      await pendingHook.wait();

      final failed = pendingHook.topLevelTasks.any((task) {
        final code = task.code;
        return code != null && code != 0;
      });

      if (pendingHook.wasKilled) {
        steps.current = Step.quit;
        stderr.writeln('full-probe: wasKilled');
      } else if (failed) {
        steps.current = Step.error;
        stderr.writeln('full-probe: failed');
      } else {
        steps.current = Step.complete;
        stderr.writeln('full-probe: complete');
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
      await runner.cancel();

      final code = pendingHook.wasKilled || failed ? 1 : 0;
      stderr.writeln('full-probe: exit=$code');
      exit(code);
    },
    values: {
      loggerProvider.overrideWith(() => Logger(level: Level.quiet)),
      fsProvider,
      processProvider,
    },
  );
}
