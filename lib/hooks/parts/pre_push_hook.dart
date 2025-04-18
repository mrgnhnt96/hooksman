part of '../hook.dart';

/// {@macro hook}
class PrePushHook extends Hook {
  const PrePushHook({
    required super.tasks,
    super.diffFilters = 'ACMR',
    super.diffArgs = const ['@{u}', 'HEAD'],
  });

  const PrePushHook.verbose({
    required super.tasks,
    super.diffFilters = 'ACMR',
    super.diffArgs = const ['@{u}', 'HEAD'],
  }) : super.verbose();
}
