part of '../hook.dart';

/// A hook that runs for Git's `commit-msg` event.
///
/// Git passes the path to the commit message file as `$1`. After
/// `executeHook` binds args, [messageFile] holds that path. Full args and
/// stdin are also available via `hookContext` from
/// `package:hooksman/hooksman.dart`.
///
/// ```dart
/// // hooks/commit_msg.dart
/// import 'package:hooksman/hooksman.dart';
///
/// Hook main() {
///   return CommitMsgHook(
///     tasks: [
///       ShellTask.always(
///         name: 'Ensure message file exists',
///         commands: (_) {
///           final file = hookContext.messageFile ?? '';
///           return ['test -f "$file"'];
///         },
///       ),
///     ],
///   );
/// }
/// ```
///
/// Prefer reading [messageFile] (or `hookContext.messageFile`) from a
/// Dart task when you need the message contents in Dart. This hook always
/// runs even when the working-tree diff is empty.
class CommitMsgHook extends Hook {
  const CommitMsgHook({
    required super.tasks,
    this.messageFile,
    super.diffArgs = const [],
    super.diffFilters = '',
    super.runInParallel,
    super.backup,
  });

  const CommitMsgHook.verbose({
    required super.tasks,
    this.messageFile,
    super.diffArgs = const [],
    super.diffFilters = '',
    super.runInParallel,
    super.backup,
  }) : super.verbose();

  /// Path to the commit message file (`$1` from Git). Bound at runtime.
  final String? messageFile;

  /// Returns a copy with [messageFile] set from hook args.
  CommitMsgHook bindMessageFile(String? path) {
    final resolved = path ?? messageFile;
    if (verbose) {
      return CommitMsgHook.verbose(
        tasks: tasks,
        messageFile: resolved,
        diffArgs: diffArgs,
        diffFilters: diffFilters,
        runInParallel: runInParallel,
      );
    }
    return CommitMsgHook(
      tasks: tasks,
      messageFile: resolved,
      diffArgs: diffArgs,
      diffFilters: diffFilters,
      runInParallel: runInParallel,
    );
  }

  @override
  bool get shouldRunOnEmpty => true;
}
