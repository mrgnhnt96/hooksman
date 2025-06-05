class ProcessDetails {
  const ProcessDetails({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final Future<int> exitCode;
}

class ProcessDetailsSync {
  const ProcessDetailsSync({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}
