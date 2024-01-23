import 'dart:convert';
import 'Thread.dart';
import 'SimpleJson.dart';

class CallStack {

  Thread copy() {
  var copy = Thread();
  copy.threadIndex = threadIndex;
  copy.callstack.addAll(callstack.map((e) => e.copy()));
  copy.previousPointer = previousPointer;
  return copy;
  }

  void writeJson(SimpleJson.Writer writer) {
  writer.writeObjectStart();

  // callstack
  writer.writePropertyStart('callstack');
  writer.writeArrayStart();
  for (var el in callstack) {
  writer.writeObjectStart();
  if (!el.currentPointer.isNull) {
  writer.writeProperty('cPath', el.currentPointer.container.path.componentsString);
  writer.writeProperty('idx', el.currentPointer.index);
  }

  writer.writeProperty('exp', el.inExpressionEvaluation);
  writer.writeProperty('type', el.type.index);

  if (el.temporaryVariables.isNotEmpty) {
  writer.writePropertyStart('temp');
  Json.writeDictionaryRuntimeObjs(writer, el.temporaryVariables);
  writer.writePropertyEnd();
  }

  writer.writeObjectEnd();
  }
  writer.writeArrayEnd();
  writer.writePropertyEnd();

  // threadIndex
  writer.writeProperty('threadIndex', threadIndex);

  if (!previousPointer.isNull) {
  writer.writeProperty('previousContentObject', previousPointer.resolve().path.toString());
  }

  writer.writeObjectEnd();
  }
  }

  List<Thread> _threads;
  int _threadCounter;
  Pointer _startOfRoot;

  List<Element> get callStack => currentThread.callstack;
  int get depth => elements.length;
  Element get currentElement => currentThread.callstack.last;
  int get currentElementIndex => callStack.length - 1;
  Thread get currentThread => _threads.last;
  set currentThread(Thread value) {
  assert(_threads.length == 1, "Shouldn't be directly setting the current thread when we have a stack of them");
  _threads.clear();
  _threads.add(value);
  }
  bool get canPop => callStack.length > 1;

  CallStack(Story storyContext) {
  _startOfRoot = Pointer.startOf(storyContext.rootContentContainer);
  reset();
  }

  CallStack.copy(CallStack toCopy) {
  _threads = <Thread>[];
  for (var otherThread in toCopy._threads) {
  _threads.add(otherThread.copy());
  }
  _threadCounter = toCopy._threadCounter;
  _startOfRoot = toCopy._startOfRoot;
  }

  void reset() {
  _threads = <Thread>[];
  _threads.add(Thread());

  _threads[0].callstack.add(Element(PushPopType.Tunnel, _startOfRoot));
  }

  void setJsonToken(Map<String, dynamic> jObject, Story storyContext) {
  _threads.clear();

  var jThreads = jObject['threads'];

  for (var jThreadTok in jThreads) {
  var jThreadObj = jThreadTok.cast<String, dynamic>();
  var thread = Thread.fromMap(jThreadObj, storyContext);
  _threads.add(thread);
  }

  _threadCounter = jObject['threadCounter'];
  _startOfRoot = Pointer.startOf(storyContext.rootContentContainer);
  }

  void writeJson(SimpleJson.Writer w) {
  w.writeObject((writer) {
  writer.writePropertyStart('threads');
  writer.writeArrayStart();

  for (var thread in _threads) {
  thread.writeJson(writer);
  }

  writer.writeArrayEnd();
  writer.writePropertyEnd();

  writer.writePropertyStart('threadCounter');
  writer.write(_threadCounter);
  writer.writePropertyEnd();
  });
  }

  void pushThread() {
  var newThread = currentThread.copy();
  _threadCounter++;
  newThread.threadIndex = _threadCounter;
  _threads.add(newThread);
  }

  Thread forkThread() {
  var forkedThread = currentThread.copy();
  _threadCounter++;
  forkedThread.threadIndex = _threadCounter;
  return forkedThread;
  }

  void popThread() {
  if (canPopThread) {
  _threads.remove(currentThread);
  } else {
  throw Exception("Can't pop thread");
  }
  }

  bool get canPopThread => _threads.length > 1 && !elementIsEvaluateFromGame;

  bool get elementIsEvaluateFromGame => currentElement.type == PushPopType.FunctionEvaluationFromGame;

  void push(PushPopType type, {int externalEvaluationStackHeight = 0, int outputStreamLengthWithPushed = 0}) {
  var element = Element(
  type,
  currentElement.currentPointer,
  inExpressionEvaluation: false,
  );

  element.evaluationStackHeightWhenPushed = externalEvaluationStackHeight;
  element.functionStartInOutputStream = outputStreamLengthWithPushed;

  callStack.add(element);
  }

  bool canPop([PushPopType? type]) {
  if (!canPop) return false;
  if (type == null) return true;
  return currentElement.type == type;
  }

  void pop([PushPopType? type]) {
  if (canPop(type)) {
  callStack.removeLast();
  } else {
  throw Exception("Mismatched push/pop in Callstack");
  }
  }

  RuntimeObject? getTemporaryVariableWithName(String name, [int contextIndex = -1]) {
  if (contextIndex == -1) contextIndex = currentElementIndex + 1;
  RuntimeObject? varValue = null;

  var contextElement = callStack[contextIndex - 1];

  if (contextElement.temporaryVariables.containsKey(name)) {
  varValue = contextElement.temporaryVariables[name];
  }

  return varValue;
  }

  void setTemporaryVariable(String name, RuntimeObject value, bool declareNew, [int contextIndex = -1]) {
  if (contextIndex == -1) contextIndex = currentElementIndex + 1;
  var contextElement = callStack[contextIndex - 1];

  if (!declareNew && !contextElement.temporaryVariables.containsKey(name)) {
  throw Exception("Could not find temporary variable to set: $name");
  }

  RuntimeObject? oldValue;
  if (contextElement.temporaryVariables.containsKey(name)) {
  oldValue = contextElement.temporaryVariables[name];
  ListValue.retainListOriginsForAssignment(oldValue, value);
  }

  contextElement.temporaryVariables[name] = value;
  }

  int contextForVariableNamed(String name) {
  if (currentElement.temporaryVariables.containsKey(name)) {
  return currentElementIndex + 1;
  } else {
  return 0;
  }
  }

  Thread threadWithIndex(int index) {
  return _threads.firstWhere((t) => t.threadIndex == index);
  }

  String get callStackTrace {
  var sb = StringBuffer();

  for (var t = 0; t < _threads.length; t++) {
  var thread = _threads[t];
  var isCurrent = (t == _threads.length - 1);
  sb.write("=== THREAD ${t + 1}/${_threads.length} ${isCurrent ? "(current) " : ""}===\n");

  for (var i = 0; i < thread.callstack.length; i++) {
  if (thread.callstack[i].type == PushPopType.Function) {
  sb.write("  [FUNCTION] ");
  } else {
  sb.write("  [TUNNEL] ");
  }

  var pointer = thread.callstack[i].currentPointer;
  if (!pointer.isNull) {
  sb.write("<SOMEWHERE IN ${pointer.container.path.toString()}>\n");
  }
  }
  }

  return sb.toString();
  }

  List

  <

  Element

  >

  get

  elements

  =>

  callStack;
}
