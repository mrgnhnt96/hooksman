import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';

part 'hook.g.dart';

class Hook extends Equatable {
  const Hook({
    required this.pathPatterns,
    required this.commands,
    this.workingDirectory,
  });

  final List<Glob> pathPatterns;
  final List<String> Function(Iterable<String> files) commands;

  /// defaults to the current working directory
  final String? workingDirectory;

  @override
  List<Object?> get props => _$props;
}
