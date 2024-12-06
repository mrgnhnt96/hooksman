import 'package:git_hooks/services/git/git_context.dart';
import 'package:git_hooks/services/git/immutable_git_context.dart';

class GitContextSetter implements GitContext {
  GitContextSetter();

  @override
  bool hidePartiallyStaged = true;
  @override
  List<String> partiallyStagedFiles = <String>[];
  @override
  List<String> nonStagedFiles = <String>[];
  @override
  List<String> deletedFiles = <String>[];
  @override
  String? mergeHead;
  @override
  String? mergeMode;
  @override
  String? mergeMsg;
  @override
  String? stashHash;

  bool get hasPartiallyStagedFiles => partiallyStagedFiles.isNotEmpty;

  ImmutableGitContext toImmutable() {
    return ImmutableGitContext(
      partiallyStagedFiles: List.unmodifiable(partiallyStagedFiles),
      deletedFiles: List.unmodifiable(deletedFiles),
      mergeHead: mergeHead,
      mergeMode: mergeMode,
      mergeMsg: mergeMsg,
      stashHash: stashHash,
      hidePartiallyStaged: hidePartiallyStaged,
      nonStagedFiles: nonStagedFiles,
    );
  }
}
