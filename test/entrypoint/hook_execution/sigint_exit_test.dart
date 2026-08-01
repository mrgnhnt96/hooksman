import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Spawns [tool/sigint_full_probe.dart], sends SIGINT, expects exit 1.
///
/// Guards the nocterm migration regression where StdioBackend's unhandled
/// Ctrl+C called requestExit(0) and raced PendingHook's kill path.
void main() {
  test(
    'SIGINT during runApp exits 1 without hanging',
    () async {
      final proc = await Process.start(Platform.resolvedExecutable, [
        'run',
        'tool/sigint_full_probe.dart',
      ], workingDirectory: Directory.current.path);

      final ready = Completer<void>();
      final err = StringBuffer();
      proc.stderr.transform(utf8.decoder).listen((chunk) {
        err.write(chunk);
        if (chunk.contains('ready') && !ready.isCompleted) {
          ready.complete();
        }
      });
      // Drain stdout so the TUI cannot fill the pipe and stall.
      unawaited(proc.stdout.drain<void>());

      await ready.future.timeout(const Duration(seconds: 45));
      await Future<void>.delayed(const Duration(milliseconds: 800));

      expect(proc.kill(ProcessSignal.sigint), isTrue);

      final code = await proc.exitCode.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          proc.kill(ProcessSignal.sigkill);
          fail('SIGINT probe hung; stderr:\n$err');
        },
      );

      expect(err.toString(), contains('wasKilled'));
      expect(code, 1, reason: 'stderr:\n$err');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
