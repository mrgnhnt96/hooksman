import 'dart:async';

import 'package:file/memory.dart';
import 'package:file/src/interface/file_system.dart';
import 'package:hooksman/mixins/paths_mixin.dart';
import 'package:mason_logger/src/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  group(PathsMixin, () {
    late FileSystem fs;
    late Logger logger;

    late _TestMixin mixin;

    setUp(() {
      fs = MemoryFileSystem.test();
      logger = _MockLogger();

      mixin = const _TestMixin();
    });

    void test(String description, FutureOr<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        logger: () => logger,
      );
    }

    group('#root', () {
      test('returns null when no pubspec.yaml is found', () {
        expect(mixin.root, isNull);
      });

      test('returns the root directory when pubspec.yaml is found', () {
        final rootDir = fs.directory('/project')..createSync();
        fs.currentDirectory = rootDir;
        rootDir.childFile('pubspec.yaml').createSync();

        expect(mixin.root, equals('/project'));
      });

      test(
          'returns the root directory when pubspec.yaml '
          'is found in a parent directory', () {
        final rootDir = fs.directory('/project')..createSync();
        final subDir = rootDir.childDirectory('subdir')..createSync();
        fs.currentDirectory = subDir;
        rootDir.childFile('pubspec.yaml').createSync();

        expect(mixin.root, equals('/project'));
      });

      test(
          'returns null when pubspec.yaml is not found in any parent directory',
          () {
        final rootDir = fs.directory('/project')..createSync();
        final subDir = rootDir.childDirectory('subdir')..createSync();
        fs.currentDirectory = subDir;

        expect(mixin.root, isNull);
      });
    });

    group('#gitDir', () {
      test('returns null when root is null', () {
        expect(mixin.gitDir, isNull);
      });

      test('returns null when .git directory is not found', () {
        final rootDir = fs.directory('/project')..createSync();
        fs.currentDirectory = rootDir;
        rootDir.childFile('pubspec.yaml').createSync();

        expect(mixin.gitDir, isNull);
      });

      test('returns the .git directory when found', () {
        final rootDir = fs.directory('/project')..createSync();
        fs.currentDirectory = rootDir;
        rootDir.childFile('pubspec.yaml').createSync();
        rootDir.childDirectory('.git').createSync();

        expect(mixin.gitDir, equals('/project/.git'));
      });

      test('returns the .git directory when found in a parent directory', () {
        final rootDir = fs.directory('/project')..createSync();
        final subDir = rootDir.childDirectory('subdir')..createSync();
        fs.currentDirectory = subDir;
        rootDir.childFile('pubspec.yaml').createSync();
        rootDir.childDirectory('.git').createSync();

        expect(mixin.gitDir, equals('/project/.git'));
      });

      test(
          'returns null when .git directory is not '
          'found in any parent directory', () {
        final rootDir = fs.directory('/project')..createSync();
        final subDir = rootDir.childDirectory('subdir')..createSync();
        fs.currentDirectory = subDir;
        rootDir.childFile('pubspec.yaml').createSync();

        expect(mixin.gitDir, isNull);
      });
    });

    group('#gitHooksDir', () {
      test('returns null when gitDir is null', () {
        expect(mixin.gitHooksDir, isNull);
      });

      test('returns the hooks directory when .git directory is found', () {
        final rootDir = fs.directory('/project')..createSync();
        fs.currentDirectory = rootDir;
        rootDir.childFile('pubspec.yaml').createSync();
        rootDir.childDirectory('.git').createSync();

        expect(mixin.gitHooksDir, equals('/project/.git/hooks'));
      });

      test(
          'returns the hooks directory when .git directory is '
          'found in a parent directory', () {
        final rootDir = fs.directory('/project')..createSync();
        final subDir = rootDir.childDirectory('subdir')..createSync();
        fs.currentDirectory = subDir;
        rootDir.childFile('pubspec.yaml').createSync();
        rootDir.childDirectory('.git').createSync();

        expect(mixin.gitHooksDir, equals('/project/.git/hooks'));
      });

      test(
          'returns null when .git directory is not '
          'found in any parent directory', () {
        final rootDir = fs.directory('/project')..createSync();
        final subDir = rootDir.childDirectory('subdir')..createSync();
        fs.currentDirectory = subDir;
        rootDir.childFile('pubspec.yaml').createSync();

        expect(mixin.gitHooksDir, isNull);
      });
    });
  });
}

class _TestMixin with PathsMixin {
  const _TestMixin();
}

class _MockLogger extends Mock implements Logger {}
