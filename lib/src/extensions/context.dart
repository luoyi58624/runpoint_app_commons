import 'package:el_flutter/el_flutter.dart';
import 'package:flutter/material.dart';

extension ContextExt on BuildContext {
  bool get isDark => ElBrightness.isDark(this);

  /// 重定向页面，先跳转新页面，再删除之前的页面
  Future<T?> push<T>(Widget page, {bool rootNavigator = false, RouteSettings? settings}) async {
    return await Navigator.of(
      this,
      rootNavigator: rootNavigator,
    ).push<T>(MaterialPageRoute(builder: (context) => page, settings: settings));
  }

  /// 退出页面
  void pop<T extends Object?>([T? result, bool rootNavigator = false]) async {
    return Navigator.of(this, rootNavigator: rootNavigator).pop<T>();
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  Future pushReplacement(Widget page, {bool rootNavigator = false, RouteSettings? settings}) async {
    return await Navigator.of(
      this,
      rootNavigator: rootNavigator,
    ).pushReplacement(MaterialPageRoute(builder: (context) => page, settings: settings));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  ///
  /// 例如：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  void pushAndRemoveUntil(Widget page, String routePath, {bool rootNavigator = false, RouteSettings? settings}) async {
    Navigator.of(this, rootNavigator: rootNavigator).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => page, settings: settings),
      ModalRoute.withName(routePath),
    );
  }

  /// 退出到指定位置
  void popUntil(String routePath, {bool rootNavigator = false}) async {
    Navigator.of(this, rootNavigator: rootNavigator).popUntil(ModalRoute.withName(routePath));
  }

  /// 进入新的页面并删除之前所有路由
  void pushAndRemoveAllUntil(Widget page, {bool rootNavigator = false, RouteSettings? settings}) async {
    Navigator.of(
      this,
      rootNavigator: rootNavigator,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => page, settings: settings), (route) => false);
  }
}
