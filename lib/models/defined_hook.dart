import 'package:change_case/change_case.dart';
import 'package:hooksman/deps/fs.dart';

class DefinedHook {
  const DefinedHook(this.path);

  final String path;

  bool get isDart => fs.path.extension(path).endsWith('.dart');

  bool get isShell => fs.path.extension(path).endsWith('.sh');

  String get name => fs.path.basenameWithoutExtension(path).toParamCase();

  String get fileName => fs.path.basename(path);
}
