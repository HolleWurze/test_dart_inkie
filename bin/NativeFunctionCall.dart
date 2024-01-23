import 'InkListItem.dart';
import 'Void.dart';
import 'StoryException.dart';

class NativeFunctionCall extends Object {
  static const String Add = "+";
  static const String Subtract = "-";
  static const String Divide = "/";
  static const String Multiply = "*";
  static const String Mod = "%";
  static const String Negate = "_"; // distinguish from "-" for subtraction

  static const String Equal = "==";
  static const String Greater = ">";
  static const String Less = "<";
  static const String GreaterThanOrEquals = ">=";
  static const String LessThanOrEquals = "<=";
  static const String NotEquals = "!=";
  static const String Not = "!";

  static const String And = "&&";
  static const String Or = "||";

  static const String Min = "MIN";
  static const String Max = "MAX";

  static const String Pow = "POW";
  static const String Floor = "FLOOR";
  static const String Ceiling = "CEILING";
  static const String Int = "INT";
  static const String Float = "FLOAT";

  static const String Has = "?";
  static const String Hasnt = "!?";
  static const String Intersect = "^";

  static const String ListMin = "LIST_MIN";
  static const String ListMax = "LIST_MAX";
  static const String All = "LIST_ALL";
  static const String Count = "LIST_COUNT";
  static const String ValueOfList = "LIST_VALUE";
  static const String Invert = "LIST_INVERT";

  static Map<String, NativeFunctionCall> _nativeFunctions;

  String _name;
  int _numberOfParameters;
  NativeFunctionCall _prototype;
  bool _isPrototype;

  NativeFunctionCall(String name) {
    generateNativeFunctionsIfNecessary();

    this.name = name;
  }

  void generateNativeFunctionsIfNecessary() {
    if (_nativeFunctions == null) {
      _nativeFunctions = {};

      // Why no bool operations?
      // Before evaluation, all bools are coerced to ints in
      // CoerceValuesToSingleType (see default value for valType at top).
      // So, no operations are ever directly done in bools themselves.
      // This also means that 1 == true works, since true is always converted
      // to 1 first.
      // However, many operations return a "native" bool (equals, etc).

      // Int operations
      addIntBinaryOp(Add, (x, y) => x + y);
      addIntBinaryOp(Subtract, (x, y) => x - y);
      addIntBinaryOp(Multiply, (x, y) => x * y);
      addIntBinaryOp(Divide, (x, y) => x / y);
      addIntBinaryOp(Mod, (x, y) => x % y);
      addIntUnaryOp(Negate, (x) => -x);

      addIntBinaryOp(Equal, (x, y) => x == y);
      addIntBinaryOp(Greater, (x, y) => x > y);
      addIntBinaryOp(Less, (x, y) => x < y);
      addIntBinaryOp(GreaterThanOrEquals, (x, y) => x >= y);
      addIntBinaryOp(LessThanOrEquals, (x, y) => x <= y);
      addIntBinaryOp(NotEquals, (x, y) => x != y);
      addIntUnaryOp(Not, (x) => x == 0);

      addIntBinaryOp(And, (x, y) => x != 0 && y != 0);
      addIntBinaryOp(Or, (x, y) => x != 0 || y != 0);

      addIntBinaryOp(Max, (x, y) => max(x, y));
      addIntBinaryOp(Min, (x, y) => min(x, y));

      // Have to cast to float since you could do POW(2, -1)
      addIntBinaryOp(Pow, (x, y) => pow(x, y).toDouble());
      addIntUnaryOp(Floor, (x) => x.toDouble());
      addIntUnaryOp(Ceiling, (x) => x.toDouble());
      addIntUnaryOp(Int, (x) => x.toInt());
      addIntUnaryOp(Float, (x) => x.toDouble());

      // Float operations
      addFloatBinaryOp(Add, (x, y) => x + y);
      addFloatBinaryOp(Subtract, (x, y) => x - y);
      addFloatBinaryOp(Multiply, (x, y) => x * y);
      addFloatBinaryOp(Divide, (x, y) => x / y);
      addFloatBinaryOp(Mod, (x, y) => x % y); // TODO: Is this the operation we want for floats?
      addFloatUnaryOp(Negate, (x) => -x);

      addFloatBinaryOp(Equal, (x, y) => x == y);
      addFloatBinaryOp(Greater, (x, y) => x > y);
      addFloatBinaryOp(Less, (x, y) => x < y);
      addFloatBinaryOp(GreaterThanOrEquals, (x, y) => x >= y);
      addFloatBinaryOp(LessThanOrEquals, (x, y) => x <= y);
      addFloatBinaryOp(NotEquals, (x, y) => x != y);
      addFloatUnaryOp(Not, (x) => x == 0.0);

      addFloatBinaryOp(And, (x, y) => x != 0.0 && y != 0.0);
      addFloatBinaryOp(Or, (x, y) => x != 0.0 || y != 0.0);

      addFloatBinaryOp(Max, (x, y) => max(x, y));
      addFloatBinaryOp(Min, (x, y) => min(x, y));

      addFloatBinaryOp(Pow, (x, y) => pow(x, y));
      addFloatUnaryOp(Floor, (x) => floor(x));
      addFloatUnaryOp(Ceiling, (x) => ceil(x));
      addFloatUnaryOp(Int, (x) => x.toInt());
      addFloatUnaryOp(Float, (x) => x);

      // String operations
      addStringBinaryOp(Add, (x, y) => x + y); // concat
      addStringBinaryOp(Equal, (x, y) => x == y);
      addStringBinaryOp(NotEquals, (x, y) => x != y);
      addStringBinaryOp(Has, (x, y) => x.contains(y));
      addStringBinaryOp(Hasnt, (x, y) => !x.contains(y));

      // List operations
      addListBinaryOp(Add, (x, y) => x.union(y));
      addListBinaryOp(Subtract, (x, y) => x.without(y));
      addListBinaryOp(Has, (x, y) => x.contains(y));
      addListBinaryOp(Hasnt, (x, y) => !x.contains(y));
      addListBinaryOp(Intersect, (x, y) => x.intersect(y));

      addListBinaryOp(Equal, (x, y) => x.equals(y));
      addListBinaryOp(Greater, (x, y) => x.greaterThan(y));
      addListBinaryOp(Less, (x, y) => x.lessThan(y));
      addListBinaryOp(GreaterThanOrEquals, (x, y) => x.greaterThanOrEquals(y));
      addListBinaryOp(LessThanOrEquals, (x, y) => x.lessThanOrEquals(y));
      addListBinaryOp(NotEquals, (x, y) => !x.equals(y));

      addListBinaryOp(And, (x, y) => x.count > 0 && y.count > 0);
      addListBinaryOp(Or, (x, y) => x.count > 0 || y.count > 0);

      addListUnaryOp(Not, (x) => x.count == 0 ? 1 : 0);

      // Placeholders to ensure that these special case functions can exist,
      // since these function is never actually run, and is special cased in Call
      addListUnaryOp(Invert, (x) => x.inverse);
      addListUnaryOp(All, (x) => x.all);
      addListUnaryOp(ListMin, (x) => x.minAsList());
      addListUnaryOp(ListMax, (x) => x.maxAsList());
      addListUnaryOp(Count, (x) => x.count);
      addListUnaryOp(ValueOfList, (x) => x.maxItem.value);

      // Special case: The only operations you can do on divert target values
      BinaryOp<Path> divertTargetsEqual = (d1, d2) {
        return d1.equals(d2);
      };
      BinaryOp<Path> divertTargetsNotEqual = (d1, d2) {
        return !d1.equals(d2);
      };
      addOpToNativeFunc(Equal, 2, ValueType.DivertTarget, divertTargetsEqual);
      addOpToNativeFunc(NotEquals, 2, ValueType.DivertTarget, divertTargetsNotEqual);
    }
  }

  void addOpFuncForType(ValueType valType, dynamic op) {
    if (_operationFuncs == null) {
      _operationFuncs = {};
    }

    _operationFuncs[valType] = op;
  }

  static void addOpToNativeFunc(String name, int args, ValueType valType, dynamic op) {
    NativeFunctionCall nativeFunc = _nativeFunctions[name];

    if (nativeFunc == null) {
      nativeFunc = NativeFunctionCall(name, args);
      _nativeFunctions[name] = nativeFunc;
    }

    nativeFunc.addOpFuncForType(valType, op);
  }

  static void addIntBinaryOp(String name, BinaryOp<int> op) {
    addOpToNativeFunc(name, 2, ValueType.Int, op);
  }

  static void addIntUnaryOp(String name, UnaryOp<int> op) {
    addOpToNativeFunc(name, 1, ValueType.Int, op);
  }

  static void addFloatBinaryOp(String name, BinaryOp<double> op) {
    addOpToNativeFunc(name, 2, ValueType.Float, op);
  }

  static void addStringBinaryOp(String name, BinaryOp<String> op) {
    addOpToNativeFunc(name, 2, ValueType.String, op);
  }

  static void addListBinaryOp(String name, BinaryOp<InkList> op) {
    addOpToNativeFunc(name, 2, ValueType.List, op);
  }

  static void addListUnaryOp(String name, UnaryOp<InkList> op) {
    addOpToNativeFunc(name, 1, ValueType.List, op);
  }

  static void addFloatUnaryOp(String name, UnaryOp<double> op) {
    addOpToNativeFunc(name, 1, ValueType.Float, op);
  }

  Value call<T>(List<Value> parametersOfSingleType) {
    Value param1 = parametersOfSingleType[0];
    ValueType valType = param1.valueType;

    Value<T> val1 = param1 as Value<T>;

    int paramCount = parametersOfSingleType.length;

    if (paramCount == 2 || paramCount == 1) {
      dynamic opForTypeObj = _operationFuncs[valType];

      if (opForTypeObj == null) {
        throw StoryException("Cannot perform operation '$name' on $valType");
      }

      if (paramCount == 2) {
        Value param2 = parametersOfSingleType[1];

        Value<T> val2 = param2 as Value<T>;

        dynamic opForType = opForTypeObj as BinaryOp<T>;

        dynamic resultVal = opForType(val1.value, val2.value);

        return Value.create(resultVal);
      } else {
        dynamic opForType = opForTypeObj as UnaryOp<T>;

        dynamic resultVal = opForType(val1.value);

        return Value.create(resultVal);
      }
    } else {
      throw Exception("Unexpected number of parameters to NativeFunctionCall: ${parametersOfSingleType.length}");
    }
  }

  Value callListIncrementOperation(List<RuntimeObject> parameters) {
    // Implement callListIncrementOperation here
    return null;
  }

  Value callBinaryListOperation(List<RuntimeObject> parameters) {
    // Implement callBinaryListOperation here
    return null;
  }

  List<Value> coerceValuesToSingleType(List<RuntimeObject> parametersIn) {
    ValueType valType = ValueType.Int;

    ListValue specialCaseList;

    for (Value val in parametersIn) {
      if (val.valueType.index > valType.index) {
        valType = val.valueType;
      }

      if (val.valueType == ValueType.List) {
        specialCaseList = val as ListValue;
      }
    }

    List<Value> parametersOut = [];

    if (valType == ValueType.List) {
      for (Value val in parametersIn) {
        if (val.valueType == ValueType.List) {
          parametersOut.add(val);
        } else if (val.valueType == ValueType.Int) {
          int intVal = val.value as int;
          InkList list = specialCaseList.value.originsOfMaxItem;

          InkListItem item;
          if (list.tryGetItemWithValue(intVal, item)) {
            Value castedValue = ListValue(item, intVal);
            parametersOut.add(castedValue);
          } else {
            throw StoryException("Could not find List item with the value $intVal in ${list.name}");
          }
        } else {
          throw StoryException("Cannot mix Lists and ${val.valueType} values in this operation");
        }
      }
    } else {
      for (Value val in parametersIn) {
        Value castedValue = val.cast(valType);
        parametersOut.add(castedValue);
      }
    }

    return parametersOut;
  }

  String get name {
    return _name;
  }

  set name(String value) {
    _name = value;
    if (!_isPrototype) _prototype = _nativeFunctions[_name];
  }

  int get numberOfParameters {
    if (_prototype != null) {
      return _prototype.numberOfParameters;
    } else {
      return _numberOfParameters;
    }
  }

  set numberOfParameters(int value) {
    _numberOfParameters = value;
  }

  Value call(List<Value> parameters) {
    if (_prototype != null) {
      return _prototype.call(parameters);
    }

    if (numberOfParameters != parameters.length) {
      throw Exception("Unexpected number of parameters");
    }

    bool hasList = false;
    for (Value p in parameters) {
      if (p is Void) {
        throw StoryException("Attempting to perform operation on a void value. Did you forget to 'return' a value from a function you called here?");
      }
      if (p is ListValue) {
        hasList = true;
      }
    }

    // Binary operations on lists are treated outside of the standard coercion rules
    if (parameters.length == 2 && hasList) {
      return callBinaryListOperation(parameters);
    }

    List<Value> coercedParams = coerceValuesToSingleType(parameters);
    ValueType coercedType = coercedParams[0].valueType;

    if (coercedType == ValueType.Int) {
      return call<int>(coercedParams);
    } else if (coercedType == ValueType.Float) {
      return call<double>(coercedParams);
    } else if (coercedType == ValueType.String) {
      return call<String>(coercedParams);
    } else if (coercedType == ValueType.DivertTarget) {
      return call<Path>(coercedParams);
    } else if (coercedType == ValueType.List) {
      return call<InkList>(coercedParams);
    }

    return null;
  }

  @override
  String toString() {
    return "Native '$name'";
  }
}

typedef BinaryOp<T> = dynamic Function(T left, T right);
typedef UnaryOp<T> = dynamic Function(T val);
typedef BinaryListOp = Value Function(InkList x, InkList y);
