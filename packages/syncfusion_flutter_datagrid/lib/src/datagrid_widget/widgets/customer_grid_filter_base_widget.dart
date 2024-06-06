import 'package:flutter/material.dart';

class CustomGridFilterBaseWidget extends StatefulWidget {
  const CustomGridFilterBaseWidget({
    super.key,
    required this.doFilterRecords,
    required this.doClearFilter,
  });

  final VoidCallback doFilterRecords;
  final VoidCallback doClearFilter;

  @override
  State<CustomGridFilterBaseWidget> createState() =>
      _CustomGridFilterBaseWidgetState();
}

class _CustomGridFilterBaseWidgetState
    extends State<CustomGridFilterBaseWidget> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
