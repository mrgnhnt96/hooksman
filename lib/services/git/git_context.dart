abstract interface class GitContext {
  const GitContext();

  List<String> get nonStagedFiles;
  List<String> get partiallyStagedFiles;
  List<String> get deletedFiles;
}
