/// Runtime context for a Git hook invocation (args + stdin).
class HookContext {
  const HookContext({required this.args, this.stdin = '', this.messageFile});

  /// Positional arguments Git passed to the hook (`$1`, `$2`, …).
  final List<String> args;

  /// Stdin contents Git piped to the hook (e.g. refs for `pre-push`).
  final String stdin;

  /// Convenience for `commit-msg` / `prepare-commit-msg`: path from `$1`.
  final String? messageFile;

  static const empty = HookContext(args: []);
}
