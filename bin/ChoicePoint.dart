import 'Path.dart';

class ChoicePoint extends RuntimeObject {
  Path? _pathOnChoice;

  ChoicePoint(bool onceOnly) {
    this.onceOnly = onceOnly;
  }

  ChoicePoint() : this(true);

  Path get pathOnChoice {
    if (_pathOnChoice != null && _pathOnChoice!.isRelative) {
      var choiceTargetObj = choiceTarget;
      if (choiceTargetObj != null) {
        _pathOnChoice = choiceTargetObj.path;
      }
    }
    return _pathOnChoice!;
  }

  set pathOnChoice(Path value) {
    _pathOnChoice = value;
  }

  Container? get choiceTarget {
    return resolvePath(_pathOnChoice!).container;
  }

  String get pathStringOnChoice {
    return compactPathString(pathOnChoice);
  }

  set pathStringOnChoice(String value) {
    pathOnChoice = Path(value);
  }

  bool hasCondition = false;
  bool hasStartContent = false;
  bool hasChoiceOnlyContent = false;
  bool onceOnly = false;
  bool isInvisibleDefault = false;

  int get flags {
    int flags = 0;
    if (hasCondition) flags |= 1;
    if (hasStartContent) flags |= 2;
    if (hasChoiceOnlyContent) flags |= 4;
    if (isInvisibleDefault) flags |= 8;
    if (onceOnly) flags |= 16;
    return flags;
  }

  set flags(int value) {
    hasCondition = (value & 1) > 0;
    hasStartContent = (value & 2) > 0;
    hasChoiceOnlyContent = (value & 4) > 0;
    isInvisibleDefault = (value & 8) > 0;
    onceOnly = (value & 16) > 0;
  }

  @override
  String toString() {
    int? targetLineNum = debugLineNumberOfPath(pathOnChoice);
    String targetString = pathOnChoice.toString();

    if (targetLineNum != null) {
      targetString = " line $targetLineNum($targetString)";
    }

    return "Choice: -> $targetString";
  }
}
