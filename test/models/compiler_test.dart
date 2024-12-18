import 'dart:convert';
import 'dart:io';

import 'package:hooksman/models/compiler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockProcess extends Mock implements Process {
  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    bool includeParentEnvironment,
    bool runInShell,
    Encoding? stderrEncoding,
    Encoding? stdoutEncoding,
    String? workingDirectory,
  });
}

void main() {
  group('Compiler', () {
    late Compiler compiler;
    late MockProcess mockProcess;
    final processResult = ProcessResult(0, 0, '', '');

    setUp(() {
      compiler = const Compiler();
      mockProcess = MockProcess();
      Compiler.ctor = mockProcess.call;
    });

    test('compile should call Process.run with correct arguments', () async {
      when(
        () => mockProcess.call(
          any(),
          any(),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
          stderrEncoding: any(named: 'stderrEncoding'),
          stdoutEncoding: any(named: 'stdoutEncoding'),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer((_) async => processResult);

      final result = await compiler.compile(
        file: 'test.dart',
        outFile: 'test.exe',
      );

      expect(result, processResult);
      verify(
        () => mockProcess.call(
          'dart',
          ['compile', 'exe', 'test.dart', '-o', 'test.exe'],
          includeParentEnvironment: true,
          runInShell: false,
        ),
      ).called(1);
    });

    test(
        'prepareShellExecutable should call Process.run with correct arguments',
        () async {
      when(
        () => mockProcess.call(
          any(),
          any(),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
          stderrEncoding: any(named: 'stderrEncoding'),
          stdoutEncoding: any(named: 'stdoutEncoding'),
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer((_) async => processResult);

      final result = await compiler.prepareShellExecutable('test.exe');

      expect(result, processResult);
      verify(
        () => mockProcess.call(
          'chmod',
          ['+x', 'test.exe'],
          includeParentEnvironment: true,
          runInShell: false,
        ),
      ).called(1);
    });
  });
}
