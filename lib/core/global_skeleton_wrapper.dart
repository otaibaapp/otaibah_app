import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../widgets/otaibah_skeleton.dart';

typedef SkeletonContentBuilder = Widget Function(BuildContext context);

class GlobalSkeletonWrapper extends StatefulWidget {
  final Future<void> Function()? loadFuture;
  final SkeletonContentBuilder skeletonBuilder;
  final Widget child;
  final Duration timeout;

  const GlobalSkeletonWrapper({
    super.key,
    required this.child,
    required this.skeletonBuilder,
    this.loadFuture,
    this.timeout = const Duration(seconds: 5),
  });

  @override
  State<GlobalSkeletonWrapper> createState() => _GlobalSkeletonWrapperState();
}

class _GlobalSkeletonWrapperState extends State<GlobalSkeletonWrapper> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLoading();
  }

  Future<void> _initLoading() async {
    try {
      if (widget.loadFuture != null) {
        await Future.any([
          widget.loadFuture!(),
          Future.delayed(widget.timeout),
        ]);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return OtaibahSkeleton(
      isLoading: _loading,
      skeletonBuilder: (context) => widget.skeletonBuilder(context),
      child: widget.child,
    );
  }
}
