import 'Container.dart';

class StatePatch {
  Map<String, dynamic> _globals;
  Set<String> _changedVariables;
  Map<Container, int> _visitCounts;
  Map<Container, int> _turnIndices;

  StatePatch([StatePatch? toCopy])
      : _globals = toCopy?._globals ?? <String, dynamic>{},
        _changedVariables = toCopy?._changedVariables ?? <String>{},
        _visitCounts = toCopy?._visitCounts ?? <Container, int>{},
        _turnIndices = toCopy?._turnIndices ?? <Container, int>{}

  Map<String, dynamic> get globals => _globals;
  Set<String> get changedVariables => _changedVariables;
  Map<Container, int> get visitCounts => _visitCounts;
  Map<Container, int> get turnIndices => _turnIndices;

  bool tryGetGlobal(String name, out dynamic value) {
  return _globals.tryGetValue(name, out value);
  }

  void setGlobal(String name, dynamic value) {
  _globals[name] = value;
  }

  void addChangedVariable(String name) {
  _changedVariables.add(name);
  }

  bool tryGetVisitCount(Container container, out int count) {
  return _visitCounts.tryGetValue(container, out count);
  }

  void setVisitCount(Container container, int count) {
  _visitCounts[container] = count;
  }

  void setTurnIndex(Container container, int index) {
  _turnIndices[container] = index;
  }

  bool tryGetTurnIndex(Container container, out int index) {
  return _turnIndices.tryGetValue(container, out index);
  }
}
