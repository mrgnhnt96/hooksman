import 'package:hooksman/app/components/hook_header.dart';
import 'package:hooksman/app/data/is_debug.dart';
import 'package:hooksman/app/data/steps.dart';
import 'package:hooksman/app/steps/footer/step_footer.dart';
import 'package:hooksman/app/steps/initial/initial_step.dart';
import 'package:hooksman/app/steps/running/running.dart';
import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_provider/provider.dart';

class HooksmanApp extends StatefulComponent {
  const HooksmanApp({
    required this.pendingHook,
    required this.nameOfHook,
    required this.debug,
    required this.steps,
    super.key,
  });

  final PendingHook pendingHook;
  final String nameOfHook;
  final Steps steps;
  final bool debug;

  @override
  State<HooksmanApp> createState() => _HooksmanAppState();
}

class _HooksmanAppState extends State<HooksmanApp> {
  @override
  void initState() {
    super.initState();
    component.steps.addListener(_onStepsChanged);
  }

  @override
  void didUpdateComponent(HooksmanApp oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.steps != component.steps) {
      oldComponent.steps.removeListener(_onStepsChanged);
      component.steps.addListener(_onStepsChanged);
    }
  }

  @override
  void dispose() {
    component.steps.removeListener(_onStepsChanged);
    super.dispose();
  }

  void _onStepsChanged() => setState(() {});

  @override
  Component build(BuildContext context) {
    final step = component.steps.current;

    // Intercept Ctrl+C so nocterm does not call requestExit(0). Task kill /
    // exit code 1 are handled by PendingHook's ProcessSignal listener and
    // HookExecutor.
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.matches(LogicalKey.keyC, ctrl: true)) {
          return true;
        }
        return false;
      },
      child: Provider(
        create: (_) => IsDebug(component.debug),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HookHeader(
              nameOfHook: component.nameOfHook,
              pendingHook: component.pendingHook,
              debug: component.debug,
            ),
            const SizedBox(height: 1),
            if (step == Step.start)
              const InitialStep()
            else ...[
              for (final task in component.pendingHook.topLevelTasks)
                Running(task),
            ],
            StepFooter(step),
          ],
        ),
      ),
    );
  }
}
