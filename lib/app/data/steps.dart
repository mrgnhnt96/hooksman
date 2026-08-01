import 'package:nocterm/nocterm.dart';

class Steps extends ChangeNotifier {
  Steps() : _current = Step.start;

  Step _current;
  Step get current => _current;
  set current(Step step) {
    if (step == _current) return;

    _current = step;
    notifyListeners();
  }
}

enum Step { start, running, quit, error, complete }
