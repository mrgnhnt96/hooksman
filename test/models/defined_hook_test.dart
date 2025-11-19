import 'dart:async';

import 'package:hooksman/models/defined_hook.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  group(DefinedHook, () {
    void test(String description, FutureOr<void> Function() fn) {
      testScoped(description, fn);
    }

    group('#isDart', () {
      test('returns true for Dart files', () {
        const hook = DefinedHook('/path/to/file.dart');
        expect(hook.isDart, isTrue);
      });

      test('returns false for non-Dart files', () {
        const hook = DefinedHook('/path/to/file.txt');
        expect(hook.isDart, isFalse);
      });
    });

    group('#isShell', () {
      test('returns true for Shell script files', () {
        const hook = DefinedHook('/path/to/script.sh');
        expect(hook.isShell, isTrue);
      });

      test('returns false for non-Shell script files', () {
        const hook = DefinedHook('/path/to/file.txt');
        expect(hook.isShell, isFalse);
      });
    });

    test('#name returns the file name without extension in param case', () {
      const hook = DefinedHook('/path/to/MyFile.dart');
      expect(hook.name, 'my-file');
    });

    test('#fileName returns the full file name with extension', () {
      const hook = DefinedHook('/path/to/MyFile.dart');
      expect(hook.fileName, 'MyFile.dart');
    });
  });
}
