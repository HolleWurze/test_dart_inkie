class Reader {
  String _text;
  int _offset;
  Object _rootObject;

  Reader(this._text) {
    _offset = 0;
    skipWhitespace();
    _rootObject = readObject();
  }

  Map<String, Object> toDictionary() {
    return _rootObject as Map<String, Object>;
  }

  List<Object> toArray() {
    return _rootObject as List<Object>;
  }
}
