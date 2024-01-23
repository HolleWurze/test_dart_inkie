import 'PushPopType.dart';
import 'Pointer.dart';
import 'Object.dart';

class Element {
    Pointer currentPointer;
    bool inExpressionEvaluation;
    Map<String, Object> temporaryVariables;
    PushPopType type;
    int evaluationStackHeightWhenPushed;
    int functionStartInOutputStream;

    Element(this.type, Pointer pointer,
        {this.inExpressionEvaluation = false}) {
      currentPointer = pointer;
      temporaryVariables = <String, Object>{};
    }

  Element copy() {
    var copy = Element(type, currentPointer,
        inExpressionEvaluation: inExpressionEvaluation);
    copy.temporaryVariables =
        Map<String, Object>.from(temporaryVariables);
    copy.evaluationStackHeightWhenPushed = evaluationStackHeightWhenPushed;
    copy.functionStartInOutputStream = functionStartInOutputStream;
    return copy;
  }
}
