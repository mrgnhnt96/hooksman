import 'package:hooksman/services/git/git_context.dart';

class GitContextSetter implements GitContext {
  GitContextSetter();

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
}
