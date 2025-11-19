# TODO

- [ ] Create a `Condition` class that can be used to check a task's exit code and execute a task based on the result
- [ ] Add `IfAny`, `IfAll`, and `IfNone` conditions
  - [ ] Verify by creating a task that checks if the pubspec.yaml file contains a `dev_dependencies.build_runner`, then execut a task to run `build_runner build --delete-conflicting-outputs`

## Fixed

### 11.19.25

- [x] Make task "pending" state when `runInParallel` is false in the hook

### 9.19.25

- [x] multiple origins fails when default origin has no changes to push
  - [x] Find a way to check which origin we are pushing to
