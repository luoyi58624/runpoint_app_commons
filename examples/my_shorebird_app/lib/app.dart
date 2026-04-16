import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

import 'flavors.dart';
import 'src/pages/my_home_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
    location: BannerLocation.topStart,
    message: F.name,
    color: Colors.green.withAlpha(150),
    textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.0, letterSpacing: 1.0),
    textDirection: TextDirection.ltr,
    child: child,
  )
      : Container(child: child);

  @override
  void initState() {
    super.initState();
    nextTick(() {
      AppUpdateUtil.shorebirdUpdate(el.context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: F.title,
      navigatorKey: el.navigatorKey,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _flavorBanner(child: MyHomePage(), show: kDebugMode),
    );
  }
}
