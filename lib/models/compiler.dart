import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';

class Compiler {
  const Compiler({
    required this.fs,
  });

  final FileSystem fs;

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

  Future<ProcessResult> prepareShellExecutable({
    required String file,
    required String outFile,
  }) async {
    if (fs.file(outFile) case final file when !file.existsSync()) {
      file.createSync(recursive: true);
    }

    await fs.file(file).copy(outFile);

    final process = ctor(
      'chmod',
      ['+x', outFile],
      includeParentEnvironment: true,
      runInShell: false,
    );

    return process;
  }
}
