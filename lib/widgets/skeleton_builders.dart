import 'package:flutter/material.dart';
import 'otaibah_skeleton.dart';

class SkeletonFutureBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final SkeletonType skeletonType;

  const SkeletonFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.skeletonType = SkeletonType.list,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (ctx, snap) {
        final isLoading = (snap.connectionState == ConnectionState.waiting);
        // لا تظهر أي أخطاء هنا؛ اتركها للـ child (اختياري)
        if (isLoading || !snap.hasData) {
          return OtaibahSkeleton(
            isLoading: true,
            type: skeletonType,
            child: const SizedBox.shrink(), // لن يُعرض
          );
        }
        return builder(ctx, snap.data as T);
      },
    );
  }
}

class SkeletonStreamBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext, T) builder;
  final SkeletonType skeletonType;

  const SkeletonStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.skeletonType = SkeletonType.list,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (ctx, snap) {
        final isLoading = (snap.connectionState == ConnectionState.waiting);
        if (isLoading || !snap.hasData) {
          return OtaibahSkeleton(
            isLoading: true,
            type: skeletonType,
            child: const SizedBox.shrink(),
          );
        }
        return builder(ctx, snap.data as T);
      },
    );
  }
}
