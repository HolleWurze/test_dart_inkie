import 'CallStack.dart';
import 'Story.dart';
import 'Choice.dart';
import 'JsonSerialisation.dart';
import 'Json.dart';

class Flow {
  String name;
  CallStack callStack;
  List<Object> outputStream;
  List<Choice> currentChoices;

  Flow(String name, Story story)
      : name = name,
        callStack = CallStack(story),
        outputStream = [],
        currentChoices = [];

  Flow.fromJson(String name, Story story, Map<String, dynamic> jObject)
      : name = name,
        callStack = CallStack(story)
          ..setJsonToken(jObject['callstack'], story),
        outputStream = JsonSerialisation.jArrayToRuntimeObjList(jObject['outputStream']),
        currentChoices = JsonSerialisation.jArrayToRuntimeObjList<Choice>(
            jObject['currentChoices']) {
    final jChoiceThreadsObj = jObject['choiceThreads'];
    if (jChoiceThreadsObj != null) {
      loadFlowChoiceThreads(
          Map<String, dynamic>.from(jChoiceThreadsObj), story);
    }
  }

  void writeJson(SimpleJsonWriter writer) {
    writer.writeObjectStart();

    writer.writeProperty('callstack', callStack.writeJson);
    writer.writeProperty('outputStream',
            (w) => JsonSerialisation.writeListRuntimeObjs(w, outputStream));

    // choiceThreads: optional
    // Has to come BEFORE the choices themselves are written out
    // since the originalThreadIndex of each choice needs to be set
    bool hasChoiceThreads = false;
    for (var c in currentChoices) {
      c.originalThreadIndex = c.threadAtGeneration.threadIndex;

      final foundActiveThread =
      callStack.threadWithIndex(c.originalThreadIndex);
      if (foundActiveThread == null) {
        if (!hasChoiceThreads) {
          hasChoiceThreads = true;
          writer.writePropertyStart('choiceThreads');
          writer.writeObjectStart();
        }

        writer.writePropertyStart(c.originalThreadIndex.toString());
        c.threadAtGeneration.writeJson(writer);
        writer.writePropertyEnd();
      }
    }

    if (hasChoiceThreads) {
      writer.writeObjectEnd();
      writer.writePropertyEnd();
    }

    writer.writeProperty('currentChoices', (w) {
      w.writeArrayStart();
      for (var c in currentChoices) {
        .writeChoice(w, c);
      }
      w.writeArrayEnd();
    });

    writer.writeObjectEnd();
  }

  // Used both to load old format and current
  void loadFlowChoiceThreads(Map<String, dynamic> jChoiceThreads, Story story) {
    for (var choice in currentChoices) {
      final foundActiveThread =
      callStack.threadWithIndex(choice.originalThreadIndex);
      if (foundActiveThread != null) {
        choice.threadAtGeneration = foundActiveThread.copy();
      } else {
        final jSavedChoiceThread = Map<String, dynamic>.from(
            jChoiceThreads[choice.originalThreadIndex.toString()]);
        choice.threadAtGeneration = CallStack.Thread.fromJson(jSavedChoiceThread, story);
      }
    }
  }
}
