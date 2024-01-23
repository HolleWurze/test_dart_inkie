import 'State.dart';
import 'StateElement.dart';
import 'Container.dart';

class Writer {
    late StringWriter _writer;

    Writer() {
      _writer = StringWriter();
    }

  Writer.fromStream(Uint8List stream) {
    _writer = StringWriter()
      ..write(utf8.decode(stream));
  }

  void writeObject(void Function(Writer) inner) {
    writeObjectStart();
    inner(this);
    writeObjectEnd();
  }

  void writeObjectStart() {
    startNewObject(container: true);
    _stateStack.add(StateElement(type: State.object));
    _writer.write('{');
  }

  void writeObjectEnd() {
    assert(state == State.object);
    _writer.write('}');
    _stateStack.removeLast();
  }

  void writeProperty(String name, void Function(Writer) inner) {
    writeProperty<String>(name, inner);
  }

  void writePropertyInt(String name, void Function(Writer) inner) {
    writeProperty<int>(name, inner);
  }

  void writePropertyBool(String name, bool content) {
    writePropertyStart(name);
    write(content);
    writePropertyEnd();
  }

  void writePropertyString(String name, String content) {
    writePropertyStart(name);
    write(content);
    writePropertyEnd();
  }

  void writePropertyStart(String name) {
    writePropertyStart<String>(name);
  }

  void writePropertyIntStart(int id) {
    writePropertyStart<int>(id);
  }

  void writePropertyStart<T>(T name) {
    assert(state == State.object);

    if (childCount > 0) {
      _writer.write(',');
    }

    _writer.write('"');
    _writer.write(name);
    _writer.write('":');

    incrementChildCount();

    _stateStack.add(StateElement(type: State.property));
  }

  void writePropertyEnd() {
    assert(state == State.property);
    assert(childCount == 1);
    _stateStack.removeLast();
  }

  void writePropertyNameStart() {
    assert(state == State.object);

    if (childCount > 0) {
      _writer.write(',');
    }

    _writer.write('"');

    incrementChildCount();

    _stateStack.add(StateElement(type: State.property));
    _stateStack.add(StateElement(type: State.propertyName));
  }

  void writePropertyNameEnd() {
    assert(state == State.propertyName);

    _writer.write('":');

    // Pop PropertyName, leaving Property state
    _stateStack.removeLast();
  }

  void writePropertyNameInner(String str) {
    assert(state == State.propertyName);
    _writer.write(str);
  }

  void writeArrayStart() {
    startNewObject(container: true);
    _stateStack.add(StateElement(type: State.array));
    _writer.write('[');
  }

  void writeArrayEnd() {
    assert(state == State.array);
    _writer.write(']');
    _stateStack.removeLast();
  }

  void write(int i) {
    startNewObject(container: false);
    _writer.write(i);
  }

  void writeDouble(double d) {
    startNewObject(container: false);

    String doubleStr = d.toString();
    if (doubleStr == 'Infinity') {
      _writer.write('3.4E+38'); // JSON doesn't support, do our best alternative
    } else if (doubleStr == '-Infinity') {
      _writer.write(
          '-3.4E+38'); // JSON doesn't support, do our best alternative
    } else if (doubleStr == 'NaN') {
      _writer.write('0.0'); // JSON doesn't support, not much we can do
    } else {
      _writer.write(doubleStr);
      if (!doubleStr.contains('.') && !doubleStr.contains('E')) {
        _writer.write(
            '.0'); // ensure it gets read back in as a floating point value
      }
    }
  }

  void writeString(String str, [bool escape = true]) {
    startNewObject(container: false);

    _writer.write('"');
    if (escape) {
      writeEscapedString(str);
    } else {
      _writer.write(str);
    }
    _writer.write('"');
  }

  void writeBool(bool b) {
    startNewObject(container: false);
    _writer.write(b ? 'true' : 'false');
  }

  void writeNull() {
    startNewObject(container: false);
    _writer.write('null');
  }

  void writeStringStart() {
    startNewObject(container: false);
    _stateStack.add(StateElement(type: State.string));
    _writer.write('"');
  }

  void writeStringEnd() {
    assert(state == State.string);
    _writer.write('"');
    _stateStack.removeLast();
  }

  void writeStringInner(String str, [bool escape = true]) {
    assert(state == State.string);
    if (escape) {
      writeEscapedString(str);
    } else {
      _writer.write(str);
    }
  }

  void writeEscapedString(String str) {
    for (int i = 0; i < str.length; i++) {
      String c = str[i];
      if (c < ' ') {
        switch (c) {
          case '\n':
            _writer.write(r'\n');
            break;
          case '\t':
            _writer.write(r'\t');
            break;
          default:
          // Don't write any control characters except \n and \t
            break;
        }
      } else {
        switch (c) {
          case '\\':
          case '"':
            _writer.write(r'\');
            _writer.write(c);
            break;
          default:
            _writer.write(c);
            break;
        }
      }
    }
  }

  void startNewObject(bool container) {
    if (container) {
      assert(state == State.none || state == State.property ||
          state == State.array);
    } else {
      assert(state == State.property || state == State.array);
    }

    if (state == State.array && childCount > 0) {
      _writer.write(',');
    }

    if (state == State.property) {
      assert(childCount == 0);
    }

    if (state == State.array || state == State.property) {
      incrementChildCount();
    }
  }

  State get state {
    if (_stateStack.isNotEmpty) {
      return _stateStack.last.type;
    } else {
      return State.none;
    }
  }

  int get childCount {
    if (_stateStack.isNotEmpty) {
      return _stateStack.last.childCount;
    } else {
      return 0;
    }
  }

  void incrementChildCount() {
    assert(_stateStack.isNotEmpty);
    StateElement currEl = _stateStack.removeLast();
    currEl.childCount++;
    _stateStack.add(currEl);
  }

  String toString() {
    return _writer.toString();
  }

  List<StateElement> _stateStack = [];

}