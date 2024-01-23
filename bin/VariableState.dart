import 'dart:collection';
import 'CallStack.dart';
import 'ListDefinitionsOrigin.dart';
import 'StatePatch.dart';
import 'CallStack.dart';
import 'StoryException.dart';
import 'ListDefinitionsOrigin.dart';



class VariablesState extends Iterable<String> {
  VariablesState(CallStack callStack, ListDefinitionsOrigin listDefsOrigin) {
    _globalVariables = <String, Object>{};
    _callStack = callStack;
    _listDefsOrigin = listDefsOrigin;
  }

  final Map<String, Object> _globalVariables;
  Map<String, Object> _defaultGlobalVariables;
  CallStack _callStack;
  HashSet<String> _changedVariablesForBatchObs;
  ListDefinitionsOrigin _listDefsOrigin;
  StatePatch patch;
  bool _batchObservingVariableChanges = false;

  bool get batchObservingVariableChanges {
    return _batchObservingVariableChanges;
  }

  set batchObservingVariableChanges(bool value) {
    _batchObservingVariableChanges = value;
    if (value) {
      _changedVariablesForBatchObs = HashSet<String>();
    } else {
      if (_changedVariablesForBatchObs != null) {
        for (var variableName in _changedVariablesForBatchObs) {
          var currentValue = _globalVariables[variableName];
          variableChangedEvent(variableName, currentValue);
        }
      }
      _changedVariablesForBatchObs = null;
    }
  }

  CallStack get callStack {
    return _callStack;
  }

  set callStack(CallStack value) {
    _callStack = value;
  }

  Object operator [](String variableName) {
    Object varContents;

    if (patch != null && patch.tryGetGlobal(variableName, varContents)) {
      return (varContents as Value).valueObject;
    }

    if (_globalVariables.containsKey(variableName) ||
        _defaultGlobalVariables.containsKey(variableName)) {
      return (_globalVariables[variableName] as Value).valueObject;
    } else {
      return null;
    }
  }

  setItem(String variableName, Object value) {
    if (!_defaultGlobalVariables.containsKey(variableName)) {
      throw StoryException(
          "Cannot assign to a variable ($variableName) that hasn't been declared in the story");
    }

    var val = Value.create(value);
    if (val == null) {
      if (value == null) {
        throw Exception("Cannot pass null to VariableState");
      } else {
        throw Exception("Invalid value passed to VariableState: $value");
      }
    }

    setGlobal(variableName, val);
  }

  @override
  Iterator<String> get iterator {
    return _globalVariables.keys.iterator;
  }

  void applyPatch() {
    for (var namedVar in patch.globals) {
      _globalVariables[namedVar.key] = namedVar.value;
    }

    if (_changedVariablesForBatchObs != null) {
      for (var name in patch.changedVariables) {
        _changedVariablesForBatchObs.add(name);
      }
    }

    patch = null;
  }

  void setJsonToken(Map<String, Object> jToken) {
    _globalVariables.clear();

    for (var varVal in _defaultGlobalVariables.entries) {
      Object loadedToken;
      if (jToken.containsKey(varVal.key)) {
        loadedToken = jToken[varVal.key];
        _globalVariables[varVal.key] = Json.jTokenToRuntimeObject(loadedToken);
      } else {
        _globalVariables[varVal.key] = varVal.value;
      }
    }
  }

  void writeJson(SimpleJsonWriter writer) {
    writer.writeObjectStart();
    for (var keyVal in _globalVariables.entries) {
      var name = keyVal.key;
      var val = keyVal.value;

      if (dontSaveDefaultValues) {
        // Don't write out values that are the same as the default global values
        Object defaultVal;
        if (_defaultGlobalVariables != null &&
            _defaultGlobalVariables.containsKey(name)) {
          defaultVal = _defaultGlobalVariables[name];
          if (runtimeObjectsEqual(val, defaultVal)) {
            continue;
          }
        }
      }

      writer.writePropertyStart(name);
      Json.writeRuntimeObject(writer, val);
      writer.writePropertyEnd();
    }
    writer.writeObjectEnd();
  }

  bool runtimeObjectsEqual(Object obj1, Object obj2) {
    if (obj1.runtimeType != obj2.runtimeType) return false;

    // Perform equality on int/float/bool manually to avoid boxing
    if (obj1 is BoolValue) {
      return (obj1 as BoolValue).value == (obj2 as BoolValue).value;
    }

    if (obj1 is IntValue) {
      return (obj1 as IntValue).value == (obj2 as IntValue).value;
    }

    if (obj1 is FloatValue) {
      return (obj1 as FloatValue).value == (obj2 as FloatValue).value;
    }

    // Other Value type (using proper Equals: list, string, divert path)
    if (obj1 is Value) {
      return (obj1 as Value).valueObject ==
          (obj2 as Value).valueObject;
    }

    throw Exception(
        "FastRoughDefinitelyEquals: Unsupported runtime object type: ${obj1.runtimeType}");
  }

  Object getVariableWithName(String name) {
    return getVariableWithName(name, -1);
  }

  Object tryGetDefaultVariableValue(String name) {
    Object val = null;
    _defaultGlobalVariables.containsKey(name) ??
        val = _defaultGlobalVariables[name];
    return val;
  }

  bool globalVariableExistsWithName(String name) {
    return _globalVariables.containsKey(name) ||
        (_defaultGlobalVariables != null &&
            _defaultGlobalVariables.containsKey(name));
  }

  Object getVariableWithName(String name, int contextIndex) {
    Object varValue = getRawVariableWithName(name, contextIndex);

    // Get value from pointer?
    var varPointer = varValue as VariablePointerValue;
    if (varPointer != null) {
      varValue = valueAtVariablePointer(varPointer);
    }

    return varValue;
  }

  Object getRawVariableWithName(String name, int contextIndex) {
    Object varValue = null;

    // 0 context = global
    if (contextIndex == 0 || contextIndex == -1) {
      if (patch != null && patch.tryGetGlobal(name, varValue)) {
        return varValue;
      }

      if (_globalVariables.containsKey(name) ||
          _defaultGlobalVariables.containsKey(name)) {
        return _globalVariables.containsKey(name)
            ? _globalVariables[name]
            : _defaultGlobalVariables[name];
      } else {
        var listItemValue = _listDefsOrigin.findSingleItemListWithName(name);
        if (listItemValue != null) {
          return listItemValue;
        }
      }
    }

    // Temporary
    varValue = _callStack.getTemporaryVariableWithName(name, contextIndex);

    return varValue;
  }

  Object valueAtVariablePointer(VariablePointerValue pointer) {
    return getVariableWithName(pointer.variableName, pointer.contextIndex);
  }

  void assign(VariableAssignment varAss, Object value) {
    var name = varAss.variableName;
    int contextIndex = -1;

    // Are we assigning to a global variable?
    bool setGlobal = false;
    if (varAss.isNewDeclaration) {
      setGlobal = varAss.isGlobal;
    } else {
      setGlobal = globalVariableExistsWithName(name);
    }

    // Constructing new variable pointer reference
    if (varAss.isNewDeclaration) {
      var varPointer = value as VariablePointerValue;
      if (varPointer != null) {
        var fullyResolvedVariablePointer = resolveVariablePointer(varPointer);
        value = fullyResolvedVariablePointer;
      }
    }

    // Assign to existing variable pointer?
    // Then assign to the variable that the pointer is pointing to by name.
    else {
      // De-reference variable reference to point to
      VariablePointerValue existingPointer = null;
      do {
        existingPointer = getRawVariableWithName(name, contextIndex) as VariablePointerValue;
        if (existingPointer != null) {
          name = existingPointer.variableName;
          contextIndex = existingPointer.contextIndex;
          setGlobal = (contextIndex == 0);
        }
      } while (existingPointer != null);
    }

    if (setGlobal) {
      setGlobal(name, value);
    } else {
      _callStack.setTemporaryVariable(name, value, varAss.isNewDeclaration, contextIndex);
    }
  }

  void snapshotDefaultGlobals() {
    _defaultGlobalVariables = Map<String, Object>.from(_globalVariables);
  }

  void retainListOriginsForAssignment(Object oldValue, Object newValue) {
    var oldList = oldValue as ListValue;
    var newList = newValue as ListValue;
    if (oldList != null && newList != null && newList.value.isEmpty) {
      newList.value.setInitialOriginNames(oldList.value.originNames);
    }
  }

  void setGlobal(String variableName, Object value) {
    Object oldValue;
    if (patch == null || !patch.tryGetGlobal(variableName, oldValue)) {
      oldValue = _globalVariables.containsKey(variableName)
          ? _globalVariables[variableName]
          : null;
    }

    retainListOriginsForAssignment(oldValue, value);

    if (patch != null) {
      patch.setGlobal(variableName, value);
    } else {
      _globalVariables[variableName] = value;
    }

    if (variableChangedEvent != null && value != oldValue) {
      if (batchObservingVariableChanges) {
        if (patch != null) {
          patch.addChangedVariable(variableName);
        } else if (_changedVariablesForBatchObs != null) {
          _changedVariablesForBatchObs.add(variableName);
        }
      } else {
        variableChangedEvent(variableName, value);
      }
    }
  }

  VariablePointerValue resolveVariablePointer(VariablePointerValue varPointer) {
    int contextIndex = varPointer.contextIndex;

    if (contextIndex == -1) contextIndex = getContextIndexOfVariableNamed(varPointer.variableName);

    var valueOfVariablePointedTo = getRawVariableWithName(varPointer.variableName, contextIndex);

    // Extra layer of indirection:
    // When accessing a pointer to a pointer (e.g. when calling nested or
    // recursive functions that take a variable references, ensure we don't create
    // a chain of indirection by just returning the final target.
    var doubleRedirectionPointer = valueOfVariablePointedTo as VariablePointerValue;
    if (doubleRedirectionPointer != null) {
      return doubleRedirectionPointer;
    } else {
      return VariablePointerValue(varPointer.variableName, contextIndex);
    }
  }

  int getContextIndexOfVariableNamed(String varName) {
    if (globalVariableExistsWithName(varName)) return 0;
    return _callStack.currentElementIndex;
  }
}
