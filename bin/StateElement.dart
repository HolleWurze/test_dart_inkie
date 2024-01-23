import 'State.dart';

class StateElement {
  State type;
  int childCount;

  StateElement({required this.type, this.childCount = 0});
}