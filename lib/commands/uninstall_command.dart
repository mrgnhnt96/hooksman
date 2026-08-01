import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/mixins/paths_mixin.dart';
import 'package:mason_logger/mason_logger.dart';

const _usage = '''
Usage: hooksman uninstall

Uninstall hooksman-managed Git hooks

Unsets core.hooksPath and removes generated shims under hooks/_.
User sources in hooks/*.dart and hooks/*.sh are left untouched.
''';

class UninstallCommand with PathsMixin {
  const UninstallCommand();

  Future<int> run() async {
    if (args['help'] case true) {
      logger.write(_usage);
      return 0;
    }

    try {
      final success = await git.unsetHooksDir();
      if (!success) {
        return 1;
      }
    } catch (e) {
      logger
        ..err('Could not unset hooks path')
        ..detail(e.toString());
      return 1;
    }

    final hooksPath = managedHooksDir;
    if (hooksPath != null) {
      final hooksDir = fs.directory(hooksPath);
      if (hooksDir.existsSync()) {
        for (final entity in hooksDir.listSync()) {
          final name = fs.path.basename(entity.path);
          if (name == '.gitignore' || name == 'README.md') continue;
          entity.deleteSync(recursive: true);
        }
        logger.info(darkGray.wrap('Removed managed shims from hooks/_'));
      }
    }

    logger.info(green.wrap('Uninstalled hooksman hooks'));
    return 0;
  }
}
