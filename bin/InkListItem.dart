class InkListItem {
  final String? originName;
  final String? itemName;

  InkListItem(this.originName, this.itemName);

  InkListItem.fromString(String fullName, originName, itemName) {
    final nameParts = fullName.split('.');
    originName = nameParts[0];
    itemName = nameParts[1];
  }

  static InkListItem get nullItem => InkListItem(null, null);

  bool get isNull => originName == null && itemName == null;

  String get fullName => (originName ?? '?') + '.' + itemName!;

  @override
  String toString() => fullName;

  @override
  bool operator ==(Object other) {
    if (other is InkListItem) {
      return other.itemName == itemName && other.originName == originName;
    }
    return false;
  }

  @override
  int get hashCode {
    var originCode = 0;
    final itemCode = itemName.hashCode;
    if (originName != null) originCode = originName.hashCode;
    return originCode + itemCode;
  }
}
