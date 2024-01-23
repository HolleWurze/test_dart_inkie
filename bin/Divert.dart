import 'PushPopType.dart';
import 'Path.dart';
import 'Pointer.dart';
import 'Container.dart';

class Divert extends Object {
  Path? _targetPath;
  Pointer _targetPointer = Pointer.nullPointer;
  String? variableDivertName;

  Divert() {
    pushesToStack = false;
  }

  Divert.withStackPushType(PushPopType stackPushType) {
    pushesToStack = true;
    this.stackPushType = stackPushType;
  }

  Path? get targetPath {
    if (_targetPath != null && _targetPath!.isRelative) {
      final targetObj = targetPointer.resolve();
      if (targetObj != null) {
        _targetPath = targetObj.path;
      }
    }
    return _targetPath;
  }

  set targetPath(Path? value) {
    _targetPath = value;
    _targetPointer = Pointer.nullPointer;
  }

  Pointer get targetPointer {
    if (_targetPointer.isNull) {
      final targetObj = resolvePath(_targetPath!).obj;
      if (_targetPath!.lastComponent!.isIndex) {
        _targetPointer.container = targetObj.parent as Container?;
        _targetPointer.index = _targetPath!.lastComponent!.index;
      } else {
        _targetPointer = Pointer.startOf(targetObj as Container);
      }
    }
    return _targetPointer;
  }

  String? get targetPathString {
    if (targetPath == null) return null;
    return compactPathString(targetPath!);
  }

  set targetPathString(String? value) {
    if (value == null) {
      targetPath = null;
    } else {
      targetPath = Path(value);
    }
  }

  bool get hasVariableTarget {
    return variableDivertName != null;
  }

  bool pushesToStack = false;
  PushPopType? stackPushType;

  bool isExternal = false;
  int externalArgs = 0;
  bool isConditional = false;

  @override
  bool operator ==(Object other) {
    if (other is Divert) {
      if (hasVariableTarget == other.hasVariableTarget) {
        if (hasVariableTarget) {
          return variableDivertName == other.variableDivertName;
        } else {
          return targetPath == other.targetPath;
        }
      }
    }
    return false;
  }

  @override
  int get hashCode {
    if (hasVariableTarget) {
      const variableTargetSalt = 12345;
      return variableDivertName.hashCode + variableTargetSalt;
    } else {
      const pathTargetSalt = 54321;
      return targetPath!.hashCode + pathTargetSalt;
    }
  }

  @override
  String toString() {
    if (hasVariableTarget) {
      return 'Divert(variable: $variableDivertName)';
    } else if (targetPath == null) {
      return 'Divert(null)';
    } else {
      final sb = StringBuffer();

      final targetStr = targetPath!.toString();
      final targetLineNum = debugLineNumberOfPath(targetPath!);
      if (targetLineNum != null) {
        sb.write('line $targetLineNum');
      }

      sb.write('Divert');

      if (isConditional) sb.write('?');

      if (pushesToStack) {
        if (stackPushType == PushPopType.function) {
          sb.write(' function');
        } else {
          sb.write(' tunnel');
        }
      }

      sb.write(' -> $targetPathString');

      if (targetStr.isNotEmpty) {
        sb.write(' ($targetStr)');
      }

      return sb.toString();
    }
  }
}