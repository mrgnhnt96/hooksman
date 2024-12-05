import 'dart:async';

import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'dart_script.g.dart';

final class DartScript extends HookCommand {
  const DartScript({
    required super.pathPatterns,
    required this.script,
    super.excludePatterns,
    super.name,
  });

  DartScript.always({
    required this.script,
    super.name,
  }) : super(pathPatterns: [AllFiles()]);

  final FutureOr<int> Function(Iterable<String> files) script;

  @override
  List<Object?> get props => _$props;
}
