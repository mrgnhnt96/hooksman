part of '../running.dart';

class _FileCount extends StatelessComponent {
  const _FileCount(this.fileCount);

  final int fileCount;

  @override
  Component build(BuildContext context) {
    final text = switch (fileCount) {
      0 => '- no files',
      1 => '- 1 file',
      _ => '- $fileCount files',
    };

    return Text(text, style: const TextStyle(color: Colors.grey));
  }
}
