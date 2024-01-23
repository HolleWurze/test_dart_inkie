import 'CallStack.dart';
import 'ControlCommand.dart';

class ProfileNode {
  final String key;
  bool openInUI = false;
  List<ProfileNode> _nodes;
  final int _selfSampleCount = 0;
  final double _selfMillisecs = 0;
  final int _totalSampleCount = 0;
  final double _totalMillisecs = 0;

  ProfileNode(this.key);

  bool get hasChildren {
    return _nodes != null && _nodes.isNotEmpty;
  }

  int get totalMillisecs => _totalMillisecs.toInt();

  void addSample(List<String> stack, double duration) {
    addSample(stack, -1, duration);
  }

  void addSampleToNode(List<String> stack, int stackIdx, double duration) {
    final nodeKey = stack[stackIdx];
    _nodes ??= <String, ProfileNode>{};

    if (!_nodes.containsKey(nodeKey)) {
      final node = ProfileNode(nodeKey);
      _nodes[nodeKey] = node;
    }

    _nodes[nodeKey]!.addSample(stack, stackIdx, duration);
  }

  Iterable<MapEntry<String, ProfileNode>> get descendingOrderedNodes {
    if (_nodes == null) return Iterable<MapEntry<String, ProfileNode>>.empty();
    return _nodes.entries.toList()
      ..sort(
          (a, b) => b.value._totalMillisecs.compareTo(a.value._totalMillisecs));
  }

  void printHierarchy(StringBuffer sb, int indent) {
    _pad(sb, indent);

    sb.write('$key: ');
    sb.writeln(ownReport);

    if (_nodes == null) return;

    for (final keyNode in descendingOrderedNodes) {
      keyNode.value.printHierarchy(sb, indent + 1);
    }
  }

  String get ownReport {
    final sb = StringBuffer();
    sb.write('total ');
    sb.write(Profiler.formatMillisecs(_totalMillisecs));
    sb.write(', self ');
    sb.write(Profiler.formatMillisecs(_selfMillisecs));
    sb.write(' ($_selfSampleCount self samples, $_totalSampleCount total)');
    return sb.toString();
  }

  void _pad(StringBuffer sb, int spaces) {
    for (var i = 0; i < spaces; i++) sb.write('   ');
  }

  @override
  String toString() {
    final sb = StringBuffer();
    printHierarchy(sb, 0);
    return sb.toString();
  }
}

class Profiler {
  late ProfileNode _rootNode;
  final _continueWatch = Stopwatch();
  final _stepWatch = Stopwatch();
  final _snapWatch = Stopwatch();
  double _continueTotal = 0;
  double _snapTotal = 0;
  double _stepTotal = 0;
  List<String>? _currStepStack;
  late StepDetails _currStepDetails;
  int _numContinues = 0;
  final List<StepDetails> _stepDetails = [];
  static final double _millisecsPerTick = 1000.0 / Stopwatch().frequency;

  ProfileNode get rootNode => _rootNode;

  Profiler() {
    _rootNode = ProfileNode('');
  }

  String report() {
    final sb = StringBuffer();
    sb.write('$_numContinues CONTINUES / LINES:\n');
    sb.write('TOTAL TIME: ${formatMillisecs(_continueTotal)}\n');
    sb.write('SNAPSHOTTING: ${formatMillisecs(_snapTotal)}\n');
    sb.write(
        'OTHER: ${formatMillisecs(_continueTotal - (_stepTotal + _snapTotal))}\n');
    sb.write(_rootNode.toString());
    return sb.toString();
  }

  void preContinue() {
    _continueWatch.reset();
    _continueWatch.start();
  }

  void postContinue() {
    _continueWatch.stop();
    _continueTotal += millisecs(_continueWatch);
    _numContinues++;
  }

  void preStep() {
    _currStepStack = null;
    _stepWatch.reset();
    _stepWatch.start();
  }

  void step(CallStack callstack) {
    _stepWatch.stop();
    final stack = List<String>.filled(callstack.elements.length, '');
    for (var i = 0; i < stack.length; i++) {
      var stackElementName = '';
      if (!callstack.elements[i].currentPointer.isNull) {
        final objPath = callstack.elements[i].currentPointer.path;

        for (var c = 0; c < objPath.length; c++) {
          final comp = objPath.getComponent(c);
          if (!comp.isIndex) {
            stackElementName = comp.name;
            break;
          }
        }
      }
      stack[i] = stackElementName;
    }

    _currStepStack = stack;
    final currObj = callstack.currentElement.currentPointer.resolve();
    String? stepType;
    final controlCommandStep = currObj as ControlCommand?;
    if (controlCommandStep != null) {
      stepType = '${controlCommandStep.commandType} CC';
    } else {
      stepType = currObj.runtimeType.toString();
    }

    _currStepDetails = StepDetails(
      type: stepType,
      obj: currObj,
    );

    _stepWatch.start();
  }

  void postStep() {
    _stepWatch.stop();
    final duration = millisecs(_stepWatch);
    _stepTotal += duration;
    _rootNode.addSample(_currStepStack!, duration);
    _currStepDetails.time = duration;
    _stepDetails.add(_currStepDetails);
  }

  String stepLengthReport() {
    final sb = StringBuffer();
    sb.writeln('TOTAL: ${_rootNode.totalMillisecs}ms');
    final averageStepTimes = _stepDetails
        .groupMapBy((s) => s.type)
        .entries
        .map((entry) =>
            MapEntry(entry.key, entry.value.map((d) => d.time).average))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    sb.writeln(
        'AVERAGE STEP TIMES: ${averageStepTimes.map((entry) => '${entry.key}: ${entry.value}ms').join(', ')}');
    final accumStepTimes = _stepDetails
        .groupMapBy((s) => '${s.type} (x${s.length})')
        .entries
        .map((entry) => MapEntry(entry.key, entry.value.map((d) => d.time).sum))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    sb.writeln(
        'ACCUMULATED STEP TIMES: ${accumStepTimes.map((entry) => '${entry.key}: ${entry.value}').join(', ')}');
    return sb.toString();
  }

  String megalog() {
    final sb = StringBuffer();
    sb.writeln('Step type\tDescription\tPath\tTime');
    for (final step in _stepDetails) {
      sb.write(step.type);
      sb.write('\t');
      sb.write(step.obj.toString());
      sb.write('\t');
      sb.write(step.obj.path);
      sb.write('\t');
      sb.writeln(step.time.toStringAsFixed(8));
    }
    return sb.toString();
  }

  void preSnapshot() {
    _snapWatch.reset();
    _snapWatch.start();
  }

  void postSnapshot() {
    _snapWatch.stop();
    _snapTotal += millisecs(_snapWatch);
  }

  double millisecs(Stopwatch watch) {
    final ticks = watch.elapsedTicks;
    return ticks * _millisecsPerTick;
  }

  static String formatMillisecs(double num) {
    if (num > 5000) {
      return '${(num / 1000.0).toStringAsFixed(1)} secs';
    } else if (num > 1000) {
      return '${(num / 1000.0).toStringAsFixed(2)} secs';
    } else if (num > 100) {
      return '${num.toInt()} ms';
    } else if (num > 1) {
      return '${num.toStringAsFixed(1)} ms';
    } else if (num > 0.01) {
      return '${num.toStringAsFixed(3)} ms';
    } else {
      return '${num.toString()} ms';
    }
  }
}
