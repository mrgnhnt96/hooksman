/// A pattern that matches all files. This class implements the [Pattern]
/// interface and can be used to match any file path.
///
/// Example usage:
/// ```dart
/// final allFiles = AllFiles();
/// final matches = allFiles.allMatches('example.dart');
/// print(matches.isNotEmpty); // true
/// ```
///
/// This class is useful when you want to include all files in a task
class AllFiles implements Pattern {
  AllFiles() : _pattern = RegExp('.*', caseSensitive: false);

  final Pattern _pattern;

  @override
  Iterable<Match> allMatches(String string, [int start = 0]) {
    return _pattern.allMatches(string, start);
  }

  @override
  Match? matchAsPrefix(String string, [int start = 0]) {
    return _pattern.matchAsPrefix(string, start);
  }

  @override
  String toString() => 'all files';
}
