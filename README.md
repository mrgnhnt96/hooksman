# Hooksman (Hooks Manager)

[![Pub Version](https://img.shields.io/pub/v/hooksman)](https://pub.dev/packages/hooksman)

[![GitHub stars](https://img.shields.io/github/stars/mrgnhnt96/hooksman?style=social)](https://github.com/mrgnhnt96/hooksman)

![preview](https://raw.githubusercontent.com/mrgnhnt96/hooksman/main/.github/images/preview.gif)

## Overview

The `hooksman` package allows you to manage and execute Git hooks using Dart. You can define your hooks as Dart files and register them with Git to run automatically when the corresponding events occur (e.g., pre-commit, post-commit, etc.). Inspired by [lint-staged](https://npm.im/lint-staged) and [husky](https://npm.im/husky), `hooksman` provides a flexible and powerful way to automate tasks during your workflow and share them across your team.

With `hooksman` you can run shell commands, Dart code, or a combination of both in your hooks to enforce coding standards, run tests, or perform other tasks.

Tasks are used to safeguard your codebase, if a task fails, `hooksman` exits with a non-zero status code, preventing the hook from completing (like a pre-commit hook).

> [!TIP]
>
> Check out [`sip_cli`](https://pub.dev/packages/sip_cli) for a Dart-based CLI tool to manage mono-repos, maintain project scripts, and run `dart|flutter pub get` across multiple packages.

## Installation

Add `hooksman` to your `pubspec.yaml`:

```bash
dart pub add hooksman --dev
```

Then, run `dart pub get` to install the package.

## Development

`nocterm` is a hosted pub.dev dependency. Unpublished siblings (`nocterm_provider`, `nocterm_nested`) are cloned into `gen/` (gitignored), then copied into committed `lib/src/vendor/` for publish:

```sh
sip gen sync   # clone pins → gen/, then vendor into lib/src/vendor/
sip install    # sync + pub get + global activate
```

Add or bump pins in `tool/gen_packages.yaml`, then re-run `sip gen sync` (runs `tool/vendor_from_gen.sh`). Do not commit `gen/`; do commit `lib/src/vendor/`.

### Publishing

`sip publish` refuses `path: gen/` (and other path/git) deps, re-syncs/vendors, tests, lints, then dry-runs and publishes. Hosted `nocterm` must stay compatible with the pin in `tool/gen_packages.yaml`.

## Register Hooks

To register your hooks with Git, run the following command:

```sh
dart run hooksman
# or explicitly:
dart run hooksman register
```

This compiles your Dart hooks into `.dart_tool/hooksman/executables/`, writes thin shims into `hooks/_/`, and sets `core.hooksPath` to `hooks/_` (husky-style). User sources in `hooks/*.dart` and `hooks/*.sh` are never deleted.

Layout after register:

```tree
.
├── hooks
│   ├── pre_commit.dart      # authored source
│   ├── post-commit.sh       # authored source
│   └── _                    # managed shims (gitignored; do not edit)
│       ├── pre-commit
│       └── post-commit
├── .dart_tool/hooksman/executables/   # compiled binaries (local)
└── pubspec.yaml
```

> [!IMPORTANT]
> After cloning a repo, run `dart run hooksman register` so compiled binaries exist. Shims under `hooks/_` invoke `.dart_tool/hooksman/executables/<name>` and forward args/stdin.

> [!NOTE]
> Hooksman no longer writes into or wipes `.git/hooks`. Existing hooks there are left alone; Git uses `hooks/_` via `core.hooksPath`.

### Uninstall

```sh
dart run hooksman uninstall
```

Unsets `core.hooksPath` and removes managed shims under `hooks/_` (keeps `.gitignore` / `README.md`). Authored sources are untouched.

### Skipping hooks

Set `HOOKSMAN=0` (or `SKIP=1` / `SKIP=true`) to no-op hooks early in the shim and in Dart execution:

```sh
HOOKSMAN=0 git commit -m "wip"
```

## Dart Hooks

### Create Hooks Directory

Create a `hooks` directory in the root of your project to store your hooks.

```tree
.
├── hooks
├── lib
│   └── ...
└── pubspec.yaml
```

### Create Hook

Create your hooks as Dart files in the `hooks` directory. Each file should contain a `main` function that returns a `Hook` subtype, imported from the `hooksman` package.

```dart
// hooks/pre_commit.dart

import 'package:hooksman/hooksman.dart';

Hook main() {
    return PreCommitHook(
        ... // Tasks
    );
}
```

The pre-defined hooks are:

- `PreCommitHook`: Runs before a commit is made
- `PrePushHook`: Runs before a push is made
- `CommitMsgHook`: Runs for `commit-msg`; binds `$1` as `messageFile` / `hookContext.messageFile`
- `AnyHook`: A general purpose hook that can be used to create custom hooks

Git hook args and stdin are forwarded into `hookContext` during execution.

```dart
// hooks/commit_msg.dart
import 'package:hooksman/hooksman.dart';

Hook main() {
  return CommitMsgHook(
    tasks: [
      ShellTask.always(
        name: 'Ensure message file exists',
        commands: (_) {
          final file = hookContext.messageFile ?? '';
          return ['test -f "$file"'];
        },
      ),
    ],
  );
}
```

> [!NOTE]
>
> `hooksman` scans the `hooks` directory for top-level Dart/shell files to use as hooks. You can organize your code by placing additional Dart files in subdirectories within the `hooks` directory. These files can be imported into your hook files and will not be picked up by `hooksman` as hooks. The managed `hooks/_` directory is ignored.
>
> ```bash
> .
> └── hooks
>     ├── tasks
>     │   ├── some_dart_task.dart # ignored
>     │   └── ...
>     ├── _                      # managed shims
>     └── pre_commit.dart # picked up
> ```

### Hook Names

The name of the hook is derived from the file name. For example, a file named `pre_commit.dart` will be registered as the `pre-commit` hook. Be sure to follow the naming convention for Git hooks.

> [!TIP]
>
> Look at the git hooks documentation for more information on the available hooks: [Git Hooks Documentation](https://git-scm.com/docs/githooks).

## Shell Hooks

You can create stand alone shell hooks by creating shell files within the hooks directory. These are prepared under `.dart_tool/hooksman/executables/` and invoked via shims in `hooks/_`.

### Create Shell Hook

Create a shell file in the `hooks` directory. The file name should match the name of the Git hook you want to use.

```bash
touch hooks/post-commit.sh
```

> [!IMPORTANT]
>
> The file extension should be `.sh` to be recognized as a shell hook.

### Shell Hook Content

Add the shell commands you want to run in the shell file.

```bash
#!/bin/sh

echo "Running post-commit hook"
```

> [!TIP]
>
> From a shell hook you can invoke another registered hook by name via its shim, e.g. `hooks/_/pre-commit` (or the executable under `.dart_tool/hooksman/executables/`).

## Tasks

Tasks are modular units of work that you define to be executed during specific Git hook events. They allow you to automate checks, validations, or any custom scripts to ensure code quality and consistency across your repository. Tasks are powerful because they can be customized to suit your project's needs while targeting specific file paths or patterns.

All top level tasks are executed in parallel, while tasks within a group are executed sequentially. This allows you to run multiple tasks concurrently and group related tasks together.

### File Patterns

You can specify file patterns to include or exclude from a task using any `Pattern` object (`Glob`, `RegExp`, `String`, etc.). Each task can have multiple include and exclude patterns.

> [!TIP]
>
> `hooksman` exposes the `Glob` class from the [Glob](https://pub.dev/packages/glob) package to match file paths using glob patterns.
>
> `hooksman` also has an `AllFiles` class to match all file paths.

> [!NOTE]
>
> `exclude` filters any matching files before `include` is applied.

After the filters are applied, the remaining files are passed to the task's `commands` or `run` function.

### Task Naming

Each task is assigned a name that is displayed when the task is executed. This is useful for identifying the task in the output. By default, the name of the task is the pattern(s) used to include files. If you would like to provide a custom name, you can do so by setting the `name` property of the task.

```dart
ShellTask(
    name: 'Analyze',
    include: [Glob('**.dart')],
    exclude: [Glob('**.g.dart')],
    commands: (filePaths) => [
        'dart analyze --fatal-infos ${filePaths.join(' ')}',
    ],
),
```

### Shell Task

A `ShellTask` allows you to run shell commands.

```dart
ShellTask(
    name: 'Analyze',
    include: [Glob('**.dart')],
    exclude: [Glob('**.g.dart')],
    commands: (filePaths) => [
        'dart analyze --fatal-infos ${filePaths.join(' ')}',
    ],
),
```

### Dart Task

A `DartTask` allows you to run Dart code.

```dart
DartTask(
    include: [Glob('**.dart')],
    run: (filePaths) async {
        print('Running custom task');

        return 0;
    },
),
```

### Sequential Tasks

You can group tasks together using the `SequentialTasks` class, which runs the tasks sequentially, one after the other.

```dart
SequentialTasks(
    tasks: [
        ShellTask(
            include: [Glob('**.dart')],
            commands: (filePaths) => [
                'dart format ${filePaths.join(' ')}',
            ],
        ),
        ShellTask(
            include: [Glob('**.dart')],
            commands: (filePaths) => [
                'sip test --concurrent --bail',
            ],
        ),
    ],
),
```

### Parallel Tasks

You can group tasks together using the `ParallelTasks` class, which runs the tasks in parallel.

```dart
ParallelTasks(
    tasks: [
        ShellTask(
            include: [Glob('**.dart')],
            commands: (filePaths) => [
                'dart format ${filePaths.join(' ')}',
            ],
        ),
        ShellTask(
            include: [Glob('**.dart')],
            commands: (filePaths) => [
                'sip test --concurrent --bail',
            ],
        ),
    ],
),
```

## Predefined Tasks

### ReRegisterHooks

It can be easy to forget to re-register the hooks with Git after making changes. Re-registering compiles sources into `.dart_tool/hooksman/` and refreshes shims in `hooks/_`.

To automate this process, you can use the `ReRegisterHooks` task. This task will re-register your hooks whenever any authored hook files are created, modified, or deleted (managed `hooks/_` shims are excluded).

```dart
Hook main() {
  return PreCommitHook(
    tasks: [
      ReRegisterHooks(),
    ],
  );
}
```

> [!TIP]
>
> If your `hooks` directory is not found in the root of your project, you can specify the path to the `hooks` directory to the `ReRegisterHooks` task.
>
> ```dart
> ReRegisterHooks(pathToHooksDir: 'path/to/hooks'),
> ```

## Hook Execution

The hooks will be executed automatically by Git when the corresponding events occur (e.g., pre-commit, post-commit, etc.).

### Amending to the Commit (PreCommitHook)

After `hooksman` executes the tasks, a check will be made to see if any files were created/deleted/modified. If so, the files will be added to the commit.

An example of this behavior is when you have a `ShellTask` that formats the code using `dart format`. If the code is not formatted correctly, `hooksman` will format the code and add the changes to the commit.

### Error Handling

If an error occurs during the execution of a task, `hooksman` will stop the execution of the remaining tasks and exit with a non-zero status code. This will prevent the commit from being made, allowing you to fix the issue before committing again.

### Rolling Back a Failed Hook

Tasks edit files in place, so a task that rewrites files — a formatter, a code generator, `dart fix --apply` — leaves those edits behind even when a *later* task fails. Without a rollback, a failed hook can quietly destroy uncommitted work, and the next commit attempt picks up whatever the tasks left in the working tree.

Before the first task runs, `hooksman` snapshots the index and the working tree. If the hook exits for any reason other than success, it restores that snapshot, so a failed hook leaves the repository exactly as it found it. On success the snapshot is discarded and task edits are kept (see [Amending to the Commit](#amending-to-the-commit-precommithook)).

A few details worth knowing:

- **Untracked files are never rolled back.** The snapshot cannot capture them, so removing them would be pure data loss. Files a task creates but does not stage are left in place.
- **The snapshot is kept at `refs/hooksman/backup` until the hook succeeds.** If the hook is killed outright — a second `Ctrl+C`, a closed terminal — it never gets the chance to restore, but the work is still recoverable:

  ```sh
  git stash apply refs/hooksman/backup
  ```

- **Nothing is pushed onto your stash stack.** `git stash list` is untouched.
- **The first commit in a repository is not snapshotted**, since there is no `HEAD` to snapshot against. The hook still runs.

To turn the rollback off for a hook, set `backup` to `false`:

```dart
Hook main() {
  return PreCommitHook(
    backup: false,
    tasks: [...],
  );
}
```

### `Ctrl+C` (Signal Interruption)

If the user interrupts the hook execution (e.g., by pressing `Ctrl+C`), `hooksman` will stop the execution of the remaining tasks and exit with a non-zero status code. The working tree is rolled back to its pre-hook state, as described above.

## Configuration

### Diff Filters

The `diffFilters` parameter allows you to specify the statuses of files to include or exclude, such as `added`, `modified`, or `deleted`.

```dart

Hook main() {
  return PreCommitHook(
    diffFilters: 'AM', // Include added and modified files
    tasks: [
      ...
    ],
  );
}
```

### Diff

The `diff` parameter allows you to specify how files are compared with the working directory, index (staged), or commit.

The example below demonstrates how to compare files with the remote branch (e.g., `origin/main`). This could be useful for a `pre-push` hook.

```dart
Hook main() {
  return PrePushHook(
    // Compare files with the remote branch
    diffArgs: ['@{u}', 'HEAD'], // default args
    tasks: [
      ...
    ],
  );
}
```

## Verbose Output

You can enable verbose output by using the `verbose` constructor on any of the `Hook` classes. This will _slow_ down the execution of the tasks and output detailed information about the tasks being executed. This can be useful to understand the order of execution and the files being processed. This is not intended to be used in non-developing environments.

## Example

```dart
// hooks/pre_push.dart

import 'package:hooksman/hooksman.dart';

Hook main() {
  return PrePushHook.verbose(
    tasks: [
      ReRegisterHooks(),
      ShellTask(
        name: 'Lint & Format',
        include: [Glob('**.dart')],
        exclude: [
          Glob('**.g.dart'),
        ],
        commands: (filePaths) => [
          'dart analyze --fatal-infos ${filePaths.join(' ')}',
          'dart format ${filePaths.join(' ')}',
        ],
      ),
      ShellTask(
        name: 'Build Runner',
        include: [Glob('lib/models/**.dart')],
        exclude: [Glob('**.g.dart')],
        commands: (filePaths) => [
          'sip run build_runner build',
        ],
      ),
      ShellTask(
        name: 'Tests',
        include: [Glob('**.dart')],
        exclude: [Glob('hooks/**')],
        commands: (filePaths) => [
          'sip test --concurrent --bail',
        ],
      ),
    ],
  );
}
```

## License

This project is licensed under the MIT License.
