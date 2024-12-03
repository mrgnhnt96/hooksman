import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'dart_script.g.dart';

class DartScript extends Equatable implements HookCommand {
  const DartScript({
    required this.pathPatterns,
    required this.script,
  });

  DartScript.always({
    required this.script,
  }) : pathPatterns = [AllFiles()];

  final FutureOr<int> Function(Iterable<String> files) script;
  @override
  final List<Pattern> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
