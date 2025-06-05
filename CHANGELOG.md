<!--  -->

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
