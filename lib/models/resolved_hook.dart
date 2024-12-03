import 'package:equatable/equatable.dart';

part 'resolved_hook.g.dart';

class ResolvedHook extends Equatable {
  const ResolvedHook({
    required this.commands,
    required this.workingDirectory,
  });

  final List<String> commands;
  final String workingDirectory;

  @override
  List<Object?> get props => _$props;
}
