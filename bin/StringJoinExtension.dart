class StringExt {
  static String join<T>(String separator, List<T> objects) {
    return objects.map((o) => o.toString()).join(separator);
  }
}
