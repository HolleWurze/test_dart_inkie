class ListDefinition {
  final String _name;
  final Map<InkListItem, int> _items = {};

  ListDefinition(String name, Map<String, int> items) : _name = name {
    for (var itemNameAndValue in items.entries) {
      var item = InkListItem(name, itemNameAndValue.key);
      _items[item] = itemNameAndValue.value;
    }
  }

  String get name => _name;

  Map<InkListItem, int> get items {
    if (_items.isEmpty) {
      for (var itemNameAndValue in _itemNameToValues.entries) {
        var item = InkListItem(_name, itemNameAndValue.key);
        _items[item] = itemNameAndValue.value;
      }
    }
    return _items;
  }

  int valueForItem(InkListItem item) {
    return _itemNameToValues[item.itemName] ?? 0;
  }

  bool containsItem(InkListItem item) {
    if (item.originName != _name) return false;
    return _itemNameToValues.containsKey(item.itemName);
  }

  bool containsItemWithName(String itemName) {
    return _itemNameToValues.containsKey(itemName);
  }

  bool tryGetItemWithValue(int val, out InkListItem item) {
  for (var namedItem in _itemNameToValues.entries) {
  if (namedItem.value == val) {
  item = InkListItem(_name, namedItem.key);
  return true;
  }
  }
  item = InkListItem.nullItem();
  return false;
  }

  bool tryGetValueForItem(InkListItem item, out int intVal) {
  return _itemNameToValues.containsKey(item.itemName) &&
  (intVal = _itemNameToValues[item.itemName]!) != null;
  }
}

class InkListItem {
  final String originName;
  final String itemName;

  InkListItem(this.originName, this.itemName);

  static InkListItem nullItem() {
    return InkListItem('', '');
  }
}
