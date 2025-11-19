import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:hooksman/models/process_details.dart';

class Process {
  const Process();

  Future<ProcessDetails> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    io.ProcessStartMode mode = io.ProcessStartMode.normal,
  }) async {
    final process = await io.Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );

    final stdoutController = StreamController<List<int>>.broadcast();
    final stderrController = StreamController<List<int>>.broadcast();

    try {
      process.stdout.listen(stdoutController.add);
    } catch (_) {}

    try {
      process.stderr.listen(stderrController.add);
    } catch (_) {}

    Stream<String> stdout() async* {
      try {
        yield* stdoutController.stream.transform(utf8.decoder);
      } catch (_) {
        // ignore
      }
    }

    Stream<String> stderr() async* {
      try {
        yield* stderrController.stream.transform(utf8.decoder);
      } catch (_) {
        // ignore
      }
    }

    return ProcessDetails(
      stdout: stdout().join(),
      stderr: stderr().join(),
      exitCode: process.exitCode,
    );
  }

  Future<ProcessDetails> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    final result = await io.Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );

    return ProcessDetails(
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
      exitCode: result.exitCode,
    );
  }

  ProcessDetails sync(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) {
    final process = io.Process.runSync(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );

    return ProcessDetails(
      stdout: process.stdout.toString(),
      stderr: process.stderr.toString(),
      exitCode: process.exitCode,
    );
  }
}
