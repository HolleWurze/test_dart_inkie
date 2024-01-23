import 'dart:async';
import 'dart:convert';
import 'Void.dart';
import 'Value.dart';
import 'Container.dart';
import 'Choice.dart';
import 'VariablesState.dart';
import 'Pointer.dart';
import 'ControlCommand.dart';
import 'Glue.dart';


class StoryState {
  static const int kInkSaveStateVersion = 10;
  static const int kMinCompatibleLoadVersion = 8;

  StreamController<void> _onDidLoadStateController = StreamController<
      void>.broadcast();

  Stream<void> get onDidLoadState => _onDidLoadStateController.stream;

  String toJson() {
    final writer = JsonWriter();
    writeJson(writer);
    return writer.toString();
  }

  void toJsonStream(StringSink sink) {
    final writer = JsonWriter(sink);
    writeJson(writer);
  }

  void loadJson(String json) {
    final jObject = jsonDecode(json) as Map<String, dynamic>;
    loadJsonObj(jObject);
    _onDidLoadStateController.add(null);
  }

  int visitCountAtPathString(String pathString) {
    int visitCountOut;

    if (_patch != null) {
      final container = story
          .contentAtPath(Path(pathString))
          .container;
      if (container == null) {
        throw Exception("Content at path not found: $pathString");
      }

      if (_patch.tryGetVisitCount(container, visitCountOut)) {
        return visitCountOut;
      }
    }

    if (_visitCounts.containsKey(pathString)) {
      return _visitCounts[pathString];
    }

    return 0;
  }

  int visitCountForContainer(Container container) {
    if (!container.visitsShouldBeCounted) {
      story.error("Read count for target (${container.name} - on ${container
          .debugMetadata}) unknown.");
      return 0;
    }

    int count = 0;
    if (_patch != null && _patch.tryGetVisitCount(container, count)) {
      return count;
    }

    final containerPathStr = container.path.toString();
    return _visitCounts[containerPathStr] ?? 0;
  }

  void incrementVisitCountForContainer(Container container) {
    if (_patch != null) {
      final currentCount = visitCountForContainer(container);
      _patch.setVisitCount(container, currentCount + 1);
      return;
    }

    final containerPathStr = container.path.toString();
    final currentCount = _visitCounts[containerPathStr] ?? 0;
    _visitCounts[containerPathStr] = currentCount + 1;
  }

  void recordTurnIndexVisitToContainer(Container container) {
    if (_patch != null) {
      _patch.setTurnIndex(container, currentTurnIndex);
      return;
    }

    final containerPathStr = container.path.toString();
    _turnIndices[containerPathStr] = currentTurnIndex;
  }

  int turnsSinceForContainer(Container container) {
    if (!container.turnIndexShouldBeCounted) {
      story.error("TURNS_SINCE() for target (${container.name} - on ${container
          .debugMetadata}) unknown.");
    }

    int index = 0;

    if (_patch != null && _patch.tryGetTurnIndex(container, index)) {
      return currentTurnIndex - index;
    }

    final containerPathStr = container.path.toString();
    final indexValue = _turnIndices[containerPathStr];
    return indexValue != null ? currentTurnIndex - indexValue : -1;
  }

  int get callstackDepth => callStack.depth;

  List<Object> get outputStream => _currentFlow.outputStream;

  List<Choice> get currentChoices {
    if (canContinue) {
      return <Choice>[];
    }
    return _currentFlow.currentChoices;
  }

  List<Choice> get generatedChoices => _currentFlow.currentChoices;

  List<String> get currentErrors => _currentErrors;

  List<String> get currentWarnings => _currentWarnings;

  VariablesState get variablesState => _variablesState;

  CallStack get callStack => _currentFlow.callStack;

  List<Object> get evaluationStack => _evaluationStack;

  Pointer get divertedPointer => _divertedPointer;

  set divertedPointer(Pointer value) {
    _divertedPointer = value;
  }

  int get currentTurnIndex => _currentTurnIndex;

  int get storySeed => _storySeed;

  set storySeed(int value) {
    _storySeed = value;
  }

  int get previousRandom => _previousRandom;

  set previousRandom(int value) {
    _previousRandom = value;
  }

  bool get didSafeExit => _didSafeExit;

  set didSafeExit(bool value) {
    _didSafeExit = value;
  }

  Story get story => _story;

  set story(Story value) {
    _story = value;
  }

  String get currentPathString {
    final pointer = currentPointer;
    if (pointer.isNull) {
      return null;
    } else {
      return pointer.path.toString();
    }
  }

  Pointer get currentPointer => callStack.currentElement.currentPointer;

  set currentPointer(Pointer value) {
    callStack.currentElement.currentPointer = value;
  }

  Pointer get previousPointer => callStack.currentThread.previousPointer;

  set previousPointer(Pointer value) {
    callStack.currentThread.previousPointer = value;
  }

  bool get canContinue => !currentPointer.isNull && !hasError;

  bool get hasError => _currentErrors.isNotEmpty;

  bool get hasWarning => _currentWarnings.isNotEmpty;

  String get currentText {
    if (_outputStreamTextDirty) {
      var sb = StringBuffer();
      bool inTag = false;

      for (var outputObj in outputStream) {
        var textContent = outputObj as StringValue;
        if (!inTag && textContent != null) {
          sb.write(textContent.value);
        } else {
          var controlCommand = outputObj as ControlCommand;
          if (controlCommand != null) {
            if (controlCommand.commandType ==
                ControlCommand.CommandType.BeginTag) {
              inTag = true;
            } else if (controlCommand.commandType ==
                ControlCommand.CommandType.EndTag) {
              inTag = false;
            }
          }
        }
      }

      _currentText = cleanOutputWhitespace(sb.toString());
      _outputStreamTextDirty = false;
    }

    return _currentText;
  }

  String _currentText;

  String cleanOutputWhitespace(String str) {
    var sb = StringBuffer(str.length);
    int currentWhitespaceStart = -1;
    int startOfLine = 0;

    for (int i = 0; i < str.length; i++) {
      var c = str[i];
      bool isInlineWhitespace = c == ' ' || c == '\t';

      if (isInlineWhitespace && currentWhitespaceStart == -1) {
        currentWhitespaceStart = i;
      }

      if (!isInlineWhitespace) {
        if (c != '\n' && currentWhitespaceStart > 0 &&
            currentWhitespaceStart != startOfLine) {
          sb.write(' ');
        }
        currentWhitespaceStart = -1;
      }

      if (c == '\n') {
        startOfLine = i + 1;
      }

      if (!isInlineWhitespace) {
        sb.write(c);
      }
    }

    return sb.toString();
  }

  List<String> get currentTags {
    if (_outputStreamTagsDirty) {
      _currentTags = <String>[];
      bool inTag = false;
      var sb = StringBuffer();

      for (var outputObj in outputStream) {
        var controlCommand = outputObj as ControlCommand;

        if (controlCommand != null) {
          if (controlCommand.commandType ==
              ControlCommand.CommandType.BeginTag) {
            if (inTag && sb.length > 0) {
              var txt = cleanOutputWhitespace(sb.toString());
              _currentTags.add(txt);
              sb.clear();
            }
            inTag = true;
          } else
          if (controlCommand.commandType == ControlCommand.CommandType.EndTag) {
            if (sb.length > 0) {
              var txt = cleanOutputWhitespace(sb.toString());
              _currentTags.add(txt);
              sb.clear();
            }
            inTag = false;
          }
        } else if (inTag) {
          var strVal = outputObj as StringValue;
          if (strVal != null) {
            sb.write(strVal.value);
          }
        } else {
          var tag = outputObj as Tag;
          if (tag != null && tag.text != null && tag.text.isNotEmpty) {
            _currentTags.add(
                tag.text); // tag.text has whitespace already cleaned
          }
        }
      }

      if (sb.length > 0) {
        var txt = cleanOutputWhitespace(sb.toString());
        _currentTags.add(txt);
        sb.clear();
      }

      _outputStreamTagsDirty = false;
    }

    return _currentTags;
  }

  List<String> _currentTags;

  String get currentFlowName => _currentFlow.name;

  bool get currentFlowIsDefaultFlow => _currentFlow.name == kDefaultFlowName;

  List<String> get aliveFlowNames {
    if (_aliveFlowNamesDirty) {
      _aliveFlowNames = <String>[];

      if (_namedFlows != null) {
        for (var flowName in _namedFlows.keys) {
          if (flowName != kDefaultFlowName) {
            _aliveFlowNames.add(flowName);
          }
        }
      }

      _aliveFlowNamesDirty = false;
    }

    return _aliveFlowNames;
  }

  List<String> _aliveFlowNames;

  bool get inExpressionEvaluation =>
      callStack.currentElement.inExpressionEvaluation;

  set inExpressionEvaluation(bool value) {
    callStack.currentElement.inExpressionEvaluation = value;
  }

  StoryState(Story story) {
    this.story = story;
    _currentFlow = Flow(kDefaultFlowName, story);
    outputStreamDirty();
    _aliveFlowNamesDirty = true;
    evaluationStack = <Object>[];
    variablesState = VariablesState(callStack, story.listDefinitions);
    _visitCounts = <String, int>{};
    _turnIndices = <String, int>{};
    currentTurnIndex = -1;
    // Seed the shuffle random numbers
    var timeSeed = DateTime
        .now()
        .millisecond;
    storySeed = Random(timeSeed).nextInt(100);
    previousRandom = 0;
    goToStart();
  }

  void goToStart() {
    callStack.currentElement.currentPointer =
        Pointer.startOf(story.mainContentContainer);
  }

  void switchFlowInternal(String flowName) {
    if (flowName == null) {
      throw Exception("Must pass a non-null string to Story.SwitchFlow");
    }

    if (_namedFlows == null) {
      _namedFlows = <String, Flow>{};
      _namedFlows[kDefaultFlowName] = _currentFlow;
    }

    if (flowName == _currentFlow.name) {
      return;
    }

    Flow flow;
    if (!_namedFlows.containsKey(flowName)) {
      flow = Flow(flowName, story);
      _namedFlows[flowName] = flow;
      _aliveFlowNamesDirty = true;
    }

    _currentFlow = flow;
    variablesState.callStack = _currentFlow.callStack;
    outputStreamDirty();
  }

  void switchToDefaultFlowInternal() {
    if (_namedFlows == null) return;
    switchFlowInternal(kDefaultFlowName);
  }

  void removeFlowInternal(String flowName) {
    if (flowName == null) {
      throw Exception("Must pass a non-null string to Story.DestroyFlow");
    }
    if (flowName == kDefaultFlowName) {
      throw Exception("Cannot destroy default flow");
    }

    // If we're currently in the flow that's being removed, switch back to default
    if (_currentFlow.name == flowName) {
      switchToDefaultFlowInternal();
    }

    _namedFlows.remove(flowName);
    _aliveFlowNamesDirty = true;
  }

  StoryState copyAndStartPatching() {
    var copy = StoryState(story);
    copy._patch = StatePatch(_patch);

    // Hijack the new default flow to become a copy of our current one
    // If the patch is applied, then this new flow will replace the old one in _namedFlows
    copy._currentFlow.name = _currentFlow.name;
    copy._currentFlow.callStack = CallStack(_currentFlow.callStack);
    copy._currentFlow.currentChoices.addAll(_currentFlow.currentChoices);
    copy._currentFlow.outputStream.addAll(_currentFlow.outputStream);
    copy.outputStreamDirty();

    // The copy of the state has its own copy of the named flows dictionary,
    // except with the current flow replaced with the copy above
    // (Assuming we're in multi-flow mode at all. If we're not then
    // the above copy is simply the default flow copy and we're done)
    if (_namedFlows != null) {
      copy._namedFlows = <String, Flow>{};
      for (var namedFlow in _namedFlows.entries) {
        copy._namedFlows[namedFlow.key] = namedFlow.value;
      }
      copy._namedFlows[_currentFlow.name] = copy._currentFlow;
      copy._aliveFlowNamesDirty = true;
    }

    if (hasError) {
      copy.currentErrors = <String>[];
      copy.currentErrors.addAll(currentErrors);
    }
    if (hasWarning) {
      copy.currentWarnings = <String>[];
      copy.currentWarnings.addAll(currentWarnings);
    }

    // ref copy - exactly the same variables state!
    // we're expecting not to read it only while in patch mode
    // (though the callstack will be modified)
    copy.variablesState = variablesState;
    copy.variablesState.callStack = copy.callStack;
    copy.variablesState.patch = copy._patch;

    copy.evaluationStack.addAll(evaluationStack);

    if (!divertedPointer.isNull) {
      copy.divertedPointer = divertedPointer;
    }

    copy.previousPointer = previousPointer;

    // visit counts and turn indices will be read only, not modified
    // while in patch mode
    copy._visitCounts = _visitCounts;
    copy._turnIndices = _turnIndices;

    copy.currentTurnIndex = currentTurnIndex;
    copy.storySeed = storySeed;
    copy.previousRandom = previousRandom;

    copy.didSafeExit = didSafeExit;

    return copy;
  }

  void restoreAfterPatch() {
    // VariablesState was being borrowed by the patched
    // state, so restore it with our own callstack.
    // _patch will be null normally, but if you're in the
    // middle of a save, it may contain a _patch for save purposes.
    variablesState.callStack = callStack;
    variablesState.patch = _patch; // usually null
  }

  void applyAnyPatch() {
    if (_patch == null) return;

    variablesState.applyPatch();

    _patch.visitCounts.forEach((pathToCount) {
      applyCountChanges(pathToCount.key, pathToCount.value, isVisit: true);
    });

    _patch.turnIndices.forEach((pathToIndex) {
      applyCountChanges(pathToIndex.key, pathToIndex.value, isVisit: false);
    });

    _patch = null;
  }

  void applyCountChanges(Container container, int newCount, bool isVisit) {
    var counts = isVisit ? _visitCounts : _turnIndices;
    counts[container.path.toString()] = newCount;
  }

  void writeJson(SimpleJsonWriter writer) {
    writer.writeObjectStart();

    // Flows
    writer.writePropertyStart("flows");
    writer.writeObjectStart();

    // Multi-flow
    if (_namedFlows != null) {
      _namedFlows.forEach((key, value) {
        writer.writeProperty(key, value.writeJson);
      });
    } else {
      writer.writeProperty(_currentFlow.name, _currentFlow.writeJson);
    }

    writer.writeObjectEnd();
    writer.writePropertyEnd(); // end of flows

    writer.writeProperty("currentFlowName", _currentFlow.name);

    writer.writeProperty("variablesState", variablesState.writeJson);

    writer.writeProperty(
        "evalStack", (w) => Json.writeListRuntimeObjs(w, evaluationStack));

    if (!divertedPointer.isNull) {
      writer.writeProperty(
          "currentDivertTarget", divertedPointer.path.componentsString);
    }

    writer.writeProperty(
        "visitCounts", (w) => Json.writeIntDictionary(w, _visitCounts));
    writer.writeProperty(
        "turnIndices", (w) => Json.writeIntDictionary(w, _turnIndices));

    writer.writeProperty("turnIdx", currentTurnIndex);
    writer.writeProperty("storySeed", storySeed);
    writer.writeProperty("previousRandom", previousRandom);

    writer.writeProperty("inkSaveVersion", kInkSaveStateVersion);

    // Not using this right now, but could do in future.
    writer.writeProperty("inkFormatVersion", Story.inkVersionCurrent);

    writer.writeObjectEnd();
  }

  void loadJsonObj(Map<String, dynamic> jObject) {
    var jSaveVersion = jObject["inkSaveVersion"];
    if (jSaveVersion == null) {
      throw Exception("ink save format incorrect, can't load.");
    } else if (jSaveVersion < kMinCompatibleLoadVersion) {
      throw Exception(
          "Ink save format isn't compatible with the current version (saw '$jSaveVersion', but minimum is $kMinCompatibleLoadVersion), so can't load.");
    }

    // Flows: Always exists in latest format (even if there's just one default)
    // but this dictionary doesn't exist in prev format
    var flowsObj = jObject["flows"];
    if (flowsObj != null) {
      var flowsObjDict = flowsObj as Map<String, dynamic>;

      // Single default flow
      if (flowsObjDict.length == 1) _namedFlows = null;

      // Multi-flow, need to create flows dict
      else if (_namedFlows == null) _namedFlows = <String, Flow>{};

      // Multi-flow, already have a flows dict
      else
        _namedFlows.clear();

      // Load up each flow (there may only be one)
      flowsObjDict.forEach((name, flowObj) {
        var flow = Flow(name, story, flowObj as Map<String, dynamic>);

        if (flowsObjDict.length == 1) {
          _currentFlow = Flow(name, story, flowObj);
        } else {
          _namedFlows[name] = flow;
        }
      });

      if (_namedFlows != null && _namedFlows.length > 1) {
        var currFlowName = jObject["currentFlowName"];
        _currentFlow = _namedFlows[currFlowName];
      }
    }

    // Old format: individually load up callstack, output stream, choices in current/default flow
    else {
      _namedFlows = null;
      _currentFlow.name = kDefaultFlowName;
      _currentFlow.callStack.setJsonToken(jObject["callstackThreads"], story);
      _currentFlow.outputStream =
          Json.jArrayToRuntimeObjList(jObject["outputStream"]);
      _currentFlow.currentChoices =
          Json.jArrayToRuntimeObjList<Choice>(jObject["currentChoices"]);

      var jChoiceThreadsObj = jObject["choiceThreads"];
      _currentFlow.loadFlowChoiceThreads(
          jChoiceThreadsObj as Map<String, dynamic>, story);
    }

    outputStreamDirty();
    _aliveFlowNamesDirty = true;

    variablesState.setJsonToken(jObject["variablesState"]);
    variablesState.callStack = _currentFlow.callStack;

    evaluationStack = Json.jArrayToRuntimeObjList(jObject["evalStack"]);

    var currentDivertTargetPath = jObject["currentDivertTarget"];
    if (currentDivertTargetPath != null) {
      var divertPath = Path(currentDivertTargetPath.toString());
      divertedPointer = story.pointerAtPath(divertPath);
    }

    _visitCounts = Json.jObjectToIntDictionary(
        jObject["visitCounts"] as Map<String, dynamic>);
    _turnIndices = Json.jObjectToIntDictionary(
        jObject["turnIndices"] as Map<String, dynamic>);

    currentTurnIndex = jObject["turnIdx"];
    storySeed = jObject["storySeed"];

    // Not optional, but bug in inkjs means it's actually missing in inkjs saves
    var previousRandomObj = jObject["previousRandom"];
    previousRandom = previousRandomObj ?? 0;
  }

  void resetErrors() {
    currentErrors = null;
    currentWarnings = null;
  }

  void resetOutput(List<Object> objs) {
    outputStream.clear();
    if (objs != null) outputStream.addAll(objs);
    outputStreamDirty();
  }

// Push to output stream, but split out newlines in text for consistency
// in dealing with them later.
  void pushToOutputStream(Object obj) {
    var text = obj as StringValue;
    if (text != null) {
      var listText = trySplittingHeadTailWhitespace(text);
      if (listText != null) {
        listText.forEach((textObj) {
          pushToOutputStreamIndividual(textObj);
        });
        outputStreamDirty();
        return;
      }
    }

    pushToOutputStreamIndividual(obj);
    outputStreamDirty();
  }

  void popFromOutputStream(int count) {
    outputStream.removeRange(outputStream.length - count, count);
    outputStreamDirty();
  }

  List<StringValue> trySplittingHeadTailWhitespace(StringValue single) {
    String str = single.value;

    int headFirstNewlineIdx = -1;
    int headLastNewlineIdx = -1;
    for (int i = 0; i < str.length; i++) {
      var c = str[i];
      if (c == '\n') {
        if (headFirstNewlineIdx == -1) headFirstNewlineIdx = i;
        headLastNewlineIdx = i;
      } else if (c == ' ' || c == '\t') {
        continue;
      } else {
        break;
      }
    }

    int tailLastNewlineIdx = -1;
    int tailFirstNewlineIdx = -1;
    for (int i = str.length - 1; i >= 0; i--) {
      var c = str[i];
      if (c == '\n') {
        if (tailLastNewlineIdx == -1) tailLastNewlineIdx = i;
        tailFirstNewlineIdx = i;
      } else if (c == ' ' || c == '\t') {
        continue;
      } else {
        break;
      }
    }

    if (headFirstNewlineIdx == -1 && tailLastNewlineIdx == -1) return null;

    var listTexts = <StringValue>[];
    int innerStrStart = 0;
    int innerStrEnd = str.length;

    if (headFirstNewlineIdx != -1) {
      if (headFirstNewlineIdx > 0) {
        var leadingSpaces = StringValue(str.substring(0, headFirstNewlineIdx));
        listTexts.add(leadingSpaces);
      }
      listTexts.add(StringValue("\n"));
      innerStrStart = headLastNewlineIdx + 1;
    }

    if (tailLastNewlineIdx != -1) {
      innerStrEnd = tailFirstNewlineIdx;
    }

    if (innerStrEnd > innerStrStart) {
      var innerStrText = str.substring(
          innerStrStart, innerStrEnd - innerStrStart);
      listTexts.add(StringValue(innerStrText));
    }

    if (tailLastNewlineIdx != -1 && tailFirstNewlineIdx > headLastNewlineIdx) {
      listTexts.add(StringValue("\n"));
      if (tailLastNewlineIdx < str.length - 1) {
        int numSpaces = (str.length - tailLastNewlineIdx) - 1;
        var trailingSpaces = StringValue(
            str.substring(tailLastNewlineIdx + 1, numSpaces));
        listTexts.add(trailingSpaces);
      }
    }

    return listTexts;
  }

  void pushToOutputStreamIndividual(Object obj) {
    var glue = obj as Glue;
    var text = obj as StringValue;

    bool includeInOutput = true;

    if (glue != null) {
      trimNewlinesFromOutputStream();
      includeInOutput = true;
    } else if (text != null) {
      var functionTrimIndex = -1;
      var currEl = callStack.currentElement;
      if (currEl.type == PushPopType.Function) {
        functionTrimIndex = currEl.functionStartInOuputStream;
      }

      int glueTrimIndex = -1;
      for (int i = outputStream.length - 1; i >= 0; i--) {
        var o = outputStream[i];
        var c = o as ControlCommand;
        var g = o as Glue;

        if (g != null) {
          glueTrimIndex = i;
          break;
        } else if (c != null &&
            c.commandType == ControlCommand.CommandType.BeginString) {
          if (i >= functionTrimIndex) {
            functionTrimIndex = -1;
          }
          break;
        }
      }

      int trimIndex = -1;
      if (glueTrimIndex != -1 && functionTrimIndex != -1) {
        trimIndex = math.min(functionTrimIndex, glueTrimIndex);
      } else if (glueTrimIndex != -1) {
        trimIndex = glueTrimIndex;
      } else {
        trimIndex = functionTrimIndex;
      }

      if (trimIndex != -1) {
        if (text.isNewline) {
          includeInOutput = false;
        } else if (text.isNonWhitespace) {
          removeExistingGlue();

          if (glueTrimIndex > -1) {
            removeExistingGlue();
          }

          if (functionTrimIndex > -1) {
            var callstackElements = callStack.elements;
            for (int i = callstackElements.length - 1; i >= 0; i--) {
              var el = callstackElements[i];
              if (el.type == PushPopType.Function) {
                el.functionStartInOuputStream = -1;
              } else {
                break;
              }
            }
          }
        }
      } else if (text.isNewline) {
        if (outputStreamEndsInNewline || !outputStreamContainsContent) {
          includeInOutput = false;
        }
      }
    }

    if (includeInOutput) {
      outputStream.add(obj);
      outputStreamDirty();
    }
  }

  void trimNewlinesFromOutputStream() {
    int removeWhitespaceFrom = -1;

    int i = outputStream.length - 1;
    while (i >= 0) {
      var obj = outputStream[i];
      var cmd = obj as ControlCommand;
      var txt = obj as StringValue;

      if (cmd != null || (txt != null && txt.isNonWhitespace)) {
        break;
      } else if (txt != null && txt.isNewline) {
        removeWhitespaceFrom = i;
      }
      i--;
    }

    if (removeWhitespaceFrom >= 0) {
      i = removeWhitespaceFrom;
      while (i < outputStream.length) {
        var text = outputStream[i] as StringValue;
        if (text != null) {
          outputStream.removeAt(i);
        } else {
          i++;
        }
      }
    }

    outputStreamDirty();
  }

  void removeExistingGlue() {
    for (int i = outputStream.length - 1; i >= 0; i--) {
      var c = outputStream[i];
      if (c is Glue) {
        outputStream.removeAt(i);
      } else if (c is ControlCommand) {
        break;
      }
    }

    outputStreamDirty();
  }

  bool get outputStreamEndsInNewline {
    if (outputStream.isNotEmpty) {
      for (int i = outputStream.length - 1; i >= 0; i--) {
        var obj = outputStream[i];
        if (obj is ControlCommand) // e.g. BeginString
          break;
        var text = outputStream[i] as StringValue;
        if (text != null) {
          if (text.isNewline)
            return true;
          else if (text.isNonWhitespace)
            break;
        }
      }
    }
    return false;
  }

  bool get outputStreamContainsContent {
    for (var content in outputStream) {
      if (content is StringValue)
        return true;
    }
    return false;
  }

  bool get inStringEvaluation {
    for (int i = outputStream.length - 1; i >= 0; i--) {
      var cmd = outputStream[i] as ControlCommand;
      if (cmd != null &&
          cmd.commandType == ControlCommand.CommandType.BeginString) {
        return true;
      }
    }
    return false;
  }

  void pushEvaluationStack(Object obj) {
    var listValue = obj as ListValue;
    if (listValue != null) {
      var rawList = listValue.value;
      if (rawList.originNames != null) {
        if (rawList.origins == null) rawList.origins = <ListDefinition>[];
        rawList.origins.clear();

        for (var n in rawList.originNames) {
          ListDefinition def = null;
          story.listDefinitions.tryListGetDefinition(n, def);
          if (def != null && !rawList.origins.contains(def))
            rawList.origins.add(def);
        }
      }
    }
    evaluationStack.add(obj);
  }

  Object popEvaluationStack() {
    var obj = evaluationStack[evaluationStack.length - 1];
    evaluationStack.removeAt(evaluationStack.length - 1);
    return obj;
  }

  Object peekEvaluationStack() {
    return evaluationStack[evaluationStack.length - 1];
  }

  List<Object> popEvaluationStack(int numberOfObjects) {
    if (numberOfObjects > evaluationStack.length) {
      throw Exception("trying to pop too many objects");
    }

    var popped = evaluationStack.getRange(
        evaluationStack.length - numberOfObjects, numberOfObjects);
    evaluationStack.removeRange(
        evaluationStack.length - numberOfObjects, numberOfObjects);
    return popped.toList();
  }

  void forceEnd() {
    callStack.reset();

    _currentFlow.currentChoices.clear();

    currentPointer = Pointer.nullPointer;
    previousPointer = Pointer.nullPointer;

    didSafeExit = true;
  }

  void trimWhitespaceFromFunctionEnd() {
    assert(callStack.currentElement.type == PushPopType.Function);

    var functionStartPoint = callStack.currentElement
        .functionStartInOuputStream;

    if (functionStartPoint == -1) {
      functionStartPoint = 0;
    }

    // Trim whitespace from END of function call
    for (int i = outputStream.length - 1; i >= functionStartPoint; i--) {
      var obj = outputStream[i];
      var txt = obj as StringValue;
      var cmd = obj as ControlCommand;
      if (txt == null) continue;
      if (cmd != null) break;

      if (txt.isNewline || txt.isInlineWhitespace) {
        outputStream.removeAt(i);
        outputStreamDirty();
      } else {
        break;
      }
    }
  }

  void popCallstack([PushPopType? popType]) {
    // Add the end of a function call, trim any whitespace from the end.
    if (callStack.currentElement.type == PushPopType.Function)
      trimWhitespaceFromFunctionEnd();

    callStack.pop(popType);
  }

// Don't make public since the method needs to be wrapped in Story for visit counting
  void setChosenPath(Path path, bool incrementingTurnIndex) {
    // Changing direction, assume we need to clear the current set of choices
    _currentFlow.currentChoices.clear();

    var newPointer = story.pointerAtPath(path);
    if (!newPointer.isNull && newPointer.index == -1)
      newPointer.index = 0;

    currentPointer = newPointer;

    if (incrementingTurnIndex) currentTurnIndex++;
  }

  void startFunctionEvaluationFromGame(Container funcContainer,
      [List<Object?>? arguments]) {
    callStack.push(
        PushPopType.FunctionEvaluationFromGame, evaluationStack.length);
    callStack.currentElement.currentPointer = Pointer.startOf(funcContainer);

    passArgumentsToEvaluationStack(arguments);
  }

  void passArgumentsToEvaluationStack(List<Object?>? arguments) {
    // Pass arguments onto the evaluation stack
    if (arguments != null) {
      for (int i = 0; i < arguments.length; i++) {
        if (!(arguments[i] is int ||
            arguments[i] is double ||
            arguments[i] is String ||
            arguments[i] is bool ||
            arguments[i] is InkList)) {
          throw ArgumentError(
              "ink arguments when calling EvaluateFunction / ChoosePathStringWithParameters must be int, double, String, bool, or InkList. Argument was ${arguments[i] ==
                  null ? "null" : arguments[i]!.runtimeType}");
        }

        pushEvaluationStack(Value.create(arguments[i]));
      }
    }
  }

  bool tryExitFunctionEvaluationFromGame() {
    if (callStack.currentElement.type ==
        PushPopType.FunctionEvaluationFromGame) {
      currentPointer = Pointer.nullPointer;
      didSafeExit = true;
      return true;
    }

    return false;
  }

  Object? completeFunctionEvaluationFromGame() {
    if (callStack.currentElement.type !=
        PushPopType.FunctionEvaluationFromGame) {
      throw Exception(
          "Expected external function evaluation to be complete. Stack trace: ${callStack
              .callStackTrace}");
    }

    int originalEvaluationStackHeight =
        callStack.currentElement.evaluationStackHeightWhenPushed;

    Object? returnedObj = null;
    while (evaluationStack.length > originalEvaluationStackHeight) {
      var poppedObj = popEvaluationStack();
      if (returnedObj == null) returnedObj = poppedObj;
    }

    popCallstack(PushPopType.functionEvaluationFromGame);

    if (returnedObj != null) {
      if (returnedObj is Void)
        return null;

      var returnVal = returnedObj as Value;

      if (returnVal.valueType == ValueType.DivertTarget) {
        return returnVal.valueObject.toString();
      }
      return returnVal.valueObject;
    }

    return null;
  }

  void addError(String message, bool isWarning) {
    if (!isWarning) {
      if (currentErrors == null) currentErrors = <String>[];
      currentErrors.add(message);
    } else {
      if (currentWarnings == null) currentWarnings = <String>[];
      currentWarnings.add(message);
    }
  }

  void outputStreamDirty() {
    _outputStreamTextDirty = true;
    _outputStreamTagsDirty = true;
  }

  Map<String, int> _visitCounts = <String, int>{};
  Map<String, int> _turnIndices = <String, int>{};
  bool _outputStreamTextDirty = true;
  bool _outputStreamTagsDirty = true;

  StatePatch? _patch;

  Flow? _currentFlow;
  Map<String, Flow>? _namedFlows;
  const String kDefaultFlowName = "DEFAULT_FLOW";
  bool _aliveFlowNamesDirty = true;
}}