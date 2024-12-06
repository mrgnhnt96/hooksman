abstract interface class GitContext {
  const GitContext();

  bool get hidePartiallyStaged;
  List<String> get nonStagedFiles;
  List<String> get partiallyStagedFiles;
  List<String> get deletedFiles;
  String? get mergeHead;
  String? get mergeMode;
  String? get mergeMsg;
  String? get stashHash;
}
