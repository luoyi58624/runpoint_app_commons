import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import 'app.dart';
import 'flavors.dart';

void main() async {
  F.appFlavor = Flavor.values.firstWhere(
        (element) => element.name == appFlavor,
  );

  // if (F.appFlavor == Flavor.sit) await 2.ss.delay();

  runApp(const App());
}
