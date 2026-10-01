import 'dart:io';

import 'package:hooksman/entrypoint/hook_execution/hook_executor.dart';
import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/tasks/dart_task.dart';
import 'package:hooksman/utils/all_files.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

/// What a task prints is queued while the TUI is up and replayed afterwards.
/// A non-verbose hook logs at [Level.error]; the replay must not be filtered
/// by it, or a failing task aborts the commit with no explanation.
void main() {
  group('task output', () {
    late _CapturingStdout out;
    late Logger logger;

    setUp(() {
      out = _CapturingStdout();
      logger = Logger(level: Level.error);
    });

    Hook hookThatPrints() => PrePushHook(
      tasks: [
        DartTask(
          name: 'explain',
          include: [AllFiles()],
          run: (_) {
            // A DartTask has no print callback, so this goes through the zone.
            // ignore: avoid_print
            print('This push is blocked because of a zone print');
            return 1;
          },
        ),
      ],
    );

    Future<void> runAndFlush() =>
        IOOverrides.runZoned(stdout: () => out, () async {
          final hook = hookThatPrints();
          final pendingHook = PendingHook(
            hook.resolve(['a.dart']),
            logger: logger,
          );

          await pendingHook.start();
          await pendingHook.wait();

          HookExecutor(hook, hookName: 'pre-push').flushTaskOutput();
        });

    testScoped('reaches stdout when the hook is not verbose', () async {
      await runAndFlush();

      expect(
        out.written.toString(),
        contains('This push is blocked because of a zone print\n'),
      );
    }, logger: () => logger);

    testScoped('reaches stdout when the hook is verbose', () async {
      logger.level = Level.verbose;

      await runAndFlush();

      expect(
        out.written.toString(),
        contains('This push is blocked because of a zone print\n'),
      );
    }, logger: () => logger);
  });
}

class _CapturingStdout implements Stdout {
  final written = StringBuffer();

  @override
  void write(Object? object) => written.write(object);

  @override
  void writeln([Object? object = '']) => written.writeln(object);

  @override
  bool get hasTerminal => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
