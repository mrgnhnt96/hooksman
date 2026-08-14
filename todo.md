# TODO

- [ ] Create a `Condition` class that can be used to check a task's exit code and execute a task based on the result
- [ ] Add `IfAny`, `IfAll`, and `IfNone` conditions
  - [ ] Verify by creating a task that checks if the pubspec.yaml file contains a `dev_dependencies.build_runner`, then execut a task to run `build_runner build --delete-conflicting-outputs`
- [ ] Make nocterm TUI optional for publish builds (fall back to mason_logger) once feasible

## Fixed

### 7.31.26

- [x] Empty-diff exit: only `PreCommitHook` without `allowEmpty` returns 1 for "No changes to commit"
- [x] Windows import paths: generated wrappers use `/` in Dart import URIs
- [x] Windows shell: `ShellTask` uses `cmd /c` on Windows
- [x] Windows chmod: skip `chmod +x` on Windows in `Compiler`
- [x] PathsMixin root walk: stop when `parent.path == directory.path` (drive root)
- [x] Missing upstream / failed `@{u}`: treat as empty file list (retry with remote/branch when available)
- [x] Husky-style `hooks/_` install via `core.hooksPath`; stop wiping `.git/hooks`
- [x] Forward hook args/stdin via `HookContext`; add `CommitMsgHook`
- [x] `HOOKSMAN=0` / `SKIP=1` skip; `hooksman uninstall`
- [x] Publish script fails early on `path: gen/` deps; document publish blockers

### 11.19.25

- [x] Make task "pending" state when `runInParallel` is false in the hook

### 9.19.25

- [x] multiple origins fails when default origin has no changes to push
  - [x] Find a way to check which origin we are pushing to
