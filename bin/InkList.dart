import 'InkListItem.dart';
import 'Story.dart';

class InkList extends Map<InkListItem, int> {
  List<ListDefinition>? origins;

  ListDefinition? get originOfMaxItem {
    if (origins == null) return null;

    final maxOriginName = maxItem.key.originName;
    for (final origin in origins!) {
      if (origin.name == maxOriginName) return origin;
    }

    return null;
  }

  List<String>? get originNames {
    if (isEmpty) return null;

    final _originNames = <String>[];
    for (final itemAndValue in entries) {
      _originNames.add(itemAndValue.key.originName!);
    }

    return _originNames;
  }

  InkList();

  InkList.clone(InkList otherList) {
    if (otherList.origins != null) {
      origins = List<ListDefinition>.from(otherList.origins!);
    }
    addAll(otherList);
  }

  InkList.singleOrigin(String singleOriginListName, Story originStory) {
    setInitialOriginName(singleOriginListName);

    final def =
        originStory.listDefinitions.tryListGetDefinition(singleOriginListName);
    if (def != null) {
      origins = [def];
    } else {
      throw Exception(
          "InkList origin could not be found in story when constructing new list: $singleOriginListName");
    }
  }

  InkList.fromSingleElement(MapEntry<InkListItem, int> singleElement) {
    add(singleElement.key, singleElement.value);
  }

  static InkList fromString(String myListItem, Story originStory) {
    final listValue =
        originStory.listDefinitions.findSingleItemListWithName(myListItem);
    if (listValue != null) {
      return InkList.fromSingleElement(listValue);
    } else {
      throw Exception(
          "Could not find the InkListItem from the string '$myListItem' to create an InkList because it doesn't exist in the original list definition in ink.");
    }
  }

  void addItem(InkListItem item) {
    if (item.originName == null) {
      addItemByName(item.itemName!);
      return;
    }

    for (final origin in origins!) {
      if (origin.name == item.originName) {
        final int? intVal = origin.tryGetValueForItem(item);
        if (intVal != null) {
          this[item] = intVal;
          return;
        } else {
          throw Exception(
              "Could not add the item $item to this list because it doesn't exist in the original list definition in ink.");
        }
      }
    }

    throw Exception(
        "Failed to add item to list because the item was from a new list definition that wasn't previously known to this list. Only items from previously known lists can be used, so that the int value can be found.");
  }

  void addItemByName(String itemName) {
    ListDefinition? foundListDef;

    for (final origin in origins!) {
      if (origin.containsItemWithName(itemName)) {
        if (foundListDef != null) {
          throw Exception(
              "Could not add the item $itemName to this list because it could come from either ${origin.name} or ${foundListDef.name}");
        } else {
          foundListDef = origin;
        }
      }
    }

    if (foundListDef == null) {
      throw Exception(
          "Could not add the item $itemName to this list because it isn't known to any list definitions previously associated with this list.");
    }

    final item = InkListItem(foundListDef.name, itemName);
    final itemVal = foundListDef.valueForItem(item);
    this[item] = itemVal;
  }

  bool containsItemNamed(String itemName) {
    for (final itemAndValue in entries) {
      if (itemAndValue.key.itemName == itemName) return true;
    }
    return false;
  }

  void setInitialOriginName(String initialOriginName) {
    originNames = [initialOriginName];
  }

  void setInitialOriginNames(List<String>? initialOriginNames) {
    originNames = initialOriginNames;
  }

  MapEntry<InkListItem, int> get maxItem {
    MapEntry<InkListItem, int> max =
        MapEntry<InkListItem, int>(InkListItem.nullItem, 0);
    for (final entry in entries) {
      if (max.key.isNull || entry.value > max.value) max = entry;
    }
    return max;
  }

  MapEntry<InkListItem, int> get minItem {
    MapEntry<InkListItem, int> min =
        MapEntry<InkListItem, int>(InkListItem.nullItem, 0);
    for (final entry in entries) {
      if (min.key.isNull || entry.value < min.value) min = entry;
    }
    return min;
  }

  InkList get inverse {
    final list = InkList();
    if (origins != null) {
      for (final origin in origins!) {
        for (final itemAndValue in origin.items) {
          if (!containsKey(itemAndValue.key))
            list[itemAndValue.key] = itemAndValue.value;
        }
      }
    }
    return list;
  }

  InkList get all {
    final list = InkList();
    if (origins != null) {
      for (final origin in origins!) {
        for (final itemAndValue in origin.items) {
          list[itemAndValue.key] = itemAndValue.value;
        }
      }
    }
    return list;
  }

  InkList union(InkList otherList) {
    final union = InkList.clone(this);
    union.addAll(otherList);
    return union;
  }

  InkList intersect(InkList otherList) {
    final intersection = InkList();
    for (final entry in entries) {
      if (otherList.containsKey(entry.key))
        intersection[entry.key] = entry.value;
    }
    return intersection;
  }

  bool hasIntersection(InkList otherList) {
    for (final entry in entries) {
      if (otherList.containsKey(entry.key)) return true;
    }
    return false;
  }

  InkList without(InkList listToRemove) {
    final result = InkList.clone(this);
    for (final entry in listToRemove.entries) {
      result.remove(entry.key);
    }
    return result;
  }

  bool contains(InkList otherList) {
    if (otherList.isEmpty || isEmpty) return false;
    for (final entry in otherList.entries) {
      if (!containsKey(entry.key)) return false;
    }
    return true;
  }

  bool containsItem(String listItemName) {
    for (final itemAndValue in entries) {
      if (itemAndValue.key.itemName == listItemName) return true;
    }
    return false;
  }

  bool greaterThan(InkList otherList) {
    if (isEmpty) return false;
    if (otherList.isEmpty) return true;

    return minItem.value > otherList.maxItem.value;
  }

  bool greaterThanOrEquals(InkList otherList) {
    if (isEmpty) return false;
    if (otherList.isEmpty) return true;

    return minItem.value >= otherList.minItem.value &&
        maxItem.value >= otherList.maxItem.value;
  }

  bool lessThan(InkList otherList) {
    if (otherList.isEmpty) return false;
    if (isEmpty) return true;

    return maxItem.value < otherList.minItem.value;
  }

  bool lessThanOrEquals(InkList otherList) {
    if (otherList.isEmpty) return false;
    if (isEmpty) return true;

    return maxItem.value <= otherList.maxItem.value &&
        minItem.value <= otherList.minItem.value;
  }

  InkList maxAsList() {
    if (isNotEmpty) return InkList.fromSingleElement(maxItem);
    return InkList();
  }

  InkList minAsList() {
    if (isNotEmpty) return InkList.fromSingleElement(minItem);
    return InkList();
  }

  InkList listWithSubRange(Object minBound, Object maxBound) {
    if (isEmpty) return InkList();

    final ordered = orderedItems;
    var minValue = 0;
    var maxValue = int.maxValue;

    if (minBound is int) {
      minValue = minBound;
    } else if (minBound is InkList && minBound.isNotEmpty) {
      minValue = minBound.minItem.value;
    }

    if (maxBound is int) {
      maxValue = maxBound;
    } else if (maxBound is InkList && maxBound.isNotEmpty) {
      maxValue = maxBound.maxItem.value;
    }

    final subList = InkList();
    subList.setInitialOriginNames(originNames);
    for (final item in ordered) {
      if (item.value >= minValue && item.value <= maxValue) {
        subList[item.key] = item.value;
      }
    }

    return subList;
  }

  @override
  bool operator ==(Object other) {
    if (other is InkList) {
      if (other.length != length) return false;

      for (final key in keys) {
        if (!other.containsKey(key)) return false;
      }

      return true;
    }
    return false;
  }

  @override
  int get hashCode {
    var ownHash = 0;
    for (final key in keys) {
      ownHash += key.hashCode;
    }
    return ownHash;
  }

  List<MapEntry<InkListItem, int>> get orderedItems {
    final ordered = <MapEntry<InkListItem, int>>[];
    ordered.addAll(entries);
    ordered.sort((x, y) {
      if (x.value == y.value) {
        return x.key.originName!.compareTo(y.key.originName!);
      } else {
        return x.value.compareTo(y.value);
      }
    });
    return ordered;
  }

  @override
  String toString() {
    final ordered = orderedItems;
    final sb = StringBuffer();
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0) sb.write(', ');
      sb.write(ordered[i].key.itemName);
    }
    return sb.toString();
  }
}
