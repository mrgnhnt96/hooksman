import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/models/compiler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

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
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
      compiler = const Compiler();
      mockProcess = MockProcess();
      Compiler.ctor = mockProcess.call;
    });

    void stub() {
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
    }

    void test(String description, FutureOr<void> Function() fn) {
      testScoped(description, fn, fileSystem: () => fs);
    }

    test('compile should call Process.run with correct arguments', () async {
      stub();

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
      return;
    });

    group('#prepareShellExecutable', () {
      test('should call Process.run with correct arguments', () async {
        fs.file('test.exe').createSync();

        stub();

        final result = await compiler.prepareShellExecutable(
          file: 'test.exe',
          outFile: 'test',
        );

        expect(result, processResult);
        verify(
          () => mockProcess.call(
            'chmod',
            ['+x', 'test'],
            includeParentEnvironment: true,
            runInShell: false,
          ),
        ).called(1);
        return;
      });

      test('should create out file when it does not exist', () async {
        final file = fs.file('test');
        stub();

        expect(file.existsSync(), isFalse);

        await compiler.prepareShellExecutable(file: 'test', outFile: 'test');

        expect(file.existsSync(), isTrue);
        return;
      });

      test('should copy the contents to out file', () async {
        final file = fs.file('test')..writeAsStringSync('test');
        stub();

        const outFile = 'test.out';
        final out = fs.file(outFile);

        expect(out.existsSync(), isFalse);

        await compiler.prepareShellExecutable(file: 'test', outFile: outFile);

        expect(out.readAsStringSync(), file.readAsStringSync());
        return;
      });
    });
  });
}
