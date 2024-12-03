import 'package:change_case/change_case.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

part 'hook_to_register.g.dart';

class HookToRegister extends Equatable {
  const HookToRegister({
    required this.hookName,
    required this.filePath,
  });

  factory HookToRegister.fromPath(String path) {
    final fileName = p.basenameWithoutExtension(path);

    final hookName = fileName.toParamCase();

    return HookToRegister(
      hookName: hookName,
      filePath: path,
    );
  }

  final String filePath;
  final String hookName;

  @override
  List<Object?> get props => _$props;
}
