import 'Container.dart';
import 'Path.dart';

class Pointer {
  Container? container;
  int index;

  Pointer({this.container, this.index = 0});

  Object? resolve() {
    if (index < 0) return container;
    if (container == null) return null;
    if (container!.content.isEmpty) return container;
    if (index >= container!.content.length) return null;
    return container!.content[index];
  }

  bool get isNull => container == null;

  Path? get path {
    if (isNull) return null;
    if (index >= 0) {
      return container!.path.pathByAppendingComponent(PathComponent(index));
    } else {
      return container!.path;
    }
  }

  @override
  String toString() {
    if (container == null) {
      return "Ink Pointer (null)";
    }
    return "Ink Pointer -> ${container!.path.toString()} -- index $index";
  }

  static Pointer startOf(Container container) {
    return Pointer(container: container, index: 0);
  }

  static final Pointer nullPointer = Pointer(container: null, index: -1);
}