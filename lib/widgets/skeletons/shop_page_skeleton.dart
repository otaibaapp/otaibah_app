import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ShopPageSkeleton extends StatelessWidget {
  const ShopPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: const Bone(width: double.infinity, height: 160),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Skeletonizer.zone(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Bone.text(words: 4),
                    SizedBox(height: 8),
                    Bone.text(words: 6),
                    SizedBox(height: 6),
                    Bone.text(words: 5),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Bone(width: double.infinity, height: 46),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 45,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, __) => const Bone(width: 90, height: 36),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: 6,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: .67,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 0,
                ),
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: Card(
                    elevation: 0,
                    color: const Color(0x20a7a9ac),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Skeletonizer.zone(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Expanded(child: Bone.square()),
                            SizedBox(height: 6),
                            Bone.text(words: 3),
                            SizedBox(height: 6),
                            Bone.text(words: 5),
                            SizedBox(height: 6),
                            Bone(width: 110, height: 28),
                          ],
                        ),
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
