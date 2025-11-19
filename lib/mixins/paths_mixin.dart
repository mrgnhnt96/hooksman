import 'package:file/file.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/logger.dart';

mixin PathsMixin {
  String? get root {
    var directory = fs.currentDirectory.absolute;

    while (directory.path != fs.path.separator) {
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

    var gitDir = fs.directory(fs.path.join(root, '.git'));

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

  String? get gitHooksDir {
    final gitDir = this.gitDir;

    if (gitDir == null) {
      logger.err('Could not find .git directory');
      return null;
    }

    return fs.directory(fs.path.join(gitDir, 'hooks')).path;
  }

  Directory dartToolGitHooksDir(String root) {
    return fs.directory(fs.path.join(root, '.dart_tool', 'hooksman'));
  }

  Directory executablesDir(String root) {
    return fs
        .directory(fs.path.join(dartToolGitHooksDir(root).path, 'executables'));
  }
}
