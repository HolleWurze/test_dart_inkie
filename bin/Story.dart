class Story extends RuntimeObject {
  static const int inkVersionCurrent = 21;
  static const int inkVersionMinimumCompatible = 18;

  late StoryState _state;
  ListDefinitionsOrigin? _listDefinitions;
  Profiler? _profiler;

  List<Choice> get currentChoices {
    var choices = <Choice>[];
    for (var c in _state.currentChoices) {
      if (!c.isInvisibleDefault) {
        c.index = choices.length;
        choices.add(c);
      }
    }
    return choices;
  }

  String get currentText {
    ifAsyncWeCant("call currentText since it's a work in progress");
    return _state.currentText;
  }

  List<String> get currentTags {
    ifAsyncWeCant("call currentTags since it's a work in progress");
    return _state.currentTags;
  }

  List<String> get currentErrors => _state.currentErrors;

  List<String> get currentWarnings => _state.currentWarnings;

  String get currentFlowName => _state.currentFlowName;

  bool get currentFlowIsDefaultFlow => _state.currentFlowIsDefaultFlow;

  List<String> get aliveFlowNames => _state.aliveFlowNames;

  bool get hasError => _state.hasError;

  bool get hasWarning => _state.hasWarning;

  VariablesState get variablesState => _state.variablesState;

  ListDefinitionsOrigin? get listDefinitions => _listDefinitions;

  StoryState get state => _state;

  Function? onError;
  Action? onDidContinue;
  Action<Choice>? onMakeChoice;
  Action<String, List<dynamic>>? onEvaluateFunction;
  Action<String, List<dynamic>, String, dynamic>? onCompleteEvaluateFunction;
  Action<String, List<dynamic>>? onChoosePathString;

  Profiler startProfiling() {
    ifAsyncWeCant("start profiling");
    _profiler = Profiler();
    return _profiler!;
  }

  void endProfiling() {
    _profiler = null;
  }

  Story(Container contentContainer, {List<Runtime.ListDefinition>? lists}) {
    _mainContentContainer = contentContainer;

    if (lists != null) _listDefinitions = ListDefinitionsOrigin(lists);

    _externals = <String, ExternalFunctionDef>{};
  }

  Story.fromJson(String jsonString) : this(null) {
    var rootObject = SimpleJson.textToDictionary(jsonString);

    var versionObj = rootObject["inkVersion"];
    if (versionObj == null) throw Exception("ink version number not found. Are you sure it's a valid .ink.json file?");

    var formatFromFile = versionObj as int;
    if (formatFromFile > inkVersionCurrent) {
      throw Exception("Version of ink used to build story was newer than the current version of the engine");
    } else if (formatFromFile < inkVersionMinimumCompatible) {
      throw Exception("Version of ink used to build story is too old to be loaded by this version of the engine");
    } else if (formatFromFile != inkVersionCurrent) {
      print("WARNING: Version of ink used to build story doesn't match the current version of the engine. Non-critical, but recommended to synchronize.");
    }

    var rootToken = rootObject["root"];
    if (rootToken == null) throw Exception("Root node for ink not found. Are you sure it's a valid .ink.json file?");

    Object? listDefsObj;
    if (rootObject.containsKey("listDefs")) {
      listDefsObj = rootObject["listDefs"];
      _listDefinitions = Json.jTokenToListDefinitions(listDefsObj);
    }

    _mainContentContainer = Json.jTokenToRuntimeObject(rootToken) as Container;

    resetState();
  }

  String toJson() {
    var writer = SimpleJson.Writer();
    toJsonInternal(writer);
    return writer.toString();
  }

  void toJson(Stream stream) {
    var writer = SimpleJson.Writer(stream);
    toJsonInternal(writer);
  }

  void toJsonInternal(SimpleJson.Writer writer) {
    writer.writeObjectStart();
    writer.writeProperty("inkVersion", inkVersionCurrent);

    // Main container content
    writer.writeProperty("root", (w) => Json.writeRuntimeContainer(w, _mainContentContainer));

    // List definitions
    if (_listDefinitions != null) {
      writer.writePropertyStart("listDefs");
      writer.writeObjectStart();

      for (var def in _listDefinitions!.lists) {
        writer.writePropertyStart(def.name);
        writer.writeObjectStart();

        for (var itemToVal in def.items) {
          var item = itemToVal.key;
          var val = itemToVal.value;
          writer.writeProperty(item.itemName, val);
        }

        writer.writeObjectEnd();
        writer.writePropertyEnd();
      }

      writer.writeObjectEnd();
      writer.writePropertyEnd();
    }

    writer.writeObjectEnd();
  }

  void resetState() {
    ifAsyncWeCant("ResetState");

    _state = StoryState(this);
    _state.variablesState.variableChangedEvent += VariableStateDidChangeEvent;

    resetGlobals();
  }

  void resetErrors() {
    _state.resetErrors();
  }

  void resetCallstack() {
    ifAsyncWeCant("ResetCallstack");
    _state.forceEnd();
  }

  void resetGlobals() {
    if (_mainContentContainer.namedContent.containsKey("global decl")) {
      var originalPointer = state.currentPointer;
      choosePath(Path("global decl"), incrementingTurnIndex: false);

      // Continue, but without validating external bindings,
      // since we may be doing this reset at initialization time.
      continueInternal();

      state.currentPointer = originalPointer;
    }

    state.variablesState.snapshotDefaultGlobals();
  }

  void switchFlow(String flowName) {
    ifAsyncWeCant("switch flow");
    if (_asyncSaving) throw Exception("Story is already in background saving mode, can't switch flow to $flowName");

    state.switchFlowInternal(flowName);
  }

  void removeFlow(String flowName) {
    state.removeFlowInternal(flowName);
  }

  void switchToDefaultFlow() {
    state.switchToDefaultFlowInternal();
  }

  String continueStory() {
    continueAsync(0);
    return currentText;
  }

  bool get canContinue {
    return state.canContinue;
  }

  bool get asyncContinueComplete {
    return !_asyncContinueActive;
  }

  void continueAsync(double millisecsLimitAsync) {
    if (!_hasValidatedExternals) validateExternalBindings();
    continueInternal(millisecsLimitAsync);
  }

  void continueInternal(double millisecsLimitAsync) {
    if (_profiler != null) _profiler.preContinue();

    bool isAsyncTimeLimited = millisecsLimitAsync > 0;

    _recursiveContinueCount++;

    if (!_asyncContinueActive) {
      _asyncContinueActive = isAsyncTimeLimited;

      if (!canContinue) {
        throw Exception("Can't continue - should check canContinue before calling Continue");
      }

      _state.didSafeExit = false;
      _state.resetOutput();

      if (_recursiveContinueCount == 1) _state.variablesState.batchObservingVariableChanges = true;
    }

    // Start timing
    var durationStopwatch = Stopwatch()..start();

    bool outputStreamEndsInNewline = false;
    _sawLookaheadUnsafeFunctionAfterNewline = false;
    do {
      try {
        outputStreamEndsInNewline = continueSingleStep();
      } catch (StoryException e) {
      addError(e.message, useEndLineNumber: e.useEndLineNumber);
      break;
    }

    if (outputStreamEndsInNewline) break;

    // Run out of async time?
    if (_asyncContinueActive && durationStopwatch.elapsedMilliseconds > millisecsLimitAsync) {
      break;
    }
  } while (canContinue);

    durationStopwatch.stop();

    if (outputStreamEndsInNewline || !canContinue) {
    // Need to rewind, due to evaluating further than we should?
    if (_stateSnapshotAtLastNewline != null) {
    restoreStateSnapshot();
    }

    // Finished a section of content / reached a choice point?
    if (!canContinue) {
    if (state.callStack.canPopThread) addError("Thread available to pop, threads should always be flat by the end of evaluation?");
    if (state.generatedChoices.isEmpty && !state.didSafeExit && _temporaryEvaluationContainer == null) {
    if (state.callStack.canPop(PushPopType.Tunnel)) addError("unexpectedly reached the end of content. Do you need a '->->' to return from a tunnel?");
    else if (state.callStack.canPop(PushPopType.Function)) addError("unexpectedly reached the end of content. Do you need a '~ return'?");
    else if (!state.callStack.canPop) addError("ran out of content. Do you need a '-> DONE' or '-> END'?");
    else addError("unexpectedly reached the end of content for an unknown reason. Please debug the compiler!");
    }
    }

    state.didSafeExit = false;
    _sawLookaheadUnsafeFunctionAfterNewline = false;

    if (_recursiveContinueCount == 1) _state.variablesState.batchObservingVariableChanges = false;

    _asyncContinueActive = false;
    if (onDidContinue != null) onDidContinue();
    }

    _recursiveContinueCount--;

    if (_profiler != null) _profiler.postContinue();

    if (state.hasError || state.hasWarning) {
    if (onError != null) {
    if (state.hasError) {
    for (var err in state.currentErrors) {
    onError(err, ErrorType.Error);
    }
    }
    if (state.hasWarning) {
    for (var err in state.currentWarnings) {
    onError(err, ErrorType.Warning);
    }
    }
    resetErrors();
    } else {
    var sb = StringBuffer();
    sb.write("Ink had ");
    if (state.hasError) {
    sb.write(state.currentErrors.length);
    sb.write(state.currentErrors.length == 1 ? " error" : " errors");
    if (state.hasWarning) sb.write(" and ");
    }
    if (state.hasWarning) {
    sb.write(state.currentWarnings.length);
    sb.write(state.currentWarnings.length == 1 ? " warning" : " warnings");
    }
    sb.write(". It is strongly suggested that you assign an error handler to story.onError. The first issue was: ");
    sb.write(state.hasError ? state.currentErrors[0] : state.currentWarnings[0]);

    throw StoryException(sb.toString());
    }
    }
  }

  bool continueSingleStep() {
    if (_profiler != null) _profiler.preStep();

    // Run main step function (walks through content)
    step();

    if (_profiler != null) _profiler.postStep();

    // Run out of content and we have a default invisible choice that we can follow?
    if (!canContinue && !state.callStack.elementIsEvaluateFromGame) {
      tryFollowDefaultInvisibleChoice();
    }

    if (_profiler != null) _profiler.preSnapshot();

    // Don't save/rewind during string evaluation, which is e.g. used for choices
    if (!state.inStringEvaluation) {
      if (_stateSnapshotAtLastNewline != null) {
        var change = calculateNewlineOutputStateChange(_stateSnapshotAtLastNewline.currentText, state.currentText, _stateSnapshotAtLastNewline.currentTags.length, state.currentTags.length);

        if (change == OutputStateChange.ExtendedBeyondNewline || _sawLookaheadUnsafeFunctionAfterNewline) {
          restoreStateSnapshot();

          // Hit a newline for sure, we're done
          return true;
        } else if (change == OutputStateChange.NewlineRemoved) {
          discardSnapshot();
        }
      }

      // Current content ends in a newline - approaching end of our evaluation
      if (state.outputStreamEndsInNewline) {
        if (canContinue) {
          if (_stateSnapshotAtLastNewline == null) stateSnapshot();
        } else {
          discardSnapshot();
        }
      }
    }

    if (_profiler != null) _profiler.postSnapshot();

    // outputStreamEndsInNewline = false
    return false;
  }

  OutputStateChange calculateNewlineOutputStateChange(String prevText, String currText, int prevTagCount, int currTagCount) {
    var newlineStillExists = currText.length >= prevText.length && prevText.length > 0 && currText[prevText.length - 1] == '\n';
    if (prevTagCount == currTagCount && prevText.length == currText.length && newlineStillExists) return OutputStateChange.NoChange;

    // Old newline has been removed, it wasn't the end of the line after all
    if (!newlineStillExists) {
      return OutputStateChange.NewlineRemoved;
    }

    // Tag added - definitely the start of a new line
    if (currTagCount > prevTagCount) return OutputStateChange.ExtendedBeyondNewline;

    // There must be new content - check whether it's just whitespace
    for (int i = prevText.length; i < currText.length; i++) {
      var c = currText[i];
      if (c != ' ' && c != '\t') {
        return OutputStateChange.ExtendedBeyondNewline;
      }
    }

    return OutputStateChange.NoChange;
  }

  String continueMaximally() {
    ifAsyncWeCant("ContinueMaximally");

    var sb = StringBuffer();

    while (canContinue) {
      sb.write(continueStory());
    }

    return sb.toString();
  }

  SearchResult contentAtPath(Path path) {
    return mainContentContainer.contentAtPath(path);
  }

  Container knotContainerWithName(String name) {
    INamedContent namedContainer;
    if (mainContentContainer.namedContent.containsKey(name)) {
      namedContainer = mainContentContainer.namedContent[name];
    }
    return namedContainer as Container;
  }

  Pointer pointerAtPath(Path path) {
    if (path.length == 0) return Pointer.nullPtr;

    var p = Pointer();

    int pathLengthToUse = path.length;

    SearchResult result;
    if (path.lastComponent.isIndex) {
      pathLengthToUse = path.length - 1;
      result = mainContentContainer.contentAtPath(path, partialPathLength: pathLengthToUse);
      p.container = result.container;
      p.index = path.lastComponent.index;
    } else {
      result = mainContentContainer.contentAtPath(path);
      p.container = result.container;
      p.index = -1;
    }

    if (result.obj == null || result.obj == mainContentContainer && pathLengthToUse > 0) {
      error("Failed to find content at path '$path', and no approximation of it was possible.");
    } else if (result.approximate) {
      warning("Failed to find content at path '$path', so it was approximated to: '${result.obj.path}'.");
    }

    return p;
  }

  void stateSnapshot() {
    _stateSnapshotAtLastNewline = _state;
    _state = _state.copyAndStartPatching();
  }

  void restoreStateSnapshot() {
    _stateSnapshotAtLastNewline.restoreAfterPatch();

    _state = _stateSnapshotAtLastNewline;
    _stateSnapshotAtLastNewline = null;

    if (!_asyncSaving) {
      _state.applyAnyPatch();
    }
  }

  void discardSnapshot() {
    if (!_asyncSaving) {
      _state.applyAnyPatch();
    }

    _stateSnapshotAtLastNewline = null;
  }

  StoryState copyStateForBackgroundThreadSave() {
    ifAsyncWeCant("start saving on a background thread");
    if (_asyncSaving) {
      throw Exception("Story is already in background saving mode, can't call CopyStateForBackgroundThreadSave again!");
    }

    var stateToSave = _state;
    _state = _state.copyAndStartPatching();
    _asyncSaving = true;
    return stateToSave;
  }

  void backgroundSaveComplete() {
    if (_stateSnapshotAtLastNewline == null) {
      _state.applyAnyPatch();
    }

    _asyncSaving = false;
  }

  void step() {
    bool shouldAddToStream = true;

    // Get current content
    var pointer = state.currentPointer;
    if (pointer.isNull) {
      return;
    }

    // Step directly to the first element of content in a container (if necessary)
    Container containerToEnter = pointer.resolve() as Container;
    while (containerToEnter != null) {
      // Mark container as being entered
      visitContainer(containerToEnter, atStart: true);

      // No content? the most we can do is step past it
      if (containerToEnter.content.isEmpty) {
        break;
      }

      pointer = Pointer.startOf(containerToEnter);
      containerToEnter = pointer.resolve() as Container;
    }
    state.currentPointer = pointer;

    if (_profiler != null) {
      _profiler.step(state.callStack);
    }

    var currentContentObj = pointer.resolve();
    bool isLogicOrFlowControl = performLogicAndFlowControl(currentContentObj);

    // Has flow been forced to end by flow control above?
    if (state.currentPointer.isNull) {
      return;
    }

    if (isLogicOrFlowControl) {
      shouldAddToStream = false;
    }

    // Choice with condition?
    var choicePoint = currentContentObj as ChoicePoint;
    if (choicePoint != null) {
      var choice = processChoice(choicePoint);
      if (choice != null) {
        state.generatedChoices.add(choice);
      }

      currentContentObj = null;
      shouldAddToStream = false;
    }

    if (currentContentObj is Container) {
      shouldAddToStream = false;
    }

    // Content to add to evaluation stack or the output stream
    if (shouldAddToStream) {
      var varPointer = currentContentObj as VariablePointerValue;
      if (varPointer != null && varPointer.contextIndex == -1) {
        // Create a new object so we're not overwriting the story's own data
        var contextIdx = state.callStack.contextForVariableNamed(varPointer.variableName);
        currentContentObj = VariablePointerValue(varPointer.variableName, contextIdx);
      }

      // Expression evaluation content
      if (state.inExpressionEvaluation) {
        state.pushEvaluationStack(currentContentObj);
      }
      // Output stream content (i.e. not expression evaluation)
      else {
        state.pushToOutputStream(currentContentObj);
      }
    }

    // Increment the content pointer, following diverts if necessary
    nextContent();

    var controlCmd = currentContentObj as ControlCommand;
    if (controlCmd != null && controlCmd.commandType == ControlCommand.CommandType.StartThread) {
      state.callStack.pushThread();
    }
  }

  void visitContainer(Container container, bool atStart) {
    if (!container.countingAtStartOnly || atStart) {
      if (container.visitsShouldBeCounted) {
        state.incrementVisitCountForContainer(container);
      }

      if (container.turnIndexShouldBeCounted) {
        state.recordTurnIndexVisitToContainer(container);
      }
    }
  }

  List<Container> _prevContainers = [];
  void visitChangedContainersDueToDivert() {
    var previousPointer = state.previousPointer;
    var pointer = state.currentPointer;

    if (pointer.isNull || pointer.index == -1) {
      return;
    }

    // First, find the previously open set of containers
    _prevContainers.clear();
    if (!previousPointer.isNull) {
      Container prevAncestor = previousPointer.resolve() as Container ?? previousPointer.container as Container;
      while (prevAncestor != null) {
        _prevContainers.add(prevAncestor);
        prevAncestor = prevAncestor.parent as Container;
      }
    }

    RuntimeObject currentChildOfContainer = pointer.resolve();

    // Invalid pointer? May happen if attempting to
    if (currentChildOfContainer == null) {
      return;
    }

    Container currentContainerAncestor = currentChildOfContainer.parent as Container;

    bool allChildrenEnteredAtStart = true;
    while (currentContainerAncestor != null &&
        (!_prevContainers.contains(currentContainerAncestor) || currentContainerAncestor.countingAtStartOnly)) {
      bool enteringAtStart = currentContainerAncestor.content.isNotEmpty &&
          currentChildOfContainer == currentContainerAncestor.content[0] &&
          allChildrenEnteredAtStart;

      if (!enteringAtStart) {
        allChildrenEnteredAtStart = false;
      }

      // Mark a visit to this container
      visitContainer(currentContainerAncestor, enteringAtStart);

      currentChildOfContainer = currentContainerAncestor;
      currentContainerAncestor = currentContainerAncestor.parent as Container;
    }
  }

  String popChoiceStringAndTags(List<String> tags) {
    var choiceOnlyStrVal = state.popEvaluationStack() as StringValue;

    while (state.evaluationStack.isNotEmpty && state.peekEvaluationStack() is Tag) {
      if (tags == null) {
        tags = [];
      }
      var tag = state.popEvaluationStack() as Tag;
      tags.insert(0, tag.text); // popped in reverse order
    }

    return choiceOnlyStrVal.value;
  }

  Choice processChoice(ChoicePoint choicePoint) {
    bool showChoice = true;

    // Don't create a choice if the choice point doesn't pass the conditional
    if (choicePoint.hasCondition) {
      var conditionValue = state.popEvaluationStack();
      if (!isTruthy(conditionValue)) {
        showChoice = false;
      }
    }

    String startText = "";
    String choiceOnlyText = "";
    List<String> tags;

    if (choicePoint.hasChoiceOnlyContent) {
      choiceOnlyText = popChoiceStringAndTags(tags);
    }

    if (choicePoint.hasStartContent) {
      startText = popChoiceStringAndTags(tags);
    }

    // Don't create a choice if the player has already read this content
    if (choicePoint.onceOnly) {
      var visitCount = state.visitCountForContainer(choicePoint.choiceTarget);
      if (visitCount > 0) {
        showChoice = false;
      }
    }

    if (!showChoice) {
      return null;
    }

    var choice = Choice();
    choice.targetPath = choicePoint.pathOnChoice;
    choice.sourcePath = choicePoint.path.toString();
    choice.isInvisibleDefault = choicePoint.isInvisibleDefault;
    choice.tags = tags;

    choice.threadAtGeneration = state.callStack.forkThread();

    // Set the final text for the choice
    choice.text = (startText + choiceOnlyText).trim();

    return choice;
  }

  bool isTruthy(RuntimeObject obj) {
    bool truthy = false;
    if (obj is Value) {
      var val = obj as Value;

      if (val is DivertTargetValue) {
        var divTarget = val as DivertTargetValue;
        error("Shouldn't use a divert target (to ${divTarget.targetPath}) as a conditional value. Did you intend a function call 'likeThis()' or a read count check 'likeThis'? (no arrows)");
        return false;
      }

      return val.isTruthy;
    }
    return truthy;
  }

  bool performLogicAndFlowControl(RuntimeObject contentObj) {
    if (contentObj == null) {
      return false;
    }

    // Divert
    if (contentObj is Divert) {
      Divert currentDivert = contentObj as Divert;

      if (currentDivert.isConditional) {
        var conditionValue = state.popEvaluationStack();

        // False conditional? Cancel divert
        if (!isTruthy(conditionValue)) {
          return true;
        }
      }

      if (currentDivert.hasVariableTarget) {
        var varName = currentDivert.variableDivertName;
        var varContents = state.variablesState.getVariableWithName(varName);

        if (varContents == null) {
          error("Tried to divert using a target from a variable that could not be found ($varName)");
        } else if (!(varContents is DivertTargetValue)) {
          var intContent = varContents as IntValue;
          String errorMessage = "Tried to divert to a target from a variable, but the variable ($varName) didn't contain a divert target, it ";
          if (intContent != null && intContent.value == 0) {
            errorMessage += "was empty/null (the value 0).";
          } else {
            errorMessage += "contained '$varContents'.";
          }
          error(errorMessage);
        }

        var target = varContents as DivertTargetValue;
        state.divertedPointer = pointerAtPath(target.targetPath);
      } else if (currentDivert.isExternal) {
        callExternalFunction(currentDivert.targetPathString, currentDivert.externalArgs);
        return true;
      } else {
        state.divertedPointer = currentDivert.targetPointer;
      }

      if (currentDivert.pushesToStack) {
        state.callStack.push(
            currentDivert.stackPushType,
            outputStreamLengthWithPushed: state.outputStream.length);
      }

      if (state.divertedPointer.isNull && !currentDivert.isExternal) {
        // Human-readable name available - runtime divert is part of a hard-written divert that to missing content
        if (currentDivert != null && currentDivert.debugMetadata.sourceName != null) {
          error("Divert target doesn't exist: ${currentDivert.debugMetadata.sourceName}");
        } else {
          error("Divert resolution failed: $currentDivert");
        }
      }

      return true;
    }

    // Start/end an expression evaluation? Or print out the result?
    else if (contentObj is ControlCommand) {
      var evalCommand = contentObj as ControlCommand;
      // Handle ControlCommand here
    }

    // Other cases go here...

    return false;
  }


  switch (evalCommand.commandType) {
  case ControlCommand.CommandType.EvalStart:
  assert(!state.inExpressionEvaluation, "Already in expression evaluation?");
  state.inExpressionEvaluation = true;
  break;

  case ControlCommand.CommandType.EvalEnd:
  assert(state.inExpressionEvaluation, "Not in expression evaluation mode");
  state.inExpressionEvaluation = false;
  break;

  case ControlCommand.CommandType.EvalOutput:
  if (state.evaluationStack.isNotEmpty) {
  var output = state.popEvaluationStack();

  if (!(output is Void)) {
  var text = StringValue(output.toString());
  state.pushToOutputStream(text);
  }
  }
  break;

  case ControlCommand.CommandType.NoOp:
  break;

  case ControlCommand.CommandType.Duplicate:
  state.pushEvaluationStack(state.peekEvaluationStack());
  break;

  case ControlCommand.CommandType.PopEvaluatedValue:
  state.popEvaluationStack();
  break;

  case ControlCommand.CommandType.PopFunction:
  case ControlCommand.CommandType.PopTunnel:
  var popType = evalCommand.commandType == ControlCommand.CommandType.PopFunction
  ? PushPopType.Function
      : PushPopType.Tunnel;
  DivertTargetValue overrideTunnelReturnTarget;
  if (popType == PushPopType.Tunnel) {
  var popped = state.popEvaluationStack();
  overrideTunnelReturnTarget = popped as DivertTargetValue;
  if (overrideTunnelReturnTarget == null) {
  assert(popped is Void, "Expected void if ->-> doesn't override target");
  }
  }
  if (state.tryExitFunctionEvaluationFromGame()) {
  break;
  } else if (state.callStack.currentElement.type != popType || !state.callStack.canPop) {
  var names = {
  PushPopType.Function: "function return statement (~ return)",
  PushPopType.Tunnel: "tunnel onwards statement (->->)"
  };
  var expected = names[state.callStack.currentElement.type];
  if (!state.callStack.canPop) {
  expected = "end of flow (-> END or choice)";
  }
  var errorMsg = "Found ${names[popType]}, when expected $expected";
  error(errorMsg);
  } else {
  state.popCallstack();
  if (overrideTunnelReturnTarget != null) {
  state.divertedPointer = pointerAtPath(overrideTunnelReturnTarget.targetPath);
  }
  }
  break;

  case ControlCommand.CommandType.BeginString:
  state.pushToOutputStream(evalCommand);
  assert(state.inExpressionEvaluation, "Expected to be in an expression when evaluating a string");
  state.inExpressionEvaluation = false;
  break;

  case ControlCommand.CommandType.BeginTag:
  state.pushToOutputStream(evalCommand);
  break;

  case ControlCommand.CommandType.EndTag:
  if (state.inStringEvaluation) {
  var contentStackForTag = <RuntimeObject>[];
  int outputCountConsumed = 0;
  for (int i = state.outputStream.length - 1; i >= 0; --i) {
  var obj = state.outputStream[i];
  outputCountConsumed++;
  if (obj is ControlCommand) {
  if (obj.commandType == ControlCommand.CommandType.BeginTag) {
  break;
  } else {
  error("Unexpected ControlCommand while extracting tag from choice");
  break;
  }
  }
  if (obj is StringValue) {
  contentStackForTag.add(obj);
  }
  }
  state.popFromOutputStream(outputCountConsumed);
  var sb = StringBuffer();
  for (StringValue strVal in contentStackForTag) {
  sb.write(strVal.value);
  }
  var choiceTag = Tag(state.cleanOutputWhitespace(sb.toString()));
  state.pushEvaluationStack(choiceTag);
  } else {
  state.pushToOutputStream(evalCommand);
  }
  break;

  case ControlCommand.CommandType.EndString:
  var contentStackForString = <RuntimeObject>[];
  var contentToRetain = <RuntimeObject>[];
  int outputCountConsumed = 0;
  for (int i = state.outputStream.length - 1; i >= 0; --i) {
  var obj = state.outputStream[i];
  outputCountConsumed++;
  if (obj is ControlCommand && obj.commandType == ControlCommand.CommandType.BeginString) {
  break;
  }
  if (obj is Tag) {
  contentToRetain.add(obj);
  }
  if (obj is StringValue) {
  contentStackForString.add(obj);
  }
  }
  state.popFromOutputStream(outputCountConsumed);
  for (var rescuedTag in contentToRetain) {
  state.pushToOutputStream(rescuedTag);
  }
  var sb = StringBuffer();
  for (var c in contentStackForString) {
  sb.write(c.toString());
  }
  state.inExpressionEvaluation = true;
  state.pushEvaluationStack(StringValue(sb.toString()));
  break;

  case ControlCommand.CommandType.ChoiceCount:
  var choiceCount = state.generatedChoices.length;
  state.pushEvaluationStack(IntValue(choiceCount));
  break;

  case ControlCommand.CommandType.Turns:
  state.pushEvaluationStack(IntValue(state.currentTurnIndex + 1));
  break;

  default:
  error("Unhandled ControlCommand: $evalCommand");
  break;
  }

  else if (contentObj is VariableAssignment) {
  var varAss = contentObj as VariableAssignment;
  var assignedVal = state.popEvaluationStack();

  // When in temporary evaluation, don't create new variables purely within
  // the temporary context, but attempt to create them globally
  //var prioritiseHigherInCallStack = _temporaryEvaluationContainer != null;

  state.variablesState.assign(varAss, assignedVal);

  return true;
  }

  // Variable reference
  else if (contentObj is VariableReference) {
  var varRef = contentObj as VariableReference;
  RuntimeObject foundValue = null;

  // Explicit read count value
  if (varRef.pathForCount != null) {
  var container = varRef.containerForCount;
  int count = state.visitCountForContainer(container);
  foundValue = IntValue(count);
  }

  // Normal variable reference
  else {
  foundValue = state.variablesState.getVariableWithName(varRef.name);

  if (foundValue == null) {
  warning("Variable not found: '${varRef.name}'. Using default value of 0 (false). This can happen with temporary variables if the declaration hasn't yet been hit. Globals are always given a default value on load if a value doesn't exist in the save state.");
  foundValue = IntValue(0);
  }
  }

  state.pushEvaluationStack(foundValue);

  return true;
  }

  // Native function call
  else if (contentObj is NativeFunctionCall) {
  var func = contentObj as NativeFunctionCall;
  var funcParams = state.popEvaluationStacks(func.numberOfParameters);
  var result = func.call(funcParams);
  state.pushEvaluationStack(result);
  return true;
  }

  // No control content, must be ordinary content
  return false;
}

void choosePathString(String path, {bool resetCallstack = true, List<Object> arguments}) {
  if (_asyncContinueActive) {
    throw Exception("Can't call ChoosePathString right now. Story is in the middle of a ContinueAsync(). Make more ContinueAsync() calls or a single Continue() call beforehand.");
  }
  if (onChoosePathString != null) {
    onChoosePathString(path, arguments);
  }
  if (resetCallstack) {
    resetCallstack();
  } else {
    if (state.callStack.currentElement.type == PushPopType.Function) {
      String funcDetail = "";
      var container = state.callStack.currentElement.currentPointer.container;
      if (container != null) {
        funcDetail = "(${container.path.toString()}) ";
      }
      throw Exception("Story was running a function $funcDetailwhen you called ChoosePathString($path) - this is almost certainly not what you want! Full stack trace:\n${state.callStack.callStackTrace}");
    }
  }

  state.passArgumentsToEvaluationStack(arguments);
  choosePath(Path(path));
}

void ifAsyncWeCant(String activityStr) {
  if (_asyncContinueActive) {
    throw Exception("Can't $activityStr. Story is in the middle of a ContinueAsync(). Make more ContinueAsync() calls or a single Continue() call beforehand.");
  }
}

void choosePath(Path p, {bool incrementingTurnIndex = true}) {
  state.setChosenPath(p, incrementingTurnIndex);

  // Take note of newly visited containers for read counts, etc.
  visitChangedContainersDueToDivert();
}

void chooseChoiceIndex(int choiceIdx) {
  var choices = currentChoices;
  assert(choiceIdx >= 0 && choiceIdx < choices.length, "Choice out of range");

  var choiceToChoose = choices[choiceIdx];
  if (onMakeChoice != null) {
    onMakeChoice(choiceToChoose);
  }
  state.callStack.currentThread = choiceToChoose.threadAtGeneration;

  choosePath(choiceToChoose.targetPath);
}

bool hasFunction(String functionName) {
  try {
    return knotContainerWithName(functionName) != null;
  } catch (e) {
    return false;
  }
}

Object evaluateFunction(String functionName, [List<Object> arguments]) {
  String _;
  return evaluateFunction(functionName, out _, arguments);
}

Object evaluateFunction(String functionName, out String textOutput, [List<Object> arguments]) {
if (onEvaluateFunction != null) {
onEvaluateFunction(functionName, arguments);
}
ifAsyncWeCant("evaluate a function");

if (functionName == null) {
throw Exception("Function is null");
} else if (functionName.isEmpty || functionName.trim().isEmpty) {
throw Exception("Function is empty or whitespace.");
}

// Get the content that we need to run
var funcContainer = knotContainerWithName(functionName);
if (funcContainer == null) {
throw Exception("Function doesn't exist: '$functionName'");
}

// Snapshot the output stream
var outputStreamBefore = List<RuntimeObject>.from(state.outputStream);
_state.resetOutput();

// State will temporarily replace the callstack in order to evaluate
state.startFunctionEvaluationFromGame(funcContainer, arguments);

// Evaluate the function, and collect the string output
var stringOutput = StringBuffer();
while (canContinue) {
stringOutput.write(continueStory());
}
textOutput = stringOutput.toString();

// Restore the output stream in case this was called
// during main story evaluation.
_state.resetOutput(outputStreamBefore);

// Finish evaluation, and see whether anything was produced
var result = state.completeFunctionEvaluationFromGame();
if (onCompleteEvaluateFunction != null) {
onCompleteEvaluateFunction(functionName, arguments, textOutput, result);
}
return result;
}

RuntimeObject evaluateExpression(RuntimeContainer exprContainer) {
int startCallStackHeight = state.callStack.elements.length;

state.callStack.push(PushPopType.Tunnel);

_temporaryEvaluationContainer = exprContainer;

state.goToStart();

int evalStackHeight = state.evaluationStack.length;

continueStory();

_temporaryEvaluationContainer = null;

if (state.callStack.elements.length > startCallStackHeight) {
state.popCallstack();
}

int endStackHeight = state.evaluationStack.length;
if (endStackHeight > evalStackHeight) {
return state.popEvaluationStack();
} else {
return null;
}
}

bool get allowExternalFunctionFallbacks => _allowExternalFunctionFallbacks;

set allowExternalFunctionFallbacks(bool value) {
_allowExternalFunctionFallbacks = value;
}

bool tryGetExternalFunction(String functionName, ExternalFunction externalFunction) {
ExternalFunctionDef externalFunctionDef;
if (_externals.containsKey(functionName)) {
externalFunctionDef = _externals[functionName];
externalFunction = externalFunctionDef.function;
return true;
} else {
externalFunction = null;
return false;
}
}

void callExternalFunction(String funcName, int numberOfArguments) {
ExternalFunctionDef funcDef;
Container fallbackFunctionContainer = null;

final foundExternal = _externals.containsKey(funcName);

if (foundExternal && !funcDef.lookaheadSafe && state.inStringEvaluation) {
return;
}

// Should this function break glue? Abort run if we've already seen a newline.
// Set a bool to tell it to restore the snapshot at the end of this instruction.
if (foundExternal && !funcDef.lookaheadSafe && _stateSnapshotAtLastNewline != null) {
_sawLookaheadUnsafeFunctionAfterNewline = true;
return;
}

// Try to use fallback function?
if (!foundExternal) {
if (allowExternalFunctionFallbacks) {
fallbackFunctionContainer = knotContainerWithName(funcName);
assert(fallbackFunctionContainer != null,
"Trying to call EXTERNAL function '$funcName' which has not been bound, and fallback ink function could not be found.");

// Divert direct into fallback function and we're done
state.callStack.push(
PushPopType.Function,
outputStreamLengthWithPushed: state.outputStream.length,
);
state.divertedPointer = Pointer.startOf(fallbackFunctionContainer);
return;
} else {
assert(false, "Trying to call EXTERNAL function '$funcName' which has not been bound (and ink fallbacks disabled).");
}
}

// Pop arguments
final arguments = <Object>[];
for (int i = 0; i < numberOfArguments; ++i) {
final poppedObj = state.popEvaluationStack() as Value;
final valueObj = poppedObj.valueObject;
arguments.add(valueObj);
}

arguments.reversed;

// Run the function!
final funcResult = funcDef.function(arguments);

// Convert return value (if any) to the a type that the ink engine can use
RuntimeObject returnObj = null;
if (funcResult != null) {
returnObj = Value.create(funcResult);
assert(returnObj != null, "Could not create ink value from returned object of type ${funcResult.runtimeType}");
} else {
returnObj = RuntimeVoid();
}

state.pushEvaluationStack(returnObj);
}

typedef ExternalFunction = Object Function(List<Object> args);

void bindExternalFunctionGeneral(String funcName, ExternalFunction func,
{bool lookaheadSafe = true}) {
if (asyncCantBind) {
throw Exception("Cannot bind an external function asynchronously");
}
assert(!_externals.containsKey(funcName), "Function '$funcName' has already been bound.");
_externals[funcName] = ExternalFunctionDef(
function: func,
lookaheadSafe: lookaheadSafe,
);
}

Object tryCoerce<T>(Object value) {
if (value == null) return null;

if (value is T) return value;

if (value is double && T == int) {
final intVal = (value as double).round();
return intVal;
}

if (value is int && T == double) {
final doubleVal = (value as int).toDouble();
return doubleVal;
}

if (value is int && T == bool) {
final intVal = value as int;
return intVal == 0 ? false : true;
}

if (value is bool && T == int) {
final boolVal = value as bool;
return boolVal ? 1 : 0;
}

if (T == String) {
return value.toString();
}

assert(false, "Failed to cast ${value.runtimeType} to ${T.runtimeType}");
return null;
}

void bindExternalFunction(String funcName, Object Function() func,
{bool lookaheadSafe = false}) {
assert(func != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<Object> args) {
assert(args.isEmpty, "External function expected no arguments");
return func();
}, lookaheadSafe: lookaheadSafe);
}

void bindExternalFunction(String funcName, void Function() act,
{bool lookaheadSafe = false}) {
assert(act != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<Object> args) {
assert(args.isEmpty, "External function expected no arguments");
act();
return null;
}, lookaheadSafe: lookaheadSafe);
}

void bindExternalFunction<T>(String funcName, Object Function(T) func,
{bool lookaheadSafe = false}) {
assert(func != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<Object> args) {
assert(args.length == 1, "External function expected one argument");
return func(tryCoerce<T>(args[0]) as T);
}, lookaheadSafe: lookaheadSafe);
}

void bindExternalFunction<T>(
String funcName, void Function(T) act,
{bool lookaheadSafe = false}) {
assert(act != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 1, "External function expected one argument");
act(args[0] as T);
return null;
}, lookaheadSafe);
}

void bindExternalFunction<T1, T2>(
String funcName, Object Function(T1, T2) func,
{bool lookaheadSafe = false}) {
assert(func != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 2, "External function expected two arguments");
return func(args[0] as T1, args[1] as T2);
}, lookaheadSafe);
}

void bindExternalFunction<T1, T2>(
String funcName, void Function(T1, T2) act,
{bool lookaheadSafe = false}) {
assert(act != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 2, "External function expected two arguments");
act(args[0] as T1, args[1] as T2);
return null;
}, lookaheadSafe);
}

void bindExternalFunction<T1, T2, T3>(
String funcName, Object Function(T1, T2, T3) func,
{bool lookaheadSafe = false}) {
assert(func != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 3, "External function expected three arguments");
return func(args[0] as T1, args[1] as T2, args[2] as T3);
}, lookaheadSafe);
}

void bindExternalFunction<T1, T2, T3>(
String funcName, void Function(T1, T2, T3) act,
{bool lookaheadSafe = false}) {
assert(act != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 3, "External function expected three arguments");
act(args[0] as T1, args[1] as T2, args[2] as T3);
return null;
}, lookaheadSafe);
}

void bindExternalFunction<T1, T2, T3, T4>(
String funcName, Object Function(T1, T2, T3, T4) func,
{bool lookaheadSafe = false}) {
assert(func != null, "Can't bind a null function");



bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 4, "External function expected four arguments");
return func(
args[0] as T1, args[1] as T2, args[2] as T3, args[3] as T4);
}, lookaheadSafe);
}

void bindExternalFunction<T1, T2, T3, T4>(
String funcName, void Function(T1, T2, T3, T4) act,
{bool lookaheadSafe = false}) {
assert(act != null, "Can't bind a null function");

bindExternalFunctionGeneral(funcName, (List<dynamic> args) {
assert(args.length == 4, "External function expected four arguments");
act(args[0] as T1, args[1] as T2, args[2] as T3, args[3] as T4);
return null;
}, lookaheadSafe);
}

void unbindExternalFunction(String funcName) {
if (asyncCantUnbind) {
throw Exception("Cannot unbind an external function asynchronously");
}
assert(_externals.containsKey(funcName),
"Function '$funcName' has not been bound.");
_externals.remove(funcName);
}

void validateExternalBindings() {
final missingExternals = <String>{};

validateExternalBindings(_mainContentContainer, missingExternals);
_hasValidatedExternals = true;

// No problem! Validation complete
if (missingExternals.isEmpty) {
_hasValidatedExternals = true;
}

// Error for all missing externals
else {
final message = "ERROR: Missing function binding for external${missingExternals.length > 1 ? 's' : ''}: '${missingExternals.join("', ")}' ${allowExternalFunctionFallbacks ? ', and no fallback ink function found.' : ' (ink fallbacks disabled)'}";
error(message);
}
}

void validateExternalBindings(Container c, Set<String> missingExternals) {
for (final innerContent in c.content) {
if (innerContent is Container || !innerContent.hasValidName) {
validateExternalBindings(innerContent, missingExternals);
}
}
for (final innerKeyValue in c.namedContent.entries) {
validateExternalBindings(innerKeyValue.value, missingExternals);
}
}

void validateExternalBindings(Object o, Set<String> missingExternals) {
if (o is Container) {
validateExternalBindings(o, missingExternals);
return;
}

final divert = o as Divert;
if (divert != null && divert.isExternal) {
final name = divert.targetPathString;

if (!_externals.containsKey(name)) {
if (allowExternalFunctionFallbacks) {
final fallbackFound = _mainContentContainer.namedContent.containsKey(name);
if (!fallbackFound) {
missingExternals.add(name);
}
} else {
missingExternals.add(name);
}
}
}
}

typedef VariableObserver = void Function(String variableName, Object newValue);

void observeVariable(String variableName, VariableObserver observer) {
if (asyncCantObserve) {
throw Exception("Cannot observe a new variable asynchronously");
}

if (_variableObservers == null) {
_variableObservers = {};
}

if (!state.variablesState.globalVariableExistsWithName(variableName)) {
throw Exception(
"Cannot observe variable '$variableName' because it wasn't declared in the ink story.");
}

if (_variableObservers.containsKey(variableName)) {
_variableObservers[variableName] += observer;
} else {
_variableObservers[variableName] = observer;
}
}

void observeVariables(List<String> variableNames, VariableObserver observer) {
for (var varName in variableNames) {
observeVariable(varName, observer);
}
}

void removeVariableObserver({VariableObserver observer, String specificVariableName}) {
if (asyncCantObserve) {
throw Exception("Cannot remove a variable observer asynchronously");
}

if (_variableObservers == null) {
return;
}

// Remove observer for this specific variable
if (specificVariableName != null) {
if (_variableObservers.containsKey(specificVariableName)) {
if (observer != null) {
_variableObservers[specificVariableName] -= observer;
if (_variableObservers[specificVariableName] == null) {
_variableObservers.remove(specificVariableName);
}
} else {
_variableObservers.remove(specificVariableName);
}
}
}

// Remove observer for all variables
else if (observer != null) {
var keys = _variableObservers.keys.toList();
for (var varName in keys) {
_variableObservers[varName] -= observer;
if (_variableObservers[varName] == null) {
_variableObservers.remove(varName);
}
}
}
}

void variableStateDidChange(String variableName, RuntimeObject newValueObj) {
if (_variableObservers == null) {
return;
}

VariableObserver observers = null;
if (_variableObservers.containsKey(variableName)) {
if (!(newValueObj is Value)) {
throw Exception("Tried to get the value of a variable that isn't a standard type");
}
var val = newValueObj as Value;

observers(variableName, val.valueObject);
}
}

List<String> get globalTags {
return tagsAtStartOfFlowContainerWithPathString("");
}

List<String> tagsForContentAtPath(String path) {
return tagsAtStartOfFlowContainerWithPathString(path);
}

List<String> tagsAtStartOfFlowContainerWithPathString(String pathString) {
var path = Runtime.Path(pathString);

// Expected to be global story, knot, or stitch
var flowContainer = contentAtPath(path).container;
while (true) {
var firstContent = flowContainer.content[0];
if (firstContent is Container) {
flowContainer = firstContent as Container;
} else {
break;
}
}

// Any initial tag objects count as the "main tags" associated with that story/knot/stitch
var inTag = false;
List<String> tags;
for (var c in flowContainer.content) {
var command = c as Runtime.ControlCommand;
if (command != null) {
if (command.commandType == Runtime.ControlCommand.CommandType.BeginTag) {
inTag = true;
} else if (command.commandType == Runtime.ControlCommand.CommandType.EndTag) {
inTag = false;
}
} else if (inTag) {
var str = c as Runtime.StringValue;
if (str != null) {
if (tags == null) {
tags = [];
}
tags.add(str.value);
} else {
error("Tag contained non-text content. Only plain text is allowed when using globalTags or TagsAtContentPath. If you want to evaluate dynamic content, you need to use story.Continue().");
}
} else {
// Any other content - we're done
// We only recognize initial text-only tags
break;
}
}

return tags;
}

String buildStringOfHierarchy() {
var sb = StringBuffer();

mainContentContainer.buildStringOfHierarchy(sb, 0, state.currentPointer.resolve());

return sb.toString();
}

String buildStringOfContainer(Container container) {
var sb = StringBuffer();

container.buildStringOfHierarchy(sb, 0, state.currentPointer.resolve());

return sb.toString();
}

void nextContent() {
// Setting previousContentObject is critical for VisitChangedContainersDueToDivert
state.previousPointer = state.currentPointer;

// Divert step?
if (!state.divertedPointer.isNull) {
state.currentPointer = state.divertedPointer;
state.divertedPointer = Pointer.nullPointer();

// Internally uses state.previousContentObject and state.currentContentObject
visitChangedContainersDueToDivert();

// Diverted location has valid content?
if (!state.currentPointer.isNull) {
return;
}
}

var successfulPointerIncrement = incrementContentPointer();

if (!successfulPointerIncrement) {
var didPop = false;

if (state.callStack.canPop(PushPopType.Function)) {
// Pop from the call stack
state.popCallStack(PushPopType.Function);

if (state.inExpressionEvaluation) {
state.pushEvaluationStack(Runtime.Void());
}

didPop = true;
} else if (state.callStack.canPopThread) {
state.callStack.popThread();

didPop = true;
} else {
state.tryExitFunctionEvaluationFromGame();
}

// Step past the point where we last called out
if (didPop && !state.currentPointer.isNull) {
nextContent();
}
}
}

bool incrementContentPointer() {
bool successfulIncrement = true;

var pointer = state.callStack.currentElement.currentPointer;
pointer.index++;

while (pointer.index >= pointer.container.content.length) {
successfulIncrement = false;

Container nextAncestor = pointer.container.parent as Container;
if (nextAncestor == null) {
break;
}

var indexInAncestor = nextAncestor.content.indexOf(pointer.container);
if (indexInAncestor == -1) {
break;
}

pointer = Pointer(nextAncestor, indexInAncestor);

// Increment to the next content in the outer container
pointer.index++;

successfulIncrement = true;
}

if (!successfulIncrement) {
pointer = Pointer.nullPointer();
}

state.callStack.currentElement.currentPointer = pointer;

return successfulIncrement;
}

bool tryFollowDefaultInvisibleChoice() {
var allChoices = state.currentChoices;

// Is a default invisible choice the ONLY choice?
var invisibleChoices = allChoices.where((c) => c.isInvisibleDefault).toList();
if (invisibleChoices.isEmpty || allChoices.length > invisibleChoices.length) {
return false;
}

var choice = invisibleChoices[0];

state.callStack.currentThread = choice.threadAtGeneration;

if (_stateSnapshotAtLastNewline != null) {
state.callStack.currentThread = state.callStack.forkThread();
}

choosePath(choice.targetPath, incrementingTurnIndex: false);

return true;
}

int nextSequenceShuffleIndex() {
var numElementsIntVal = state.popEvaluationStack() as IntValue;
if (numElementsIntVal == null) {
error("expected number of elements in sequence for shuffle index");
return 0;
}

var seqContainer = state.currentPointer.container;

int numElements = numElementsIntVal.value;

var seqCountVal = state.popEvaluationStack() as IntValue;
var seqCount = seqCountVal.value;
var loopIndex = seqCount ~/ numElements;
var iterationIndex = seqCount % numElements;

var seqPathStr = seqContainer.path.toString();
int sequenceHash = 0;
for (var c in seqPathStr.runes) {
sequenceHash += c;
}
var randomSeed = sequenceHash + loopIndex + state.storySeed;
var random = Random(randomSeed);

var unpickedIndices = List<int>.generate(numElements, (i) => i);

for (var i = 0; i <= iterationIndex; ++i) {
var chosen = random.nextInt(unpickedIndices.length);
var chosenIndex = unpickedIndices[chosen];
unpickedIndices.removeAt(chosen);

if (i == iterationIndex) {
return chosenIndex;
}
}

throw Exception("Should never reach here");
}

void error(String message, {bool useEndLineNumber = false}) {
var e = StoryException(message);
e.useEndLineNumber = useEndLineNumber;
throw e;
}

void warning(String message) {
addError(message, isWarning: true);
}

void addError(String message,
{bool isWarning = false, bool useEndLineNumber = false}) {
var dm = currentDebugMetadata;

var errorTypeStr = isWarning ? "WARNING" : "ERROR";

if (dm != null) {
int lineNum = useEndLineNumber ? dm.endLineNumber : dm.startLineNumber;
message =
"RUNTIME $errorTypeStr: '${dm.fileName}' line $lineNum: $message";
} else if (!state.currentPointer.isNull) {
message = "RUNTIME $errorTypeStr: (${state.currentPointer.path}): $message";
} else {
message = "RUNTIME $errorTypeStr: $message";
}

state.addError(message, isWarning);

// In a broken state don't need to know about any other errors.
if (!isWarning) state.forceEnd();
}

void assert(bool condition, {String message, List<Object> formatParams}) {
if (!condition) {
if (message == null) {
message = "Story assert";
}
if (formatParams != null && formatParams.isNotEmpty) {
message = message.replaceAllMapped(
RegExp(r'{}'), (match) => formatParams.removeAt(0).toString());
}

throw Exception("$message $currentDebugMetadata");
}
}

DebugMetadata get currentDebugMetadata {
DebugMetadata dm;

// Try to get from the current path first
var pointer = state.currentPointer;
if (!pointer.isNull) {
dm = pointer.resolve().debugMetadata;
if (dm != null) {
return dm;
}
}

// Move up callstack if possible
for (var i = state.callStack.elements.length - 1; i >= 0; --i) {
pointer = state.callStack.elements[i].currentPointer;
if (!pointer.isNull && pointer.resolve() != null) {
dm = pointer.resolve().debugMetadata;
if (dm != null) {
return dm;
}
}
}

for (var i = state.outputStream.length - 1; i >= 0; --i) {
var outputObj = state.outputStream[i];
dm = outputObj.debugMetadata;
if (dm != null) {
return dm;
}
}

return null;
}

int get currentLineNumber {
var dm = currentDebugMetadata;
if (dm != null) {
return dm.startLineNumber;
}
return 0;
}

Container get mainContentContainer {
if (_temporaryEvaluationContainer != null) {
return _temporaryEvaluationContainer;
} else {
return _mainContentContainer;
}
}

Container _mainContentContainer;
ListDefinitionsOrigin _listDefinitions;

struct ExternalFunctionDef {
ExternalFunction function;
bool lookaheadSafe;
}

Map<String, ExternalFunctionDef> _externals;
Map<String, VariableObserver> _variableObservers;
bool _hasValidatedExternals;

Container _temporaryEvaluationContainer;

StoryState _state;

bool _asyncContinueActive;
StoryState _stateSnapshotAtLastNewline = null;
bool _sawLookaheadUnsafeFunctionAfterNewline = false;

int _recursiveContinueCount = 0;

bool _asyncSaving;

Profiler _profiler;
}
}