part of '../hook.dart';

/// The `VerboseHook` class extends the `Hook` class to provide verbose output
/// during the execution of tasks. This class is useful for
/// understanding the order of execution and the files being processed.
///
/// ## Usage
///
/// To use the `VerboseHook`, instantiate it with the desired tasks:
///
/// ```dart
/// import 'package:hooksman/hooksman.dart';
///
/// VerboseHook main() {
///   return VerboseHook(
///     tasks: [
///       ReRegisterHooks(),
///       ShellTask(
///         name: 'Lint & Format',
///         include: [Glob('**.dart')],
///         exclude: [Glob('**.g.dart')],
///         commands: (filePaths) => [
///           'dart analyze --fatal-infos ${filePaths.join(' ')}',
///           'dart format ${filePaths.join(' ')}',
///         ],
///       ),
///       ShellTask(
///         name: 'Build Runner',
///         include: [Glob('lib/models/**.dart')],
///         exclude: [Glob('**.g.dart')],
///         commands: (filePaths) => [
///           'sip run build_runner build',
///         ],
///       ),
///       ShellTask(
///         name: 'Tests',
///         include: [Glob('**.dart')],
///         exclude: [Glob('hooks/**')],
///         commands: (filePaths) => [
///           'sip test --concurrent --bail',
///         ],
///       ),
///     ],
///   );
/// }
/// ```
///
/// This will enable verbose output, providing detailed information about the
/// tasks being executed. Note that this will slow down the execution of the
/// tasks and is not intended for use in production environments.
class VerboseHook extends Hook {
  const VerboseHook({
    required super.tasks,
    super.diffArgs = const [],
    super.diffFilters = '',
  });
}
