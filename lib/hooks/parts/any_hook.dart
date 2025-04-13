part of '../hook.dart';

class AnyHook extends Hook {
  const AnyHook({
    required super.tasks,
    super.diffArgs = const [],
    super.diffFilters = '',
  });
  const AnyHook.verbose({
    required super.tasks,
    super.diffArgs = const [],
    super.diffFilters = '',
  }) : super.verbose();
}
