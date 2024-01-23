import 'CommandType.dart';

class Json {
  static final _controlCommandNames =
      List<String?>.filled(CommandType.TOTAL_VALUES.index, null);

  static void initialize() {
    _controlCommandNames[CommandType.evalStart.index] = "ev";
    _controlCommandNames[CommandType.evalOutput.index] = "out";
    _controlCommandNames[CommandType.evalEnd.index] = "/ev";
    _controlCommandNames[CommandType.duplicate.index] = "du";
    _controlCommandNames[CommandType.popEvaluatedValue.index] = "pop";
    _controlCommandNames[CommandType.popFunction.index] = "~ret";
    _controlCommandNames[CommandType.popTunnel.index] = "->->";
    _controlCommandNames[CommandType.beginString.index] = "str";
    _controlCommandNames[CommandType.endString.index] = "/str";
    _controlCommandNames[CommandType.noOp.index] = "nop";
    _controlCommandNames[CommandType.choiceCount.index] = "choiceCnt";
    _controlCommandNames[CommandType.turns.index] = "turn";
    _controlCommandNames[CommandType.turnsSince.index] = "turns";
    _controlCommandNames[CommandType.readCount.index] = "readc";
    _controlCommandNames[CommandType.random.index] = "rnd";
    _controlCommandNames[CommandType.seedRandom.index] = "srnd";
    _controlCommandNames[CommandType.visitIndex.index] = "visit";
    _controlCommandNames[CommandType.sequenceShuffleIndex.index] = "seq";
    _controlCommandNames[CommandType.startThread.index] = "thread";
    _controlCommandNames[CommandType.done.index] = "done";
    _controlCommandNames[CommandType.end.index] = "end";
    _controlCommandNames[CommandType.listFromInt.index] = "listInt";
    _controlCommandNames[CommandType.listRange.index] = "range";
    _controlCommandNames[CommandType.listRandom.index] = "lrnd";
    _controlCommandNames[CommandType.beginTag.index] = "#";
    _controlCommandNames[CommandType.endTag.index] = "/#";

    for (int i = 0; i < CommandType.TOTAL_VALUES.index; ++i) {
      if (_controlCommandNames[i] == null) {
        throw Exception("Control command not accounted for in serialization");
      }
    }
  }
}
