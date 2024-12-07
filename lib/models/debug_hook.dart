import 'package:hooksman/models/hook.dart';

class DebugHook extends Hook {
  DebugHook({
    required super.tasks,
    super.diffArgs = const [],
    super.allowEmpty = false,
    super.diffFilters,
    super.backupFiles,
  });
}
