import 'package:git_hooks/models/hook.dart';

class DebugHook extends Hook {
  DebugHook({
    required super.commands,
    super.diffArgs = const [],
    super.allowEmpty = false,
    super.diffFilters,
    super.backupFiles,
  });
}
