import 'package:hooksman/hooks/hook.dart';

class VerboseHook extends Hook {
  VerboseHook({
    required super.tasks,
    super.diffArgs = const [],
    super.allowEmpty = false,
    super.diffFilters,
    super.backupFiles,
  });
}
