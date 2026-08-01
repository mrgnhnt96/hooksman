import 'dart:async';

import 'package:hooksman/app/data/is_debug.dart';
import 'package:hooksman/models/pending_task.dart';
import 'package:hooksman/src/vendor/nocterm_provider/provider.dart';
import 'package:nocterm/nocterm.dart';

part 'components/__file_count.dart';
part 'components/__icon.dart';
part 'components/__index.dart';
part 'components/__name.dart';
part 'components/__progress_indicator.dart';
part 'components/__status.dart';
part 'components/__sub_tasks.dart';
part 'data/__pending_task.dart';

class Running extends StatefulComponent {
  const Running(this.task, {super.key}) : indent = 1;
  const Running._nested(this.task, this.indent);

  final PendingTask task;
  final int indent;

  @override
  State<Running> createState() => _RunningState();
}

class _RunningState extends State<Running> {
  @override
  void initState() {
    super.initState();
    component.task.addListener(_onChanged);
  }

  @override
  void dispose() {
    component.task.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Component build(BuildContext context) {
    final task = component.task;
    final isDebug = context.read<IsDebug>().value;
    final pending = _PendingTask.snapshot(task, indent: component.indent);

    return Padding(
      padding: EdgeInsets.only(left: component.indent.toDouble()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDebug) ...[
            Text('\nTotal depth: ${task.resolvedTask.label.depth}'),
            _Status(pending.status),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDebug) ...[
                _Index(pending.index),
                const SizedBox(width: 1),
                _Status.short(pending.status, hasSubtasks: pending.hasSubtasks),
                const SizedBox(width: 1),
              ],
              _Icon(status: pending.status, hasSubtasks: pending.hasSubtasks),
              const SizedBox(width: 1),
              _Name(pending.name),
              const SizedBox(width: 1),
              _FileCount(pending.fileCount),
            ],
          ),
          if (pending.hasSubtasks &&
              !pending.hasCompleted &&
              !pending.hasHalted)
            _SubTasks(pending.subTasks, indent: component.indent),
        ],
      ),
    );
  }
}
