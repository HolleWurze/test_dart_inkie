class Path {
  static String parentId = "^";

  List<Component> _components;
  bool isRelative = false;

  Path() {
    _components = <Component>[];
  }

  Component getComponent(int index) {
    return _components[index];
  }

  Component get head {
    if (_components.isNotEmpty) {
      return _components.first;
    } else {
      return null;
    }
  }

  Path get tail {
    if (_components.length >= 2) {
      final tailComps = _components.sublist(1);
      return Path.fromComponents(tailComps);
    } else {
      return Path.self;
    }
  }

  int get length {
    return _components.length;
  }

  Component? get lastComponent {
    final lastComponentIdx = _components.length - 1;
    if (lastComponentIdx >= 0) {
      return _components[lastComponentIdx];
    } else {
      return null;
    }
  }

  bool get containsNamedComponent {
    for (final comp in _components) {
      if (!comp.isIndex) {
        return true;
      }
    }
    return false;
  }

  Path.fromComponents(List<Component> components, {bool relative = false}) {
    _components = List<Component>.from(components);
    isRelative = relative;
  }

  Path.fromString(String componentsString) {
    _componentsString = componentsString;
    if (componentsString.isEmpty) {
      return;
    }

    if (componentsString[0] == '.') {
      isRelative = true;
      _componentsString = componentsString.substring(1);
    } else {
      isRelative = false;
    }

    final componentStrings = _componentsString.split('.');
    for (final str in componentStrings) {
      int index;
      if (int.tryParse(str, out index) != null) {
        _components.add(Component(index));
      } else {
        _components.add(Component(str));
      }
    }
  }

  Path.pathByAppendingPath(Path pathToAppend) {
    final p = Path();

    int upwardMoves = 0;
    for (int i = 0; i < pathToAppend._components.length; ++i) {
      if (pathToAppend._components[i].isParent) {
        upwardMoves++;
      } else {
        break;
      }
    }

    for (int i = 0; i < this._components.length - upwardMoves; ++i) {
      p._components.add(this._components[i]);
    }

    for (int i = upwardMoves; i < pathToAppend._components.length; ++i) {
      p._components.add(pathToAppend._components[i]);
    }

    return p;
  }

  Path pathByAppendingComponent(Component c) {
    final p = Path.fromComponents(_components);
    p._components.add(c);
    return p;
  }

  String get componentsString {
    if (_componentsString == null) {
      _componentsString = StringExt.join('.', _components);
      if (isRelative) _componentsString = '.' + _componentsString;
    }
    return _componentsString;
  }

  String _componentsString;

  @override
  String toString() {
    return componentsString;
  }

  @override
  bool operator ==(Object obj) {
    if (identical(this, obj)) return true;
    if (obj is! Path) return false;

    final Path other = obj;
    return other._components.length == _components.length &&
        other.isRelative == isRelative &&
        other._components.every((otherComp) {
          final comp = _components[other._components.indexOf(otherComp)];
          return comp == otherComp;
        });
  }

  @override
  int get hashCode {
    return toString().hashCode;
  }

  static Component toParent() {
    return Component(parentId);
  }

  static Path self = Path.selfPath();

  static Path selfPath() {
    final path = Path();
    path.isRelative = true;
    return path;
  }
}

class Component {
  int index;
  String name;

  Component(int index) {
    assert(index >= 0);
    this.index = index;
    this.name = null;
  }

  Component.fromName(String name) {
    assert(name != null && name.isNotEmpty);
    this.name = name;
    this.index = -1;
  }

  Component.toParent() {
    name = Path.parentId;
  }

  bool get isIndex {
    return index >= 0;
  }

  bool get isParent {
    return name == Path.parentId;
  }

  @override
  String toString() {
    if (isIndex) {
      return index.toString();
    } else {
      return name;
    }
  }

  @override
  bool operator ==(Object obj) {
    if (identical(this, obj)) return true;
    if (obj is! Component) return false;

    final Component other = obj;
    return other.isIndex == isIndex && other.index == index &&
        other.name == name;
  }

  @override
  int get hashCode {
    if (isIndex) {
      return index.hashCode;
    } else {
      return name.hashCode;
    }
  }
}
