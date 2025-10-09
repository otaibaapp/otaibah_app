import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum SkeletonType { auto, list, grid, detail }

class OtaibahSkeleton extends StatelessWidget {
  final bool isLoading;
  final SkeletonType type;
  final Widget child;
  final Widget Function(BuildContext)? skeletonBuilder; // 👈 جديد


  const OtaibahSkeleton({
    super.key,
    required this.isLoading,
    required this.child,
    this.type = SkeletonType.auto,
    this.skeletonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // تفعيل أنيميشن انتقال بين السكيليتون والمحتوى (اختياري)
    return Skeletonizer(
      enabled: isLoading,
      effect: const ShimmerEffect(
        baseColor: Color(0xFFE0E0E0),      // رمادي متوسط
        highlightColor: Color(0xFFF5F5F5), // رمادي فاتح مثل فيسبوك/انستغرام
        duration: Duration(milliseconds: 120000),
      ),
      enableSwitchAnimation: true,
      child: isLoading ? _buildSkeleton(context) : child,
    );


  }

  SkeletonType _autoDetect() {
    if (child is GridView) return SkeletonType.grid;
    if (child is ListView) return SkeletonType.list;
    // مبدئيًا اعتبر الباقي تفاصيل
    return SkeletonType.detail;
  }

  Widget _buildSkeleton(BuildContext context) {
    // ✅ إذا في skeletonBuilder مخصص (مثل ShoppingSkeleton)
    if (skeletonBuilder != null) {
      return skeletonBuilder!(context);
    }

    // 👇 لو ما في builder مخصص، استخدم الأنواع الافتراضية
    final kind = (type == SkeletonType.auto) ? _autoDetect() : type;

    switch (kind) {
      case SkeletonType.list:
        return _listSkeleton();
      case SkeletonType.grid:
        return _gridSkeleton();
      case SkeletonType.detail:
      case SkeletonType.auto:
        return _detailSkeleton();
    }
  }


  /// شكل قائمة احترافي (أفاتار + عنوان + سطرين)
  Widget _listSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Card(
          elevation: 0.2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Skeletonizer.zone(
              child: Row(
                children: [
                  const Bone.circle(size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end, // RTL ودّي
                      children: const [
                        Bone.text(words: 3),
                        SizedBox(height: 8),
                        Bone.text(words: 5),
                        SizedBox(height: 6),
                        Bone.text(words: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Bone.icon(), // زر/أيقونة يمين
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// شكل شبكة (صورة مربعة + سطرين نص)
  Widget _gridSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .72,
      ),
      itemBuilder: (_, __) {
        return Card(
          elevation: 0.2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Skeletonizer.zone(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  // صورة المنتج
                  Expanded(child: Bone.square()),
                  SizedBox(height: 10),
                  Bone.text(words: 3),
                  SizedBox(height: 6),
                  Bone.text(words: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// شكل صفحة تفاصيل (صورة عريضة + عنوان + عدة أسطر + أزرار)
  Widget _detailSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Skeletonizer.zone(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Bone(width: double.infinity, height: 220), // صورة/بانر
            SizedBox(height: 16),
            Bone.text(words: 4), // عنوان
            SizedBox(height: 10),
            Bone.multiText(lines: 3),
            SizedBox(height: 10),
            Bone.multiText(lines: 2),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Bone.button(width: 140), // زر يسار
                Bone.button(width: 140), // زر يمين
              ],
            ),
          ],
        ),
      ),
    );
  }
}
