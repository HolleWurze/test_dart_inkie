import 'Element.dart';
import 'PushPopType.dart';
import 'Pointer.dart';
import 'Story.dart';
import 'JsonSerialisation.dart';

class Thread {
  List<Element> callstack;
  int threadIndex;
  Pointer previousPointer;

  Thread() {
    callstack = <Element>[];
  }

  Thread.fromMap(Map<String, dynamic> jThreadObj, Story storyContext) : this() {
    threadIndex = jThreadObj['threadIndex'];

    List<dynamic> jThreadCallstack = jThreadObj['callstack'];
    for (var jElTok in jThreadCallstack) {
      var jElementObj = jElTok.cast<String, dynamic>();

      PushPopType pushPopType = PushPopType.values[jElementObj['type']];

      Pointer pointer = Pointer.nullPointer;

      String? currentContainerPathStr = jElementObj['cPath'];
      if (currentContainerPathStr != null) {
        var threadPointerResult = storyContext.contentAtPath(
            Path(currentContainerPathStr));
        pointer.container = threadPointerResult.container;
        pointer.index = jElementObj['idx'];

        if (threadPointerResult.obj == null) {
          throw Exception(
              "When loading state, internal story location couldn't be found: $currentContainerPathStr. Has the story changed since this save data was created?");
        } else if (threadPointerResult.approximate) {
          storyContext.warning(
              "When loading state, exact internal story location couldn't be found: '$currentContainerPathStr', so it was approximated to '${pointer
                  .container?.path
                  .toString()}' to recover. Has the story changed since this save data was created?");
        }
      }

      bool inExpressionEvaluation = jElementObj['exp'];

      var el = Element(
          pushPopType, pointer, inExpressionEvaluation: inExpressionEvaluation);

      if (jElementObj.containsKey('temp')) {
        el.temporaryVariables = JsonSerialisation.jObjectToDictionaryRuntimeObjs(
            Map<String, dynamic>.from(jElementObj['temp']));
      } else {
        el.temporaryVariables.clear();
      }

      callstack.add(el);
    }

    var prevContentObjPath = jThreadObj['previousContentObject'];
    if (prevContentObjPath != null) {
      var prevPath = Path(prevContentObjPath);
      previousPointer = storyContext.pointerAtPath(prevPath);
    }
  }
}