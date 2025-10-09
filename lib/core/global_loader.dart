import 'package:flutter/material.dart';

/// وسيلة بسيطة للتحكم بحالة تحميل عامة (اختياري)
class GlobalLoader extends InheritedWidget {
  final ValueNotifier<bool> isLoading;

  const GlobalLoader({
    super.key,
    required this.isLoading,
    required super.child,
  });

  static GlobalLoader of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<GlobalLoader>();
    assert(w != null, 'GlobalLoader not found in the tree');
    return w!;
  }

  @override
  bool updateShouldNotify(covariant GlobalLoader oldWidget) {
    return oldWidget.isLoading != isLoading;
  }

  void show() => isLoading.value = true;
  void hide() => isLoading.value = false;
}
