import 'package:hooksman/entrypoint/hook_execution/hook_executor.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:test/test.dart';

void main() {
  group('postSuccessExitCode', () {
    test('PreCommitHook(allowEmpty: false) + empty → 1', () {
      const hook = PreCommitHook(tasks: []);
      expect(postSuccessExitCode(hook, const []), 1);
    });

    test('PreCommitHook(allowEmpty: false) + files → 0', () {
      const hook = PreCommitHook(tasks: []);
      expect(postSuccessExitCode(hook, const ['a.dart']), 0);
    });

    test('PreCommitHook(allowEmpty: true) + empty → 0', () {
      const hook = PreCommitHook(tasks: [], allowEmpty: true);
      expect(postSuccessExitCode(hook, const []), 0);
    });

    test('PrePushHook + empty → 0', () {
      const hook = PrePushHook(tasks: []);
      expect(postSuccessExitCode(hook, const []), 0);
    });

    test('AnyHook + empty → 0', () {
      const hook = AnyHook(tasks: []);
      expect(postSuccessExitCode(hook, const []), 0);
    });

    test('CommitMsgHook + empty → 0', () {
      const hook = CommitMsgHook(tasks: []);
      expect(postSuccessExitCode(hook, const []), 0);
    });
  });
}
