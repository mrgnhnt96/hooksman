import 'package:hooksman/services/git/git_context.dart';

class GitContextSetter implements GitContext {
  GitContextSetter();

  @override
  List<String> partiallyStagedFiles = <String>[];
  @override
  List<String> nonStagedFiles = <String>[];
  @override
  List<String> deletedFiles = <String>[];

  bool get hasPartiallyStagedFiles => partiallyStagedFiles.isNotEmpty;
}
