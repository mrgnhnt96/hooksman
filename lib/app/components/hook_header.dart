import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:nocterm/nocterm.dart';

class HookHeader extends StatelessComponent {
  const HookHeader({
    required this.nameOfHook,
    required this.pendingHook,
    required this.debug,
    super.key,
  });

  final String nameOfHook;
  final PendingHook pendingHook;
  final bool debug;

  @override
  Component build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Running tasks for $nameOfHook'),
        if (debug) ...[
          const SizedBox(height: 1),
          Text(
            'Started: ${pendingHook.startedTasks.join(', ')}',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Completed: ${pendingHook.completedTasks.join(', ')}',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Killed: ${pendingHook.wasKilled}  Dead: ${pendingHook.isDead}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ],
    );
  }
}
