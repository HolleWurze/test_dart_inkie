import 'ListDefinition.dart';
import 'Value.dart';

class ListDefinitionsOrigin {
  final Map<String, ListDefinition> _lists = {};
  final Map<String, ListValue> _allUnambiguousListValueCache = {};

  List<ListDefinition> get lists => _lists.values.toList();

  ListDefinitionsOrigin(List<ListDefinition> lists) {
    for (var list in lists) {
      _lists[list.name] = list;
      for (var itemWithValue in list.items.entries) {
        var listValue = ListValue(itemWithValue.key, itemWithValue.value);
        _allUnambiguousListValueCache[itemWithValue.key.itemName] = listValue;
        _allUnambiguousListValueCache[itemWithValue.key.fullName] = listValue;
      }
    }
  }

  bool tryListGetDefinition(String name, out ListDefinition def) {
  return _lists.containsKey(name) ? def = _lists[name], true : false;
  }

  ListValue? findSingleItemListWithName(String name) {
  return _allUnambiguousListValueCache[name];
  }
}
