import 'package:hooksman/app/data/steps.dart';
import 'package:nocterm/nocterm.dart';

class StepFooter extends StatelessComponent {
  const StepFooter(this.step, {super.key});

  final Step step;

  @override
  Component build(BuildContext context) {
    final (:icon, :label, :color) = switch (step) {
      Step.complete => (icon: '✓', label: 'Finished', color: Colors.green),
      Step.quit => (icon: '•', label: 'Interrupted', color: Colors.blue),
      Step.error => (icon: 'ⅹ', label: 'Failed', color: Colors.red),
      Step.start || Step.running => (icon: '', label: '', color: Colors.grey),
    };

    if (label.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Text(icon, style: TextStyle(color: color)),
          const SizedBox(width: 1),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
