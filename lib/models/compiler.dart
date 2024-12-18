import 'dart:convert';
import 'dart:io';

class Compiler {
  const Compiler();

  static Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    bool includeParentEnvironment,
    bool runInShell,
    Encoding? stderrEncoding,
    Encoding? stdoutEncoding,
    String? workingDirectory,
  }) ctor = Process.run;

  Future<ProcessResult> compile({
    required String file,
    required String outFile,
  }) async {
    final process = ctor(
      'dart',
      [
        'compile',
        'exe',
        file,
        '-o',
        outFile,
      ],
      includeParentEnvironment: true,
      runInShell: false,
    );

    return process;
  }

  Future<ProcessResult> prepareShellExecutable(String file) async {
    final process = ctor(
      'chmod',
      ['+x', file],
      includeParentEnvironment: true,
      runInShell: false,
    );

    return process;
  }
}
