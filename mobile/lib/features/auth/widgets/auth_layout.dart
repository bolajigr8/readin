import 'package:flutter/material.dart';

/// RN pattern: SafeArea → KeyboardAvoiding → ScrollView(flexGrow:1) → content
/// vertically centred, scrolls when the keyboard is open.
class AuthScrollBody extends StatelessWidget {
  const AuthScrollBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 48, 24, 32),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: padding,
                child: Center(child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}
