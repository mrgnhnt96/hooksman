import 'dart:async';
import 'dart:io';

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

/// Captures nocterm frames of the hooksman TUI for a fake hook run.
Future<void> main() async {
  await runScoped(
    () async {
      final hook = PreCommitHook(
        tasks: [
          ShellTask(
            name: 'Lint & Format',
            include: [AllFiles()],
            commands: (_) => ['sleep 0.4'],
          ),
          ParallelTasks(
            name: 'Checks',
            tasks: [
              ShellTask(
                name: 'Analyze',
                include: [AllFiles()],
                commands: (_) => ['sleep 0.6'],
              ),
              SequentialTasks(
                name: 'Format & Test',
                tasks: [
                  ShellTask(
                    name: 'Format',
                    include: [AllFiles()],
                    commands: (_) => ['sleep 0.3'],
                  ),
                  ShellTask(
                    name: 'Tests',
                    include: [AllFiles()],
                    commands: (_) => ['sleep 0.5'],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final pendingHook = PendingHook(
        hook.resolve(['lib/hooksman.dart', 'lib/app/hooksman_app.dart']),
        logger: logger,
      );
      final steps = Steps();

      final tester = await NoctermTester.create(size: const Size(72, 16));

      await tester.pumpComponent(
        HooksmanApp(
          pendingHook: pendingHook,
          nameOfHook: 'pre-commit',
          debug: false,
          steps: steps,
        ),
      );

      void dump(String label) {
        stdout
          ..writeln('\n══ $label ══')
          ..writeln(tester.renderToString());
      }

      dump('start (preparing)');

      steps.current = Step.running;
      await tester.pump();
      dump('running (pending)');

      unawaited(pendingHook.start());

      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 80));
        if (i == 2 || i == 5) {
          dump('running (t=${(i + 1) * 120}ms)');
        }
      }

      await pendingHook.wait();
      steps.current = Step.complete;
      await tester.pump();
      dump('complete');

      tester.dispose();
      exit(0);
    },
    values: {
      loggerProvider.overrideWith(() => Logger(level: Level.quiet)),
      fsProvider,
      processProvider,
    },
  );
}
