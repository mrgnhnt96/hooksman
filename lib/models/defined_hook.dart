import 'package:change_case/change_case.dart';
import 'package:path/path.dart' as p;

class DefinedHook {
  const DefinedHook(this.path);

  final String path;

  bool get isDart => p.extension(path).endsWith('.dart');

  bool get isShell => p.extension(path).endsWith('.sh');

  String get name => p.basenameWithoutExtension(path).toParamCase();

  String get fileName => p.basename(path);
}
