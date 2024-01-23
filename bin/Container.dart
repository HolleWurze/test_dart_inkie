import 'dart:collection';
import 'Path.dart';
import 'SearchResult.dart';
import 'INamedContent.dart';

class Container extends RuntimeObject implements INamedContent {
  String name;
  List<RuntimeObject> content;
  HashMap<String, INamedContent> namedContent;
  bool visitsShouldBeCounted;
  bool turnIndexShouldBeCounted;
  bool countingAtStartOnly;

  static const int Visits = 1;
  static const int Turns = 2;
  static const int CountStartOnly = 4;

  int countFlags = 0;

  bool get hasValidName {
    return name != null && name.isNotEmpty;
  }

  Path get pathToFirstLeafContent {
    if (_pathToFirstLeafContent == null) {
      _pathToFirstLeafContent = path.PathByAppendingPath(internalPathToFirstLeafContent);
    }
    return _pathToFirstLeafContent;
  }

  Path _pathToFirstLeafContent;

  Container() {
    content = [];
    namedContent = HashMap();
  }

  void AddContent(RuntimeObject contentObj) {
    content.add(contentObj);

    if (contentObj.parent != null) {
      throw Exception("content is already in ${contentObj.parent}");
    }

    contentObj.parent = this;

    TryAddNamedContent(contentObj);
  }

  void AddContentsOfContainer(Container otherContainer) {
    content.addAll(otherContainer.content);
    for (var obj in otherContainer.content) {
      obj.parent = this;
      TryAddNamedContent(obj);
    }
  }

  void TryAddNamedContent(RuntimeObject contentObj) {
    var namedContentObj = contentObj as INamedContent;
    if (namedContentObj != null && namedContentObj.hasValidName) {
      AddToNamedContentOnly(namedContentObj);
    }
  }

  void AddToNamedContentOnly(INamedContent namedContentObj) {
    assert(namedContentObj is RuntimeObject, "Can only add Runtime.Objects to a Runtime.Container");
    var runtimeObj = namedContentObj as RuntimeObject;
    runtimeObj.parent = this;
    namedContent[namedContentObj.name] = namedContentObj;
  }

  SearchResult ContentAtPath(Path path, {int partialPathStart = 0, int partialPathLength = -1}) {
    if (partialPathLength == -1) partialPathLength = path.length;

    var result = SearchResult();
    result.approximate = false;

    Container currentContainer = this;
    RuntimeObject currentObj = this;

    for (var i = partialPathStart; i < partialPathLength; ++i) {
      var comp = path.GetComponent(i);

      if (currentContainer == null) {
        result.approximate = true;
        break;
      }

      var foundObj = currentContainer.ContentWithPathComponent(comp);

      if (foundObj == null) {
        result.approximate = true;
        break;
      }

      currentObj = foundObj;
      currentContainer = foundObj as Container;
    }

    result.obj = currentObj;

    return result;
  }

  RuntimeObject ContentWithPathComponent(Path.Component component) {
    if (component.isIndex) {
      if (component.index >= 0 && component.index < content.length) {
        return content[component.index];
      } else {
        return null;
      }
    } else if (component.isParent) {
      return this.parent;
    } else {
      INamedContent foundContent;
      if (namedContent.containsKey(component.name)) {
        foundContent = namedContent[component.name];
        return foundContent as RuntimeObject;
      } else {
        return null;
      }
    }
  }

  void BuildStringOfHierarchy(StringBuffer sb, int indentation, RuntimeObject pointedObj) {
    void appendIndentation() {
      const int spacesPerIndent = 4;
      for (var i = 0; i < spacesPerIndent * indentation; ++i) {
        sb.write(" ");
      }
    }

    appendIndentation();
    sb.write("[");

    if (hasValidName) {
      sb.write(" ($name)");
    }

    if (this == pointedObj) {
      sb.write("  <---");
    }

    sb.writeln();

    indentation++;

    for (var i = 0; i < content.length; ++i) {
      var obj = content[i];

      if (obj is Container) {
        var container = obj as Container;
        container.BuildStringOfHierarchy(sb, indentation, pointedObj);
      } else {
        appendIndentation();
        if (obj is StringValue) {
          sb.write("\"${obj.toString().replaceAll("\n", "\\n")}\"");
        } else {
          sb.write(obj.toString());
        }
      }

      if (i != content.length - 1) {
        sb.write(",");
      }

      if (!(obj is Container) && obj == pointedObj) {
        sb.write("  <---");
      }

      sb.writeln();
    }

    var onlyNamed = HashMap<String, INamedContent>();

    namedContent.forEach((key, value) {
      if (content.contains(value as RuntimeObject)) {
        return;
      } else {
        onlyNamed[key] = value;
      }
    });

    if (onlyNamed.length > 0) {
      appendIndentation();
      sb.writeln("-- named: --");

      onlyNamed.forEach((key, value) {
        assert(value is Container, "Can only print out named Containers");
        var container = value as Container;
        container.BuildStringOfHierarchy(sb, indentation, pointedObj);
        sb.writeln();
      });
    }

    indentation--;

    appendIndentation();
    sb.write("]");
  }

  String BuildStringOfHierarchy() {
    var sb = StringBuffer();
    BuildStringOfHierarchy(sb, 0, null);
    return sb.toString();
  }
}
