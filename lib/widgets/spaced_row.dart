import 'package:flutter/material.dart';
import 'package:rattata_vision/extensions/iterable_extension.dart';

class SpacedRow extends StatelessWidget {
  final List<Widget> children;
  final bool expanded;
  final Widget? spacer;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;

  const SpacedRow({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.expanded = false,
    this.spacer,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children.map<Widget>(
        (Widget w) => expanded ? Expanded(child: w) : Flexible(child: w),
      ).separateWith(spacer),
    );
  }
}
