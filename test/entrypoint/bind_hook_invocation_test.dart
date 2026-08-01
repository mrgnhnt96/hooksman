import 'package:hooksman/entrypoint/execute_hook.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:test/test.dart';

void main() {
  group('bindHookInvocation', () {
    test('commit-msg + args → messageFile = args.first', () {
      const hook = CommitMsgHook(tasks: []);
      final bound = bindHookInvocation(
        name: 'commit-msg',
        hook: hook,
        args: ['.git/COMMIT_EDITMSG'],
      );

      expect(bound.messageFile, '.git/COMMIT_EDITMSG');
      expect(
        (bound.boundHook as CommitMsgHook).messageFile,
        '.git/COMMIT_EDITMSG',
      );
      expect(bound.context.messageFile, '.git/COMMIT_EDITMSG');
      expect(bound.context.args, ['.git/COMMIT_EDITMSG']);
    });

    test('pre-push + two args → remoteName/remoteUrl', () {
      const hook = PrePushHook(tasks: []);
      final bound = bindHookInvocation(
        name: 'pre-push',
        hook: hook,
        args: ['origin', 'https://example.com/repo.git'],
      );

      expect(bound.remoteName, 'origin');
      expect(bound.remoteUrl, 'https://example.com/repo.git');
      expect(bound.messageFile, isNull);
    });

    test('HookContext carries args/stdin/messageFile', () {
      const hook = CommitMsgHook(tasks: []);
      final bound = bindHookInvocation(
        name: 'commit_msg',
        hook: hook,
        args: ['MSG'],
        stdinContent: 'stdin-body',
      );

      expect(bound.context.args, ['MSG']);
      expect(bound.context.stdin, 'stdin-body');
      expect(bound.context.messageFile, 'MSG');
    });

    test('PrePushHook type binds remotes even with non-pre-push name', () {
      const hook = PrePushHook(tasks: []);
      final bound = bindHookInvocation(
        name: 'custom',
        hook: hook,
        args: ['upstream', 'git@host:repo.git'],
      );

      expect(bound.remoteName, 'upstream');
      expect(bound.remoteUrl, 'git@host:repo.git');
    });
  });
}
