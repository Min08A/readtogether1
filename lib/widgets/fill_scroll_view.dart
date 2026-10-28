import 'package:flutter/material.dart';

/// Прокручиваемая колонка, которая занимает всю высоту экрана.
/// Позволяет прижать элементы к низу через Spacer() (как на макетах)
/// и при этом не ломается при открытой клавиатуре.
class FillScrollView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  const FillScrollView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
