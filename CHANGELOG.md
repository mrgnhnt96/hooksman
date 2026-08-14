<!--  -->

# Unreleased

## Features

- Snapshot the index and working tree before tasks run and roll back to it when a hook does not succeed, so a failed hook cannot leave behind partial task edits or destroy uncommitted work. Opt out per hook with `backup: false`
- Keep the snapshot at `refs/hooksman/backup` until the hook succeeds, so work is recoverable by hand if the hook is killed before it can restore
- Add `GitService.workingDirectory` to run `git` somewhere other than the process working directory

# 3.2.0 | 7.31.26

## Features

- Migrate hook progress UI to nocterm TUI
- Add husky-style `hooks/_` path, `uninstall`, and `CommitMsgHook`
- Depend on hosted `nocterm`; vendor unpublished `nocterm_provider` / `nocterm_nested` under `lib/src/vendor/` for pub.dev publish

## Fixes

- Exit cleanly on Ctrl-C during nocterm UI
- Skip chmod and use cmd on Windows
- Restore equatable codegen and builder config

# 3.1.2 | 12.9.25

## Fixes

- Fix issue where the label maker would throw an error if the terminal was not available
  - Would impact if the user was running the hook in a non-terminal environment (such as vscode extensions)

# 3.1.1 | 11.19.25

## Features

- Add `runInParallel` parameter to `Hook`, which allows you to specify whether the top level tasks should be run in parallel
  - Defaults to `true`

## Deps

- Remove `args` dependency, use pattern matching instead
- Add `scoped_deps` dependency

# 3.0.0 | 10.15.25

## Breaking Changes

- Remove `always` constructor from `SequentialTask` and `ParallelTask`
- Remove `include` parameter from `SequentialTask` and `ParallelTask`

## Enhancements

- Improve task filtering in "always" sub tasks

# 2.1.0 | 9.19.25

## Features

- Support branches that do not have an upstream set

# 2.0.2 | 6.5.25

## Fixes

- Issue where deleted files were being added to commit when they were not modified

# 2.0.1 | 4.16.25

## Fixes

- Issue where backup stash was being created unnecessarily

## Chores

- Clean up old files

# 2.0.0 | 4.12.25

## Features

- Create `PreCommitHook` specifically for the `pre-commit` hook
  - This hook will get the files that are being committed to run the tasks against
  - _This was the previous default behavior of the `Hook` class_
- Create `PrePushHook` specifically for the `pre-push` hook
  - This hook will get the files that are being pushed to run the tasks against
- Create `AnyHook`
  - A general purpose hooks that can be used to create custom hooks
- Add `verbose` constructor to all hooks
  - This will enable verbose output, providing detailed information about the tasks being executed

## Breaking Changes

- `Hook` is now an abstract class
- Remove `VerboseHook`, prefer to use the `verbose` constructor on any of the `Hook` classes
- Remove functionality for running tasks against "partially staged" files
  - Tasks will run against the staged files **as they are**
  - The previous behavior was buggy and slow. The benefit that it provided was not worth the complexity it added to the code
    - (If you feel differently, please let me know and I will reconsider this)

# 1.3.1 | 3.21.25

## Fixes

- Fix issue where `always` did not provide any files

# 1.3.0 | 2.21.25

## Enhancements

- Apply failsafe stash before attempting to restore
  - This helps prevent the loss of non-version controlled files (such as the .dart_tool directory)

# 1.2.0 | 1.20.25

## Features

- New `always` constructor on commands to run them regardless if any files are being processed
- Create failsafe Stash during backup processing to ensure that files are not lost when an error occurs

## Enhancements

- Improve backup processing during pre-commit hooks

## Fixes

- Better handle file processing when `diffArgs` is provided

# 1.1.0 | 12.18.24

## Features

- Support shell files in the `hooks` directory

# 1.0.2 | 12.9.24

- Initial version
