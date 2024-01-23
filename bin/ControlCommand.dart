import 'CommandType.dart';

class ControlCommand extends Object {
  CommandType commandType;

  ControlCommand(this.commandType);

  ControlCommand.evalStart() : commandType = CommandType.evalStart;

  ControlCommand.evalOutput() : commandType = CommandType.evalOutput;

  ControlCommand.evalEnd() : commandType = CommandType.evalEnd;

  ControlCommand.duplicate() : commandType = CommandType.duplicate;

  ControlCommand.popEvaluatedValue()
      : commandType = CommandType.popEvaluatedValue;

  ControlCommand.popFunction() : commandType = CommandType.popFunction;

  ControlCommand.popTunnel() : commandType = CommandType.popTunnel;

  ControlCommand.beginString() : commandType = CommandType.beginString;

  ControlCommand.endString() : commandType = CommandType.endString;

  ControlCommand.noOp() : commandType = CommandType.noOp;

  ControlCommand.choiceCount() : commandType = CommandType.choiceCount;

  ControlCommand.turns() : commandType = CommandType.turns;

  ControlCommand.turnsSince() : commandType = CommandType.turnsSince;

  ControlCommand.readCount() : commandType = CommandType.readCount;

  ControlCommand.random() : commandType = CommandType.random;

  ControlCommand.seedRandom() : commandType = CommandType.seedRandom;

  ControlCommand.visitIndex() : commandType = CommandType.visitIndex;

  ControlCommand.sequenceShuffleIndex()
      : commandType = CommandType.sequenceShuffleIndex;

  ControlCommand.startThread() : commandType = CommandType.startThread;

  ControlCommand.done() : commandType = CommandType.done;

  ControlCommand.end() : commandType = CommandType.end;

  ControlCommand.listFromInt() : commandType = CommandType.listFromInt;

  ControlCommand.listRange() : commandType = CommandType.listRange;

  ControlCommand.listRandom() : commandType = CommandType.listRandom;

  ControlCommand.beginTag() : commandType = CommandType.beginTag;

  ControlCommand.endTag() : commandType = CommandType.endTag;

  ControlCommand.notSet() : commandType = CommandType.notSet;

  @override
  Object copy() {
    return ControlCommand(commandType);
  }

  @override
  String toString() {
    return commandType.toString();
  }
}
