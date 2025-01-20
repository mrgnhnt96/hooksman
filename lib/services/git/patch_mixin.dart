import 'dart:io';

import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

mixin PatchMixin {
  static const _patch = 'hooksman.patch';

  String get gitDir;
  List<String> get gitDiffArgs;
  Logger get logger;
  FileSystem get fs;

  String get patchPath {
    return p.join(gitDir, _patch);
  }

  Future<void> patch(
    List<String> filePaths,
  ) async {
    final result = await Process.run(
      'git',
      [
        'diff',
        ...gitDiffArgs,
        '--output',
        patchPath,
        '--',
        ...filePaths,
      ],
    );

    if (result.exitCode != 0) {
      logger
        ..err('Failed to create patch files')
        ..detail('Error: ${result.stderr}')
        ..detail('Files (${filePaths.length})');
      for (final file in filePaths) {
        logger.detail('  - $file');
      }
      throw Exception('Failed to create path files');
    }

    logger.detail('Create patch output: ${result.stdout}');

    // ensure file exists
    if (!fs.file(patchPath).existsSync()) {
      logger
        ..err('Failed to create patch')
        ..detail('Output: ${result.stdout}');
      throw Exception('Failed to create patch');
    }
  }

  Future<bool> applyPatch() async {
    final patch = patchPath;
    logger.detail('Applying patch from $patch');
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

    logger
      ..detail('First patch try failed')
      ..detail('Error: ${firstTry.stderr}');

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
    final path = patchPath;

    final file = fs.file(path);

    if (!file.existsSync()) {
      logger.detail('no patch file to delete');
      return;
    }

    logger.detail('deleting patch file');
    file.deleteSync();
  }

  Future<bool> patchAvailable() async {
    final path = patchPath;

    final file = fs.file(path);

    return file.exists();
  }
}
