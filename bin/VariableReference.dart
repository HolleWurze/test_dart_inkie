import 'Container.dart';
import 'Path.dart';

class VariableReference {
  String? name;
  Path? pathForCount;

  Container? get containerForCount => ResolvePath(pathForCount)?.container;

  String? get pathStringForCount => pathForCount == null ? null : CompactPathString(pathForCount);
  set pathStringForCount(String? value) => pathForCount = value == null ? null : Path(value);

  VariableReference({this.name});
  VariableReference.defaultConstructor();

  @override
  String toString() {
    if (name != null) {
      return "var($name)";
    } else {
      var pathStr = pathStringForCount;
      return "read_count($pathStr)";
    }
  }
}
