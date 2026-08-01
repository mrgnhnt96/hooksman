import 'package:file/file.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/logger.dart';

mixin PathsMixin {
  String? get root {
    var directory = fs.currentDirectory.absolute;

    while (true) {
      final file = directory.childFile('pubspec.yaml');

      if (file.existsSync()) {
        return directory.path;
      }

      final parent = directory.parent;
      // Drive roots (e.g. `C:\`) have parent.path == path; stop there.
      // Comparing only to path.separator misses Windows drive roots.
      if (parent.path == directory.path) {
        return null;
      }

      directory = parent;
    }
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

  /// Managed shim directory Git runs via `core.hooksPath` (`hooks/_`).
  ///
  /// User-authored sources live in `hooks/*.dart` / `hooks/*.sh`; this
  /// directory only holds generated shims.
  String? get managedHooksDir {
    final root = this.root;

    if (root == null) {
      logger.err('Could not find root directory');
      return null;
    }

    return fs.directory(fs.path.join(root, 'hooks', '_')).path;
  }

  /// Alias for [managedHooksDir] (kept for existing call sites / tests).
  String? get gitHooksDir => managedHooksDir;

  Directory dartToolGitHooksDir(String root) {
    return fs.directory(fs.path.join(root, '.dart_tool', 'hooksman'));
  }

  Directory executablesDir(String root) {
    return fs.directory(
      fs.path.join(dartToolGitHooksDir(root).path, 'executables'),
    );
  }
}
