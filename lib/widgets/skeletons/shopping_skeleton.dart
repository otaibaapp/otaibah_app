import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ShoppingSkeleton extends StatelessWidget {
  const ShoppingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 7),
            // 🔹 البانر
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Bone(width: double.infinity, height: 160),
              ),
            ),
            const SizedBox(height: 10),
            // 🔹 مربع البحث
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Bone(width: double.infinity, height: 46),
              ),
            ),
            const SizedBox(height: 10),
            // 🔹 تبويبات الفئات
            SizedBox(
              height: 45,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, __) => const Bone(width: 90, height: 36),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: 8,
              ),
            ),
            const SizedBox(height: 10),
            // 🔹 بطاقات المتاجر
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 2.8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (_, __) => Card(
                  elevation: 0,
                  color: const Color(0x20a7a9ac),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Skeletonizer.zone(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Bone.text(words: 4),
                          SizedBox(height: 8),
                          Bone.text(words: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
