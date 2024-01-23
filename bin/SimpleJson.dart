import 'dart:math';
import 'Reader.dart';

class SimpleJson {
  static Map<String, Object> textToDictionary(String text) {
    return Reader(text).toDictionary();
  }

  static List<Object> textToArray(String text) {
    return Reader(text).toArray();
  }

  bool isNumberChar(String c) {
    return RegExp(r'[0-9\.\-\+Ee]').hasMatch(c);
  }

  bool isFirstNumberChar(String c) {
    return RegExp(r'[0-9\-\+]').hasMatch(c);
  }

  Object readObject() {
    String currentChar = _text[_offset];

    if (currentChar == '{') {
      return readDictionary();
    } else if (currentChar == '[') {
      return readArray();
    } else if (currentChar == '"') {
      return readString();
    } else if (isFirstNumberChar(currentChar)) {
      return readNumber();
    } else if (tryRead('true')) {
      return true;
    } else if (tryRead('false')) {
      return false;
    } else if (tryRead('null')) {
      return null;
    } else {
      throw Exception(
          'Unhandled object type in JSON: ${_text.substring(_offset, min(_text.length, _offset + 30))}');
    }
  }

  Map<String, Object> readDictionary() {
    Map<String, Object> dict = {};

    expect('{');

    skipWhitespace();

    if (tryRead('}')) {
      return dict;
    }

    do {
      skipWhitespace();

      String key = readString();
      expect(key != null, 'dictionary key');

      skipWhitespace();
      expect(':');
      skipWhitespace();

      Object val = readObject();
      expect(val != null, 'dictionary value');

      dict[key] = val;

      skipWhitespace();
    } while (tryRead(','));

    expect('}');

    return dict;
  }

  List<Object> readArray() {
    List<Object> list = [];

    expect('[');

    skipWhitespace();

    if (tryRead(']')) {
      return list;
    }

    do {
      skipWhitespace();

      Object val = readObject();

      list.add(val);

      skipWhitespace();
    } while (tryRead(','));

    expect(']');

    return list;
  }

  String readString() {
    expect('"');

    StringBuffer sb = StringBuffer();

    for (; _offset < _text.length; _offset++) {
      String c = _text[_offset];

      if (c == '\\') {
        _offset++;
        if (_offset >= _text.length) {
          throw Exception('Unexpected EOF while reading string');
        }
        c = _text[_offset];
        switch (c) {
          case '"':
          case '\\':
          case '/':
            sb.write(c);
            break;
          case 'n':
            sb.write('\n');
            break;
          case 't':
            sb.write('\t');
            break;
          case 'r':
          case 'b':
          case 'f':
            break;
          case 'u':
            if (_offset + 4 >= _text.length) {
              throw Exception('Unexpected EOF while reading string');
            }
            String digits = _text.substring(_offset + 1, _offset + 5);
            int uchar = int.parse(digits, radix: 16, onError: (_) {
              throw Exception(
                  'Invalid Unicode escape character at offset ${_offset - 1}');
            });
            sb.write(String.fromCharCode(uchar));
            _offset += 4;
            break;
          default:
            throw Exception(
                'Invalid Unicode escape character at offset ${_offset - 1}');
        }
      } else if (c == '"') {
        break;
      } else {
        sb.write(c);
      }
    }

    expect('"');
    return sb.toString();
  }

  Object readNumber() {
    int startOffset = _offset;

    bool isFloat = false;
    for (; _offset < _text.length; _offset++) {
      String c = _text[_offset];
      if (c == '.' || c == 'e' || c == 'E') isFloat = true;
      if (isNumberChar(c)) {
        continue;
      } else {
        break;
      }
    }

    String numStr = _text.substring(startOffset, _offset);

    if (isFloat) {
      double? f = double.tryParse(numStr);
      if (f != null) {
        return f;
      }
    } else {
      int? i = int.tryParse(numStr);
      if (i != null) {
        return i;
      }
    }

    throw Exception('Failed to parse number value: $numStr');
  }

  bool tryRead(String textToRead) {
    if (_offset + textToRead.length > _text.length) {
      return false;
    }

    for (int i = 0; i < textToRead.length; i++) {
      if (textToRead[i] != _text[_offset + i]) {
        return false;
      }
    }

    _offset += textToRead.length;

    return true;
  }

  void expect(String expectedStr) {
    if (!tryRead(expectedStr)) {
      expect(false, expectedStr);
    }
  }

  void expect(bool condition, [String message]) {
    if (!condition) {
      if (message == null) {
        message = 'Unexpected token';
      } else {
        message = 'Expected $message';
      }
      message += ' at offset $_offset';

      throw Exception(message);
    }
  }

  void skipWhitespace() {
    while (_offset < _text.length) {
      String c = _text[_offset];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        _offset++;
      } else {
        break;
      }
    }
  }
}
