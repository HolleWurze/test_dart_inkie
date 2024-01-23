import 'Path.dart';
import 'CallStackThread.dart';

class Choice {
  String text;
  String get pathStringOnChoice => targetPath.toString();
  set pathStringOnChoice(String value) => targetPath = Path(value);

  String sourcePath;
  int index;
  Path targetPath;
  CallStackThread threadAtGeneration;
  int originalThreadIndex;
  bool isInvisibleDefault;
  List<String> tags;

  Choice() : text = '', sourcePath = '', index = 0, originalThreadIndex = 0, isInvisibleDefault = false, tags = [];
}
