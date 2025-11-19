import 'dart:async';

class ProcessDetails {
  const ProcessDetails({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final FutureOr<String> stdout;
  final FutureOr<String> stderr;
  final FutureOr<int> exitCode;
}
