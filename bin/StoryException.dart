class StoryException implements Exception {
  final bool useEndLineNumber;
  final String message;

  StoryException({this.useEndLineNumber = false, this.message = ''});

  @override
  String toString() => message;
}
