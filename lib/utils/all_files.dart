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
}
