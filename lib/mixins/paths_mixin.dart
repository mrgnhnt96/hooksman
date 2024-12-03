import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

mixin PathsMixin {
  FileSystem get fs;
  Logger get logger;

  String? get root {
    var directory = fs.currentDirectory.absolute;

    while (directory.path != p.separator) {
      final file = directory.childFile('pubspec.yaml');

      if (file.existsSync()) {
        return directory.path;
      }

      directory = directory.parent;
    }

    return null;
  }

  String? get gitDir {
    final root = this.root;

    if (root == null) {
      logger.err('Could not find root directory');
      return null;
    }

    var gitDir = fs.directory(p.join(root, '.git'));

    while (!gitDir.childDirectory('.git').existsSync()) {
      final parent = gitDir.parent;

      if (parent.path == gitDir.path) {
        logger.err('Could not find .git directory');
        return null;
      }

      gitDir = parent;
    }

    return gitDir.childDirectory('.git').path;
  }

  String? get hooksDir {
    final gitDir = this.gitDir;

    if (gitDir == null) {
      logger.err('Could not find .git directory');
      return null;
    }

    return fs.directory(p.join(gitDir, 'hooks')).path;
  }
}
