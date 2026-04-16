enum Flavor {
  sit,
  prod,
}

class F {
  static late final Flavor appFlavor;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.sit:
        return 'MyShorebirdApp SIT';
      case Flavor.prod:
        return 'MyShorebirdApp';
    }
  }

}
