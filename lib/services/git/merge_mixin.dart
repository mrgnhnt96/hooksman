import 'package:file/file.dart';
import 'package:path/path.dart' as p;

mixin MergeMixin {
  FileSystem get fs;

  static const _mergeHead = 'MERGE_HEAD';
  static const _mergeMode = 'MERGE_MODE';
  static const _mergeMsg = 'MERGE_MSG';

  String get gitDir;

  String? _content(String path) {
    final file = fs.file(path);

    if (!file.existsSync()) return null;

    return file.readAsStringSync();
  }

  void _writeContent(String path, String? content) {
    if (content == null) return;

    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  set mergeHead(String? content) =>
      _writeContent(p.join(gitDir, _mergeHead), content);

  String? get mergeHead {
    return _content(p.join(gitDir, _mergeHead));
  }

  set mergeMode(String? content) =>
      _writeContent(p.join(gitDir, _mergeMode), content);

  String? get mergeMode {
    return _content(p.join(gitDir, _mergeMode));
  }

  set mergeMsg(String? content) =>
      _writeContent(p.join(gitDir, _mergeMsg), content);

  String? get mergeMsg {
    return _content(p.join(gitDir, _mergeMsg));
  }

  void restoreMergeStatuses({
    required String? msg,
    required String? mode,
    required String? head,
  }) {
    mergeMsg = msg;
    mergeMode = mode;
    mergeHead = head;
  }
}
