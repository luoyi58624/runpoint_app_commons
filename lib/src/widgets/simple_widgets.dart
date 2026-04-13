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
        onTap: () {
          children[index].$2();
        },
        title: Text(children[index].$1),
      ),
      separatorBuilder: (context, index) => ElDivider(),
    );
  }
}

class ListViewDemoWidget extends StatelessWidget {
  const ListViewDemoWidget(this.itemCount, {super.key, this.physics, this.controller, this.onTap});

  final int itemCount;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ElScroll(
      controller: controller,
      physics: physics,
      children: [
        ...List.generate(
          itemCount,
          (index) => Material(
            type: MaterialType.transparency,
            child: ListTile(onTap: onTap, title: Text('列表 - ${index + 1}')),
          ),
        ),
      ],
    );
  }
}
