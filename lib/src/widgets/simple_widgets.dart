import 'package:flutter/material.dart';
import 'package:runpoint_app_commons/runpoint_app_commons.dart';

class ListTileGroupWidget extends StatelessWidget {
  const ListTileGroupWidget({super.key, required this.children});

  final List<(String title, VoidCallback onTap)> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: children.length,
      shrinkWrap: true,
      itemBuilder: (context, index) => ListTile(
        onTap: (){
          children[index].$2();
        },
        title: Text(children[index].$1),
      ),
      separatorBuilder: (context, index) => ElDivider(),
    );
  }
}
