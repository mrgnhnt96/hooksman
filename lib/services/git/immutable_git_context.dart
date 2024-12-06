import 'package:git_hooks/services/git/git_context.dart';

class ImmutableGitContext implements GitContext {
  const ImmutableGitContext({
    required this.partiallyStagedFiles,
    required this.deletedFiles,
    required this.mergeHead,
    required this.mergeMode,
    required this.mergeMsg,
    required this.stashHash,
    required this.hidePartiallyStaged,
  });

  @override
  final List<String> partiallyStagedFiles;
  @override
  final List<String> deletedFiles;
  @override
  final String? mergeHead;
  @override
  final String? mergeMode;
  @override
  final String? mergeMsg;
  @override
  final String? stashHash;
  @override
  final bool hidePartiallyStaged;

  bool get hasPartiallyStagedFiles => partiallyStagedFiles.isNotEmpty;
}
