import 'Path.dart';
import 'Container.dart';
import 'INamedContent.dart';

class Object {
  Object parent;
  DebugMetadata debugMetadata;
  DebugMetadata ownDebugMetadata;
  Path path;

  Object() {
    parent = null;
  }

  int? debugLineNumberOfPath(Path path) {
    if (path == null) return null;

    var root = this.rootContentContainer;
    if (root != null) {
      Object targetContent = root
          .contentAtPath(path)
          .obj;
      if (targetContent != null) {
        var dm = targetContent.debugMetadata;
        if (dm != null) {
          return dm.startLineNumber;
        }
      }
    }

    return null;
  }

  Path get path {
    if (_path == null) {
      if (parent == null) {
        _path = Path();
      } else {
        var comps = List<Path.Component>();

        var child = this;
        Container container = child.parent as Container;

        while (container != null) {
          var namedChild = child as INamedContent;
          if (namedChild != null && namedChild.hasValidName) {
            comps.add(Path.Component(namedChild.name));
          } else {
            comps.add(Path.Component(container.content.indexOf(child)));
          }

          child = container;
          container = container.parent as Container;
        }

        _path = Path(components: comps);
      }
    }

    return _path;
  }

  Path _path;

  SearchResult resolvePath(Path path) {
    if (path.isRelative) {
      Container nearestContainer = this as Container;
      if (nearestContainer == null) {
        assert(parent !=
            null, "Can't resolve relative path because we don't have a parent");
        nearestContainer = parent as Container;
        assert(nearestContainer != null, "Expected parent to be a container");
        assert(path
            .getComponent(0)
            .isParent);
        path = path.tail;
      }

      return nearestContainer.contentAtPath(path);
    } else {
      return this.rootContentContainer.contentAtPath(path);
    }
  }

  Path convertPathToRelative(Path globalPath) {
    var ownPath = this.path;
    int minPathLength = globalPath.length < ownPath.length
        ? globalPath.length
        : ownPath.length;
    int lastSharedPathCompIndex = -1;

    for (int i = 0; i < minPathLength; ++i) {
      var ownComp = ownPath.getComponent(i);
      var otherComp = globalPath.getComponent(i);

      if (ownComp == otherComp) {
        lastSharedPathCompIndex = i;
      } else {
        break;
      }
    }

    if (lastSharedPathCompIndex == -1) return globalPath;

    int numUpwardsMoves = (ownPath.length - 1) - lastSharedPathCompIndex;
    var newPathComps = List<Path.Component>();

    for (int up = 0; up < numUpwardsMoves; ++up)
      newPathComps.add(Path.Component.toParent());

    for (int down = lastSharedPathCompIndex + 1; down <
        globalPath.length; ++down)
      newPathComps.add(globalPath.getComponent(down));

    var relativePath = Path(components: newPathComps, relative: true);
    return relativePath;
  }

  String compactPathString(Path otherPath) {
    String globalPathStr = null;
    String relativePathStr = null;
    if (otherPath.isRelative) {
      relativePathStr = otherPath.componentsString;
      globalPathStr = this.path
          .pathByAppendingPath(otherPath)
          .componentsString;
    } else {
      var relativePath = convertPathToRelative(otherPath);
      relativePathStr = relativePath.componentsString;
      globalPathStr = otherPath.componentsString;
    }

    return relativePathStr.length < globalPathStr.length
        ? relativePathStr
        : globalPathStr;
  }

  Container get rootContentContainer {
    Object ancestor = this;
    while (ancestor.parent != null) {
      ancestor = ancestor.parent;
    }
    return ancestor as Container;
  }

  Object copy() {
    throw UnimplementedError('${runtimeType} doesn\'t support copying');
  }

  void setChild<T>(T obj, T value)

  where

  T

      :

  Object {
  if (obj != null) obj.parent = null;

  obj = value;

  if (obj != null) obj.parent = this;
  }

  static bool toBool(Object obj) {
    var isNull = obj == null;
    return !isNull;
  }

  static bool operator ==(Object a, Object b) {
    return identical(a, b);
  }

  static bool operator

  !=

  (Object a, Object b) {
  return !identical(a, b);
  }

  bool operator ==(Object other) {
    return identical(this, other);
  }

  @override
  int get hashCode {
    return super.hashCode;
  }
}
