import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/tasks/shell_task.dart';
import 'package:test/test.dart';

void main() {
  group(CommitMsgHook, () {
    test('shouldRunOnEmpty is true', () {
      const hook = CommitMsgHook(tasks: []);
      expect(hook.shouldRunOnEmpty, isTrue);
    });

    test('bindMessageFile sets messageFile', () {
      const hook = CommitMsgHook(tasks: []);
      final bound = hook.bindMessageFile('.git/COMMIT_EDITMSG');
      expect(bound.messageFile, '.git/COMMIT_EDITMSG');
    });

    test('bindMessageFile preserves verbose', () {
      const hook = CommitMsgHook.verbose(tasks: []);
      final bound = hook.bindMessageFile('msg');
      expect(bound.verbose, isTrue);
      expect(bound.messageFile, 'msg');
    });

    test('default diff args are empty', () {
      final hook = CommitMsgHook(
        tasks: [
          ShellTask.always(commands: (_) => ['true']),
        ],
      );
      expect(hook.diffArgs, isEmpty);
      expect(hook.diffFilters, isEmpty);
    });
  });
}
