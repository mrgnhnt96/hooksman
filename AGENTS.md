# AGENTS.md

Guide for AI agents contributing to **hooksman** itself. If you are helping someone *use*
the package in their own project, read `llms-full.txt` instead — it is the usage reference
and this file is not.

## What this package is

A Dart CLI + library that turns `hooks/*.dart` files into native executables and wires them
into Git via `core.hooksPath`. A hook file's `main()` returns a `Hook`; hooksman resolves
the changed files from `git diff`, filters them per task, runs the tasks, and exits
non-zero to abort the Git operation.

## Setup

```sh
sip install          # gen sync + clean .dart_tool + pub get + global activate
```

`sip` is [`sip_cli`](https://pub.dev/packages/sip_cli); every script lives in
`scripts.yaml`. Without it, run the underlying commands directly:

```sh
bash tool/sync_gen.sh   # required: clones pinned deps into gen/, vendors into lib/src/vendor/
dart pub get
```

## Commands

| Task | Command | Notes |
| --- | --- | --- |
| Test | `sip test` / `dart test` | Scope to `test/` when passing a path — see the `gen/` warning below. |
| Lint | `sip lint` | `dart format . --set-exit-if-changed` then `dart analyze --fatal-infos --fatal-warnings`. Both must pass. |
| Codegen | `sip run build_runner build` | Regenerates `*.g.dart` (equatable props). |
| Barrel | `sip run barrel` | Regenerates `lib/hooksman.dart` via `barreler`. |
| Vendor sync | `sip gen sync` | Re-clones pins into `gen/`, re-vendors `lib/src/vendor/`. |
| Register hooks | `sip hooks` / `dart run hooksman register` | Recompiles this repo's own hooks. |
| Publish | `sip publish` | Guarded, see Publishing. |

Analysis is strict: `strict-casts`, `strict-inference`, `strict-raw-types`, and a long
lint list in `analysis_options.yaml`. `--fatal-infos` means an info-level lint fails the
build, so run `sip lint` before considering work done.

## Layout

```
bin/hooksman.dart              CLI entrypoint → GitHookRunner
lib/
  commands/                    register / uninstall commands, GitHookRunner dispatch
  entrypoint/
    execute_hook.dart          runtime entrypoint called by generated wrappers
    hook_execution/            HookExecutor, TaskRunner, PendingHook
  hooks/                       Hook base class + parts/ (PreCommit, PrePush, CommitMsg, Any)
  tasks/                       HookTask base + ShellTask, DartTask, groups, ReRegisterHooks
  services/git/                GitService: diff, staging, backup/restore refs
  app/                         nocterm TUI that renders hook progress
  deps/                        scoped_deps providers (fs, git, process, logger, args, compiler)
  models/                      Args, DefinedHook, Compiler, resolved/pending task models
  src/vendor/                  vendored nocterm_provider / nocterm_nested — do not edit
  hooksman.dart                GENERATED barrel — do not edit
hooks/                         this repo's own hooks (dogfooding)
tool/                          sync_gen.sh, vendor_from_gen.sh, gen_packages.yaml, demo_ui.dart
test/                          mirrors lib/ structure
```

## Two execution paths

Keep these distinct when changing behavior — they have different dependency graphs.

1. **Register/uninstall (CLI).** `bin/hooksman.dart` parses `Args`, scopes providers, and
   calls `GitHookRunner`. `RegisterCommand` finds top-level `hooks/*.dart` and `hooks/*.sh`,
   writes a wrapper per Dart hook into `.dart_tool/hooksman/`, compiles it with
   `dart compile exe` into `.dart_tool/hooksman/executables/`, writes POSIX shims into
   `hooks/_/`, and sets `core.hooksPath`.
2. **Hook run.** The compiled wrapper calls `executeHook(name, hook, args)`, which binds
   Git args/stdin into a `HookContext`, scopes providers, and hands off to `HookExecutor`:
   resolve the diff → snapshot via `git.createBackup()` → run tasks → re-stage or roll back.

`.git/hooks` is never touched. Do not reintroduce writes there.

## Dependency injection

All I/O goes through `scoped_deps` providers in `lib/deps/`: `fs`, `git`, `process`,
`logger`, `args`, `compiler`. Read them through the global getters (`fs.file(...)`, not
`File(...)`) so tests can substitute a `MemoryFileSystem` or a mock. New I/O belongs behind
a provider.

Two escape hatches exist for things `scoped_deps` cannot reach: `Compiler.ctor` and
`Compiler.isWindows` are static, overridable function fields, because `Process.run` and
`Platform.isWindows` are not mockable. Restore them in a test's teardown.

## Generated code

Never hand-edit these; regenerate instead:

- `lib/hooksman.dart` — the public barrel, produced by `sip run barrel` from `barreler.yaml`.
  Adding a new public API means adding it to the `include` list there and regenerating.
- `**/*.g.dart` — equatable props, produced by `sip run build_runner build`. Adding a field
  to a class with a `part '*.g.dart'` requires a regen or `_$props` goes stale.

## Vendored packages

`nocterm` is a hosted dependency. Its unpublished siblings `nocterm_provider` and
`nocterm_nested` are cloned into `gen/` (gitignored) from the pin in
`tool/gen_packages.yaml`, then copied by `tool/vendor_from_gen.sh` into `lib/src/vendor/`
(committed) with imports rewritten. This exists so the published package has no `path:` or
`git:` dependencies.

- Commit `lib/src/vendor/`, never `gen/`.
- Do not edit `lib/src/vendor/` by hand — bump the pin and re-run `sip gen sync`.
- Both `gen/**` and `lib/src/vendor/**` are excluded from analysis.
- Keep the hosted `nocterm` constraint compatible with the pinned SHA's version.

## Testing

`dart test`. Tests use `testScoped` from `test/utils/test_scoped.dart`, which wraps
`test()` and installs providers — pass `fileSystem:`, `git:`, `process:`, `compiler:`,
`logger:`, or `args:` to override; the default file system is `MemoryFileSystem.test`.
Mocks are `mocktail`. `test/services/git/` exercises real `git` in temp directories, so
those tests need `git` on PATH.

**Never run an unscoped `sip test`.** `sip` discovers tests with a `**/*_test.dart` glob
from the package root and cannot exclude directories, so it walks into the gitignored
`gen/` checkout, tries to compile the vendored packages' own tests, and reports zero tests
overall. Always pass `test/`. Plain `dart test` is unaffected.

## Style

- Package imports only (`package:hooksman/...`), never relative — enforced by lint.
- No `print` in `lib/`: use the scoped `logger`, or the `print` callback passed into
  `HookTask.run`. Direct stdout writes corrupt the nocterm TUI while a hook is rendering.
- Prefer switch expressions and pattern matching; the codebase leans on them heavily.
- Match the surrounding comment density: comments here explain *why* a non-obvious choice
  was made (the `gen/` test scoping, the Windows branches), not what the code does.
- Windows matters. `ShellTask` uses `cmd /c`, `chmod` is skipped, and Dart import URIs in
  generated wrappers always use `/`. Do not regress these.

## Changelog, versioning, publishing

`CHANGELOG.md` leads with an `# Unreleased` section grouped under `## Features`,
`## Fixes`, `## Deps`. Add an entry there for any user-visible change.

`sip publish` derives the version from the first `# ` heading in `CHANGELOG.md` and writes
it into `pubspec.yaml`, so a release means renaming `# Unreleased` to `# <version> | <date>`.
The script refuses to publish while `pubspec.yaml` has any `path:` or `git:` dependency,
then runs gen sync, tests, lint, a dry run, publish, commit, tag, and push.

## Committing

This repo's own `pre-commit` hook runs `ReRegisterHooks`, lint/format, build_runner, and
tests. Two consequences:

- The hook formats files and **re-stages them even when a later task fails.** After a
  failed commit, verify what is staged before retrying — a blind `git add -A && git commit`
  sweeps unrelated work into the commit. Stage explicit paths.
- Changing anything under `hooks/` requires a re-register for the change to take effect;
  `ReRegisterHooks` handles that on the next commit, but run `sip hooks` if you need it now.

Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`,
`style:`).

## Keeping docs in sync

A change to the public API or to hook behavior should update, in the same change:
`README.md`, `llms-full.txt`, `llms.txt` if the summary facts moved, and `CHANGELOG.md`.
