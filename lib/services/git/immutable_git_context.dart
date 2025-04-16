import 'package:hooksman/services/git/git_context.dart';

class ImmutableGitContext implements GitContext {
  ImmutableGitContext({
    required this.partiallyStagedFiles,
    required this.deletedFiles,
    required this.nonStagedFiles,
  });

  @override
  final List<String> partiallyStagedFiles;
  @override
  final List<String> nonStagedFiles;
  @override
  final List<String> deletedFiles;

  bool get hasPartiallyStagedFiles => partiallyStagedFiles.isNotEmpty;
}
