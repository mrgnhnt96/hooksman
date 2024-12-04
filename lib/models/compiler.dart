import 'dart:io';

class Compiler {
  const Compiler();

  Future<ProcessResult> compile({
    required String file,
    required String outFile,
  }) async {
    final process = Process.run('dart', [
      'compile',
      'exe',
      file,
      '-o',
      outFile,
    ]);

    return process;
  }
}
