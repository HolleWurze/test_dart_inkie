import 'Container.dart';

class SearchResult {
  final dynamic obj; // Dart doesn't have a direct equivalent of C#'s Object type
  final bool approximate;

  SearchResult(this.obj, this.approximate);

  get correctObj => approximate ? null : obj;
  Container? get container => obj as Container?;
}
