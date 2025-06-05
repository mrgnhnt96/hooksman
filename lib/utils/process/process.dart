import 'dart:io' as io;

import 'package:hooksman/utils/process/process_details.dart';

class Process {
  const Process();

  Future<ProcessDetails> start(
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

    return ProcessDetails(
      stdout: process.stdout,
      stderr: process.stderr,
      exitCode: process.exitCode,
    );
  }

  Future<ProcessDetailsSync> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) async {
    final process = await io.Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );

    return ProcessDetailsSync(
      stdout: process.stdout.toString(),
      stderr: process.stderr.toString(),
      exitCode: process.exitCode,
    );
  }

  ProcessDetailsSync sync(
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

    return ProcessDetailsSync(
      stdout: process.stdout.toString(),
      stderr: process.stderr.toString(),
      exitCode: process.exitCode,
    );
  }
}
