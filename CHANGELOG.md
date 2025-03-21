<!--  -->

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
