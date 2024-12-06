import 'dart:io';

import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

mixin PatchMixin {
  static const _patch = '.git_hooks.patch';

  String get gitDir;
  List<String> get gitDiffArgs;
  Logger get logger;
  FileSystem get fs;

  String get _patchPath {
    return p.join(gitDir, _patch);
  }

  Future<void> patch(
    List<String> files,
  ) async {
    final result = await Process.run(
      'git',
      [
        'diff',
        ...gitDiffArgs,
        '--output',
        _patchPath,
        '--',
        ...files,
      ],
    );

    if (result.exitCode != 0) {
      logger
        ..err('Failed to create patch files')
        ..detail('Error: ${result.stderr}');
      throw Exception('Failed to create path files');
    }
  }

  Future<bool> applyPatch() async {
    final patch = _patchPath;
    final firstTry = await Process.run(
      'git',
      [
        'apply',
        '-v',
        '--whitespace=nowarn',
        '--recount',
        '--unidiff-zero',
        patch,
      ],
    );

    if (firstTry.exitCode == 0) {
      return true;
    }

    // retry with --3way
    final secondTry = await Process.run(
      'git',
      [
        'apply',
        '-v',
        '--whitespace=nowarn',
        '--recount',
        '--unidiff-zero',
        '--3way',
        patch,
      ],
    );

    if (secondTry.exitCode != 0) {
      logger
        ..err('Failed to apply patch')
        ..detail('Error: ${secondTry.stderr}');
    }

    return false;
  }

  Future<void> deletePatch() async {
    final path = _patchPath;

    final file = fs.file(path);

    if (!file.existsSync()) return;

    file.deleteSync();
  }
}
