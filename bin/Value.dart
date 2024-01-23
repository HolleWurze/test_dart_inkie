import 'package:ink_runtime/ink_runtime.dart';

enum ValueType {
  Bool,
  Int,
  Float,
  List,
  String,
  DivertTarget,
  VariablePointer,
}

abstract class Value extends RuntimeObject {
  ValueType get valueType;
  bool get isTruthy;

  Value Cast(ValueType newType);

  Object get valueObject;

  static Value Create(Object val) {
    if (val is double) {
      double doub = val as double;
      val = doub as float;
    }

    if (val is bool) {
      return BoolValue(val as bool);
    } else if (val is int) {
      return IntValue(val as int);
    } else if (val is int) {
      return IntValue((val as int).toInt());
    } else if (val is float) {
      return FloatValue(val as float);
    } else if (val is double) {
      return FloatValue((val as double).toFloat());
    } else if (val is String) {
      return StringValue(val as String);
    } else if (val is Path) {
      return DivertTargetValue(val as Path);
    } else if (val is InkList) {
      return ListValue(val as InkList);
    }

    return null;
  }

  @override
  Object Copy() {
    return Create(valueObject);
  }

  StoryException BadCastException(ValueType targetType) {
    return StoryException("Can't cast ${this.valueObject} from ${this.valueType} to $targetType");
  }
}

abstract class Value<T> extends Value {
  T value;

  Value(this.value);

  @override
  Object get valueObject {
    return value;
  }

  @override
  String toString() {
    return value.toString();
  }
}

class BoolValue extends Value<bool> {
  BoolValue(bool boolVal) : super(boolVal);

  @override
  ValueType get valueType => ValueType.Bool;

  @override
  bool get isTruthy => value;

  @override
  Value Cast(ValueType newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.Int) {
      return IntValue(value ? 1 : 0);
    }

    if (newType == ValueType.Float) {
      return FloatValue(value ? 1.0 : 0.0);
    }

    if (newType == ValueType.String) {
      return StringValue(value ? "true" : "false");
    }

    throw BadCastException(newType);
  }

  @override
  String toString() {
    return value ? "true" : "false";
  }
}

class IntValue extends Value<int> {
  IntValue(int intVal) : super(intVal);

  @override
  ValueType get valueType => ValueType.Int;

  @override
  bool get isTruthy => value != 0;

  @override
  Value Cast(ValueType newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.Bool) {
      return BoolValue(value == 0 ? false : true);
    }

    if (newType == ValueType.Float) {
      return FloatValue(value.toFloat());
    }

    if (newType == ValueType.String) {
      return StringValue(value.toString());
    }

    throw BadCastException(newType);
  }
}

class FloatValue extends Value<float> {
  FloatValue(float val) : super(val);

  @override
  ValueType get valueType => ValueType.Float;

  @override
  bool get isTruthy => value != 0.0;

  @override
  Value Cast(ValueType newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.Bool) {
      return BoolValue(value == 0.0 ? false : true);
    }

    if (newType == ValueType.Int) {
      return IntValue(value.toInt());
    }

    if (newType == ValueType.String) {
      return StringValue(value.toStringAsFixed(8));
    }

    throw BadCastException(newType);
  }
}

class StringValue extends Value<String> {
  bool isNewline;
  bool isInlineWhitespace;

  StringValue(String str) : super(str) {
    isNewline = value == "\n";
    isInlineWhitespace = true;
    for (var c in value.runes) {
      if (c != ' ' && c != '\t') {
        isInlineWhitespace = false;
        break;
      }
    }
  }

  @override
  ValueType get valueType => ValueType.String;

  @override
  bool get isTruthy => value.length > 0;

  @override
  Value Cast(ValueType newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.Int) {
      int parsedInt = int.tryParse(value);
      if (parsedInt != null) {
        return IntValue(parsedInt);
      } else {
        return null;
      }
    }

    if (newType == ValueType.Float) {
      double parsedFloat = double.tryParse(value);
      if (parsedFloat != null) {
        return FloatValue(parsedFloat.toFloat());
      } else {
        return null;
      }
    }

    throw BadCastException(newType);
  }
}

class DivertTargetValue extends Value<Path> {
  DivertTargetValue(Path targetPath) : super(targetPath);

  @override
  ValueType get valueType => ValueType.DivertTarget;

  @override
  bool get isTruthy => throw Exception("Shouldn't be checking the truthiness of a divert target");

  @override
  Value Cast(ValueType newType) {
    if (newType == valueType) {
      return this;
    }

    throw BadCastException(newType);
  }

  @override
  String toString() {
    return "DivertTargetValue(${targetPath.toString()})";
  }
}

class VariablePointerValue extends Value<String> {
  String variableName;
  int contextIndex;

  VariablePointerValue(this.variableName, {this.contextIndex = -1}) : super(variableName);

  @override
  ValueType get valueType => ValueType.VariablePointer;

  @override
  bool get isTruthy => throw Exception("Shouldn't be checking the truthiness of a variable pointer");

  @override
  Value Cast(ValueType newType) {
    if (newType == valueType) {
      return this;
    }

    throw BadCastException(newType);
  }

  @override
  Object Copy() {
    return VariablePointerValue(variableName, contextIndex: contextIndex);
  }

  @override
  Object get valueObject {
    return variableName;
  }
}

class ListValue extends Value<InkList> {
  ListValue() : super(InkList());

  ListValue(InkList list) : super(InkList.from(list));

  ListValue(InkListItem singleItem, int singleValue) : super(InkList(singleItem, singleValue));

  @override
  ValueType get valueType => ValueType.List;

  @override
  bool get isTruthy => value.Count > 0;

  @override
  Value Cast(ValueType newType) {
    if (newType == ValueType.Int) {
      var max = value.maxItem;
      if (max.Key.isNull) {
        return IntValue(0);
      } else {
        return IntValue(max.Value);
      }
    } else if (newType == ValueType.Float) {
      var max = value.maxItem;
      if (max.Key.isNull) {
        return FloatValue(0.0);
      } else {
        return FloatValue(max.Value.toFloat());
      }
    } else if (newType == ValueType.String) {
      var max = value.maxItem;
      if (max.Key.isNull) {
        return StringValue("");
      } else {
        return StringValue(max.Key.toString());
      }
    }

    if (newType == valueType) {
      return this;
    }

    throw BadCastException(newType);
  }

  static void RetainListOriginsForAssignment(Object? oldValue, Object? newValue) {
    var oldList = oldValue as ListValue?;
    var newList = newValue as ListValue?;

    if (oldList != null && newList != null && newList.value.Count == 0) {
      newList.value.SetInitialOriginNames(oldList.value.originNames);
    }
  }
}
