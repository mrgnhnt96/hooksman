part of '../running.dart';

class _Name extends StatelessComponent {
  const _Name(this.name);

  final String name;

  @override
  Component build(BuildContext context) {
    return Text(name);
  }
}
