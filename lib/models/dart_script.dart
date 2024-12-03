import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';
import 'package:glob/glob.dart';

part 'dart_script.g.dart';

class DartScript extends Equatable implements HookCommand {
  const DartScript({
    required this.pathPatterns,
    required this.script,
  });

  final FutureOr<int> Function(Iterable<String> files) script;
  @override
  final List<Glob> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
