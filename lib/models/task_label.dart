class TaskLabel {
  const TaskLabel(
    this.name, {
    required this.taskId,
    required this.fileCount,
    this.children = const [],
  });

  final String name;
  final int fileCount;
  final String taskId;
  final List<TaskLabel> children;

  bool get hasChildren => children.isNotEmpty;

  int get length {
    if (!hasChildren) {
      return 1;
    }

    return children.length;
  }

  int get depth {
    if (children.isEmpty) {
      return 1;
    }

    return children
        .map((e) => e.depth)
        .reduce((value, element) => value + element);
  }

  @override
  String toString() => name;
}
