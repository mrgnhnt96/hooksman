part of '../running.dart';

class _Index extends StatelessComponent {
  const _Index(this.index);

  final int index;

  @override
  Component build(BuildContext context) {
    return Text('$index', style: const TextStyle(color: Colors.grey));
  }
}
