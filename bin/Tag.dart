class Tag {
  final String text;

  Tag(this.text);

  @override
  String toString() {
    return "# $text";
  }
}
