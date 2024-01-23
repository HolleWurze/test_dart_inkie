import 'CommandType.dart';
import 'ListDefinition.dart';
import 'SimpleJsonWriter.dart';
import 'ListValue.dart';
import 'Container.dart';
import 'Divert.dart';
import 'PushPopType.dart';
import 'ChoicePoint.dart';
import 'ControlCommand.dart';
import 'Glue.dart';
import 'Tag.dart';
import 'Choice.dart';
import 'Void.dart';
import 'NativeFunctionCall.dart';

class JsonSerialisation {
  static List<T> jArrayToRuntimeObjList<T extends Object>(List<Object> jArray,
      {bool skipLast = false}) {
    int count = jArray.length;
    if (skipLast) count--;

    var list = <T>[];

    for (int i = 0; i < count; i++) {
      var jTok = jArray[i];
      var runtimeObj = jTokenToRuntimeObject(jTok) as T;
      list.add(runtimeObj);
    }

    return list;
  }

  static List<Object> jArrayToRuntimeObjList(List<Object> jArray,
      {bool skipLast = false}) {
    return jArrayToRuntimeObjList<Object>(jArray, skipLast: skipLast);
  }

  static void writeDictionaryRuntimeObjs(SimpleJsonWriter writer,
      Map<String, Object> dictionary) {
    writer.writeObjectStart();
    for (var keyVal in dictionary.entries) {
      writer.writePropertyStart(keyVal.key);
      writeRuntimeObject(writer, keyVal.value);
      writer.writePropertyEnd();
    }
    writer.writeObjectEnd();
  }

  static void writeListRuntimeObjs(SimpleJsonWriter writer, List<Object> list) {
    writer.writeArrayStart();
    for (var val in list) {
      writeRuntimeObject(writer, val);
    }
    writer.writeArrayEnd();
  }

  static void writeIntDictionary(SimpleJsonWriter writer,
      Map<String, int> dict) {
    writer.writeObjectStart();
    for (var keyVal in dict.entries)
      writer.writeProperty(keyVal.key, keyVal.value);
    writer.writeObjectEnd();
  }

  static void writeRuntimeObject(SimpleJsonWriter writer, RuntimeObject obj) {
    if (obj is Container) {
      writeRuntimeContainer(writer, obj);
      return;
    }

    if (obj is Divert) {
      var divert = obj as Divert;
      String divTypeKey = "->";
      if (divert.isExternal) divTypeKey = "x()";
      if (divert.pushesToStack) {
        if (divert.stackPushType == PushPopType.function)
          divTypeKey = "f()";
        else
        if (divert.stackPushType == PushPopType.tunnel) divTypeKey = "->t->";
      }

      String targetStr;
      if (divert.hasVariableTarget)
        targetStr = divert.variableDivertName;
      else
        targetStr = divert.targetPathString;

      writer.writeObjectStart();

      writer.writeProperty(divTypeKey, targetStr);

      if (divert.hasVariableTarget) writer.writeProperty("var", true);

      if (divert.isConditional) writer.writeProperty("c", true);

      if (divert.externalArgs > 0) writer.writeProperty(
          "exArgs", divert.externalArgs);

      writer.writeObjectEnd();
      return;
    }

    if (obj is ChoicePoint) {
      var choicePoint = obj as ChoicePoint;
      writer.writeObjectStart();
      writer.writeProperty("*", choicePoint.pathStringOnChoice);
      writer.writeProperty("flg", choicePoint.flags);
      writer.writeObjectEnd();
      return;
    }

    if (obj is BoolValue) {
      writer.write((obj as BoolValue).value);
      return;
    }

    if (obj is IntValue) {
      writer.write((obj as IntValue).value);
      return;
    }

    if (obj is FloatValue) {
      writer.write((obj as FloatValue).value);
      return;
    }

    if (obj is StringValue) {
      var strVal = obj as StringValue;
      if (strVal.isNewline)
        writer.write("\\n", escape: false);
      else {
        writer.writeStringStart();
        writer.writeStringInner("^");
        writer.writeStringInner(strVal.value);
        writer.writeStringEnd();
      }
      return;
    }

    if (obj is ListValue) {
      writeInkList(writer, obj as ListValue);
      return;
    }

    if (obj is DivertTargetValue) {
      writer.writeObjectStart();
      writer.writeProperty(
          "^->", (obj as DivertTargetValue).value.componentsString);
      writer.writeObjectEnd();
      return;
    }

    if (obj is VariablePointerValue) {
      writer.writeObjectStart();
      writer.writeProperty("^var", (obj as VariablePointerValue).value);
      writer.writeProperty("ci", (obj as VariablePointerValue).contextIndex);
      writer.writeObjectEnd();
      return;
    }

    if (obj is Glue) {
      writer.write("<>");
      return;
    }

    if (obj is ControlCommand) {
      writer.write(
          ControlCommandNames[(obj as ControlCommand).commandType.index]);
      return;
    }

    if (obj is NativeFunctionCall) {
      var name = (obj as NativeFunctionCall).name;

      if (name == "^") name = "L^";

      writer.write(name);
      return;
    }

    if (obj is VariableReference) {
      writer.writeObjectStart();

      String readCountPath = (obj as VariableReference).pathStringForCount;
      if (readCountPath != null)
        writer.writeProperty("CNT?", readCountPath);
      else
        writer.writeProperty("VAR?", (obj as VariableReference).name);

      writer.writeObjectEnd();
      return;
    }

    if (obj is VariableAssignment) {
      writer.writeObjectStart();

      String key = (obj as VariableAssignment).isGlobal ? "VAR=" : "temp=";
      writer.writeProperty(key, (obj as VariableAssignment).variableName);

      if (!(obj as VariableAssignment).isNewDeclaration) writer.writeProperty(
          "re", true);

      writer.writeObjectEnd();

      return;
    }

    if (obj is Void) {
      writer.write("void");
      return;
    }

    if (obj is Tag) {
      writer.writeObjectStart();
      writer.writeProperty("#", (obj as Tag).text);
      writer.writeObjectEnd();
      return;
    }

    if (obj is Choice) {
      writeChoice(writer, obj as Choice);
      return;
    }

    throw Exception("Failed to write runtime object to JSON: $obj");
  }

  static Map<String, Object> jObjectToDictionaryRuntimeObjs(
      Map<String, Object> jObject) {
    var dict = <String, Object>{};

    for (var keyVal in jObject.entries) {
      dict[keyVal.key] = jTokenToRuntimeObject(keyVal.value);
    }

    return dict;
  }

  static Map<String, int> jObjectToIntDictionary(Map<String, Object> jObject) {
    var dict = <String, int>{};
    for (var keyVal in jObject.entries) {
      dict[keyVal.key] = keyVal.value as int;
    }
    return dict;
  }

  static RuntimeObject jTokenToRuntimeObject(Object token) {
    if (token is int || token is double || token is bool) {
      return Value.create(token);
    }

    if (token is String) {
      String str = token as String;

      String firstChar = str[0];
      if (firstChar == '^') return StringValue(str.substring(1));
      if (firstChar == '\n' && str.length == 1) return StringValue("\n");

      if (str == "<>") return Glue();

      for (int i = 0; i < ControlCommandNames.length; ++i) {
        String cmdName = ControlCommandNames[i];
        if (str == cmdName) {
          return ControlCommand(ControlCommandType.values[i]);
        }
      }

      if (str == "L^") str = "^";
      if (NativeFunctionCall.callExistsWithName(str)) {
        return NativeFunctionCall.callWithName(str);
      }

      if (str == "->->")
        return ControlCommand(PushPopType.popTunnel as CommandType);
      if (str == "~ret")
        return ControlCommand(PushPopType.popFunction as CommandType);

      if (str == "void") return Void();
    }

    if (token is Map<String, Object>) {
      Map<String, Object> obj = token as Map<String, Object>;
      Object propValue;

      if (obj.containsKey("^->"))
        return DivertTargetValue(Path(obj["^->"] as String));

      if (obj.containsKey("^var")) {
        VariablePointerValue varPtr = VariablePointerValue(
            obj["^var"] as String);
        if (obj.containsKey("ci")) varPtr.contextIndex = obj["ci"] as int;
        return varPtr;
      }

      bool isDivert = false;
      bool pushesToStack = false;
      PushPopType divPushType = PushPopType.Function;
      bool external = false;
      if (obj.containsKey("->")) {
        isDivert = true;
      } else if (obj.containsKey("f()")) {
        isDivert = true;
        pushesToStack = true;
        divPushType = PushPopType.Function;
      } else if (obj.containsKey("->t->")) {
        isDivert = true;
        pushesToStack = true;
        divPushType = PushPopType.Tunnel;
      } else if (obj.containsKey("x()")) {
        isDivert = true;
        external = true;
        pushesToStack = false;
        divPushType = PushPopType.Function;
      }
      if (isDivert) {
        Divert divert = Divert();
        divert.pushesToStack = pushesToStack;
        divert.stackPushType = divPushType;
        divert.isExternal = external;

        String target = obj["->"] ?? obj["f()"] ?? obj["->t->"] ?? obj["x()"];

        if (obj.containsKey("var"))
          divert.variableDivertName = target;
        else
          divert.targetPathString = target;

        divert.isConditional = obj.containsKey("c");

        if (external) {
          if (obj.containsKey("exArgs"))
            divert.externalArgs = obj["exArgs"] as int;
        }

        return divert;
      }

      if (obj.containsKey("*")) {
        ChoicePoint choice = ChoicePoint();
        choice.pathStringOnChoice = obj["*"] as String;

        if (obj.containsKey("flg")) choice.flags = obj["flg"] as int;

        return choice;
      }

      if (obj.containsKey("VAR?")) {
        return VariableReference(obj["VAR?"] as String);
      } else if (obj.containsKey("CNT?")) {
        VariableReference readCountVarRef = VariableReference();
        readCountVarRef.pathStringForCount = obj["CNT?"] as String;
        return readCountVarRef;
      }

      bool isVarAss = false;
      bool isGlobalVar = false;
      if (obj.containsKey("VAR=")) {
        isVarAss = true;
        isGlobalVar = true;
      } else if (obj.containsKey("temp=")) {
        isVarAss = true;
        isGlobalVar = false;
      }
      if (isVarAss) {
        String varName = obj["VAR="] ?? obj["temp="];
        bool isNewDecl = !obj.containsKey("re");
        VariableAssignment varAss = VariableAssignment(varName, isNewDecl);
        varAss.isGlobal = isGlobalVar;
        return varAss;
      }

      if (obj.containsKey("#")) {
        return Tag(obj["#"] as String);
      }

      if (obj.containsKey("list")) {
        Map<String, Object> listContent = obj["list"] as Map<String, Object>;
        InkList rawList = InkList();
        if (obj.containsKey("origins")) {
          List<String> namesAsObjs = obj["origins"] as List<String>;
          rawList.setInitialOriginNames(namesAsObjs);
        }
        for (var nameToVal in listContent.entries) {
          InkListItem item = InkListItem(nameToVal.key);
          int val = nameToVal.value as int;
          rawList.add(item, val);
        }
        return ListValue(rawList);
      }

      if (obj.containsKey("originalChoicePath")) return jsonObjectToChoice(obj);
    }

    if (token is List<Object>) {
      return jArrayToContainer(token as List<Object>);
    }

    if (token == null) return null;

    throw Exception("Failed to convert token to runtime object: $token");
  }

  void writeRuntimeContainer(SimpleJsonWriter writer, Container container,
      {bool withoutName = false}) {
    writer.writeArrayStart();

    for (var c in container.content) {
      writeRuntimeObject(writer, c);
    }

    // Container is always an array [...]
    // But the final element is always either:
    //  - a dictionary containing the named content, as well as possibly
    //    the key "#" with the count flags
    //  - null, if neither of the above
    var namedOnlyContent = container.namedOnlyContent;
    var countFlags = container.countFlags;
    var hasNameProperty = container.name != null && !withoutName;

    bool hasTerminator = namedOnlyContent != null || countFlags > 0 ||
        hasNameProperty;

    if (hasTerminator) {
      writer.writeObjectStart();
    }

    if (namedOnlyContent != null) {
      namedOnlyContent.forEach((name, namedContent) {
        writer.writePropertyStart(name);
        writeRuntimeContainer(writer, namedContent, withoutName: true);
        writer.writePropertyEnd();
      });
    }

    if (countFlags > 0) {
      writer.writeProperty("#f", countFlags);
    }

    if (hasNameProperty) {
      writer.writeProperty("#n", container.name);
    }

    if (hasTerminator) {
      writer.writeObjectEnd();
    } else {
      writer.writeNull();
    }

    writer.writeArrayEnd();
  }

  Container jArrayToContainer(List<Object> jArray) {
    var container = Container();
    container.content = jArrayToRuntimeObjList(jArray, skipLast: true);

    // Final object in the array is always a combination of
    //  - named content
    //  - a "#f" key with the countFlags
    // (if either exists at all, otherwise null)
    var terminatingObj = jArray[jArray.length - 1] as Map<String, Object>?;
    if (terminatingObj != null) {
      var namedOnlyContent = <String, RuntimeObject>{};

      terminatingObj.forEach((key, value) {
        if (key == "#f") {
          container.countFlags = value as int;
        } else if (key == "#n") {
          container.name = value.toString();
        } else {
          var namedContentItem = jTokenToRuntimeObject(value);
          var namedSubContainer = namedContentItem as Container?;
          if (namedSubContainer != null) {
            namedSubContainer.name = key;
          }
          namedOnlyContent[key] = namedContentItem;
        }
      });

      container.namedOnlyContent = namedOnlyContent;
    }

    return container;
  }

  Choice jObjectToChoice(Map<String, Object> jObj) {
    var choice = Choice();
    choice.text = jObj["text"].toString();
    choice.index = jObj["index"] as int;
    choice.sourcePath = jObj["originalChoicePath"].toString();
    choice.originalThreadIndex = jObj["originalThreadIndex"] as int;
    choice.pathStringOnChoice = jObj["targetPath"].toString();
    return choice;
  }

  void writeChoice(SimpleJsonWriter writer, Choice choice) {
    writer.writeObjectStart();
    writer.writeProperty("text", choice.text);
    writer.writeProperty("index", choice.index);
    writer.writeProperty("originalChoicePath", choice.sourcePath);
    writer.writeProperty("originalThreadIndex", choice.originalThreadIndex);
    writer.writeProperty("targetPath", choice.pathStringOnChoice);
    writer.writeObjectEnd();
  }

  void writeInkList(SimpleJsonWriter writer, ListValue listVal) {
    var rawList = listVal.value;

    writer.writeObjectStart();
    writer.writePropertyStart("list");
    writer.writeObjectStart();

    rawList.forEach((itemAndValue) {
      var item = itemAndValue.key;
      int itemVal = itemAndValue.value;

      writer.writePropertyNameStart();
      writer.writePropertyNameInner(item.originName ?? "?");
      writer.writePropertyNameInner(".");
      writer.writePropertyNameInner(item.itemName);
      writer.writePropertyNameEnd();

      writer.write(itemVal);

      writer.writePropertyEnd();
    });

    writer.writeObjectEnd();
    writer.writePropertyEnd();

    if (rawList.isEmpty && rawList.originNames != null &&
        rawList.originNames.isNotEmpty) {
      writer.writePropertyStart("origins");
      writer.writeArrayStart();
      rawList.originNames.forEach((name) {
        writer.write(name);
      });
      writer.writeArrayEnd();
      writer.writePropertyEnd();
    }

    writer.writeObjectEnd();
  }

  ListDefinitionsOrigin jTokenToListDefinitions(Object obj) {
    var defsObj = obj as Map<String, Object>;

    var allDefs = <ListDefinition>[];

    defsObj.forEach((key, value) {
      var name = key;
      var listDefJson = value as Map<String, Object>;

      var items = <String, int>{};
      listDefJson.forEach((nameValueKey, nameValueValue) {
        items[nameValueKey] = nameValueValue as int;
      });

      var def = ListDefinition(name, items);
      allDefs.add(def);
    });

    return ListDefinitionsOrigin(allDefs);
  }
  }
