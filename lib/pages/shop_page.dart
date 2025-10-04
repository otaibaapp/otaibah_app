import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'cart_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ShopPage extends StatefulWidget {
  final Map shopData;
  const ShopPage({super.key, required this.shopData});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  List<Map<String, dynamic>> products = [];
  Map<String, dynamic> categories = {};
  List<String> _categoryKeys = []; // 👈 أسماء التصنيفات
  String? _selectedCategory;

  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  final user = FirebaseAuth.instance.currentUser;

  DatabaseReference get _cartRef =>
      FirebaseDatabase.instance.ref("carts/${user?.uid}/${widget.shopData['id']}");

  // 🔥 Stream يرجع العدد الكلي للمنتجات في السلة
  Stream<int> get totalCartItems {
    return _cartRef.onValue.map((event) {
      if (!event.snapshot.exists) return 0;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      int total = 0;
      for (var p in data.values) {
        final product = Map<String, dynamic>.from(p);
        total += (product['quantity'] ?? 0) as int;
      }
      return total;
    });
  }

  // يحوّل أي قيمة رقمية (int/double/string) إلى num
  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

// 🔥 Stream يرجع المبلغ الإجمالي للسلة (سعر * كمية)
  // 🔥 Stream يرجّع المبلغ الإجمالي للسلة (السعر الفعّال * الكمية)
  Stream<int> get totalCartAmount {
    return _cartRef.onValue.map((event) {
      if (!event.snapshot.exists) return 0;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // فهرس سريع لآخر خصومات المنتجات المحمّلة في الصفحة (للـ fallback)
      final Map<String, num> liveDiscountIndex = {
        for (final p in products)
          (p['id']?.toString() ?? ''): _toNum(p['discountPrice'])
      };

      int total = 0;
      for (final p in data.values) {
        final m = Map<String, dynamic>.from(p as Map);
        final int qty = _toNum(m['quantity']).toInt();

        final num orig = _toNum(m['price']);
        num disc = _toNum(m['discountPrice']); // قد تكون غير موجودة أو 0

        // لو ما في discountPrice داخل السلة (عناصر قديمة) جرّب آخر خصم حيّ من المنتجات
        if (disc <= 0) {
          final pid = (m['id'] ?? '').toString();
          disc = _toNum(liveDiscountIndex[pid]);
        }

        final num effective = (disc > 0 && disc < orig) ? disc : orig;
        total += (effective.toInt()) * qty;
      }
      return total;
    });
  }




  @override
  void initState() {
    super.initState();
    _loadShop();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShop() async {
    final shopRef = FirebaseDatabase.instance.ref(
      "otaibah_navigators_taps/shopping/categories/${widget.shopData['category']}/${widget.shopData['id']}",
    );
    final snap = await shopRef.get();
    if (!mounted) return;

    if (snap.exists) {
      final data = Map<dynamic, dynamic>.from(snap.value as Map);

      // --- المنتجات ---
      final prods = Map<String, dynamic>.from(data['products'] ?? {});
      final sortedProducts = prods.entries.map((e) {
        final p = Map<String, dynamic>.from(e.value);
        p['id'] = e.key; // ضروري نخزن id
        return p;
      }).toList()
        ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

      // --- الفئات ---
      final cats = Map<String, dynamic>.from(data['categories'] ?? {});
      final catList = cats.entries.map((e) {
        final val = (e.value is Map) ? Map<String, dynamic>.from(e.value) : {};
        return {
          "id": e.key.toString(),
          "order": val["order"] ?? 0,
        };
      }).toList()
        ..sort((a, b) => (a["order"] ?? 0).compareTo(b["order"] ?? 0));

      // --- تحديث الحالة ---
      setState(() {
        products = sortedProducts; // ✅ صار معرف
        categories = cats;
        _categoryKeys = catList.map((c) => c["id"].toString()).toList(); // ✅ مرتبة
        _selectedCategory = "مُختارة لك 🔥";
      });
    } else {
      setState(() {
        products = [];
        categories = {};
        _categoryKeys = [];
        _selectedCategory = "مُختارة لك 🔥";
      });
    }
  }

  // ---------- سلة ----------
  Stream<int> getCartQuantity(String productId) {
    return _cartRef.child(productId).child("quantity").onValue.map((event) {
      if (event.snapshot.value == null) return 0;
      return (event.snapshot.value as num).toInt();
    });
  }

  Future<void> addToCart(Map product) async {
    final productId = product['id'];
    final ref = _cartRef.child(productId);

    // نحاول قراءة الأسعار كسِكَرات/أرقام ونحوّلها إلى أرقام
    final int originalPrice = _toNum(product['price']).toInt();
    final int? discountMaybe = (() {
      final d = _toNum(product['discountPrice']);
      if (d > 0 && d < originalPrice) return d.toInt();
      return null;
    })();

    final snap = await ref.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final qty = (_toNum(data['quantity']).toInt()) + 1;

      // نحدّث الكمية + نضمن حفظ الأسعار الحالية (حتى لو تغيّر الخصم)
      final updatePayload = <String, dynamic>{
        "quantity": qty,
        "price": originalPrice,
      };
      if (discountMaybe != null) {
        updatePayload["discountPrice"] = discountMaybe;
      }
      await ref.update(updatePayload);
    } else {
      final setPayload = <String, dynamic>{
        "id": productId,
        "name": product['name'],
        "imageUrl": product['imageUrl'],
        "quantity": 1,
        "price": originalPrice,
      };
      if (discountMaybe != null) {
        setPayload["discountPrice"] = discountMaybe;
      }
      await ref.set(setPayload);
    }
  }


  Future<void> removeFromCart(Map product) async {
    final productId = product['id'];
    final ref = _cartRef.child(productId);
    final snap = await ref.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final qty = (data['quantity'] ?? 0) - 1;
      if (qty > 0) {
        await ref.update({"quantity": qty});
      } else {
        await ref.remove();
      }
    }
  }

  // ---------- فلترة ----------
  List<Map<String, dynamic>> _allProductsList() {
    final list = products;
    if (_query.isEmpty) return list;
    return list.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      return name.contains(_query) || desc.contains(_query);
    }).toList();
  }

  List<Map<String, dynamic>> _categoryProducts(String cat) {
    return _allProductsList()
        .where((p) => (p['category'] ?? '').toString() == cat)
        .toList();
  }

  // ---------- واجهة ----------
  @override
  Widget build(BuildContext context) {
    // منتجات حسب التبويب الحالي (ما عدا "مختارة لك" لأنه Sections)
    final visibleProducts = (_selectedCategory != "مُختارة لك 🔥")
        ? _categoryProducts(_selectedCategory ?? "")
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFf6f6f6),
        elevation: 0.0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        automaticallyImplyLeading: false, // 👈 عشان نتحكم بالـ leading يدوي
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end, // 👈 كله لليمين
          children: [
            Flexible(
              child: Text(
                widget.shopData['name'] ?? "المتجر",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(width: 8), // مسافة بسيطة بين الاسم والايقونة
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: SvgPicture.asset(
                "assets/svg/back.svg",
                width: 22,
                height: 22,
                color: Colors.black,
              ),
            ),
          ],
        ),
        ),


        body: SafeArea(
        child: Stack(
          children: [
            // ===== المحتوى =====
            Directionality(
              textDirection: TextDirection.rtl,
              child: CustomScrollView(
                slivers: [
                  // ===== بطاقة المتجر =====
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x20a7a9ac),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🖼️ صورة المتجر مع شارات (خصم / جديد)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 2.35,
                                    child: Image.network(
                                      widget.shopData['imageUrl'] ?? "",
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Icon(Icons.store, size: 60, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 🔹 شارة "خصم"
                                  if ((widget.shopData['discountText']?.toString().isNotEmpty ?? false))
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      child: Image.asset(
                                        'assets/images/discount_icon_above.png',
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.contain,
                                      ),
                                    ),

                                  // 🔸 شارة "جديد"
                                  if (widget.shopData['createdAt'] != null)
                                    Builder(builder: (context) {
                                      final createdAt = DateTime.tryParse(widget.shopData['createdAt']);
                                      final now = DateTime.now();
                                      final isNew = createdAt != null && now.difference(createdAt).inDays <= 30;
                                      if (!isNew) return const SizedBox.shrink();
                                      return Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Image.asset(
                                          'assets/images/new_icon.png',
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.contain,
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ),

                          // ✅ تفاصيل المتجر
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // العمود الأيمن: الاسم + الوصف + الخصم
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // الاسم + التوثيق
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                widget.shopData['name']?.toString() ?? '',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (widget.shopData['verified'] == true) ...[
                                              const SizedBox(width: 2),
                                              SvgPicture.asset(
                                                'assets/svg/verified.svg',
                                                width: 13,
                                                height: 13,
                                              ),
                                            ],
                                          ],
                                        ),

                                        const SizedBox(height: 4),

                                        // الوصف
                                        Text(
                                          widget.shopData['description']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black,
                                          ),
                                        ),

                                        const SizedBox(height: 6),

                                        // الخصم
                                        if ((widget.shopData['discountText']?.toString().isNotEmpty ?? false)) ...[
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.only(
                                                  right: 30,
                                                  left: 10,
                                                  top: 5,
                                                  bottom: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6b1f2a),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  widget.shopData['discountText'],
                                                  style: const TextStyle(
                                                    color: Color(0xFFedebe0),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Positioned(
                                                right: 3,
                                                top: 0,
                                                child: Image.asset(
                                                  'assets/images/discount_icon.png',
                                                  width: 25,
                                                  height: 25,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // العمود الأيسر (التوصيل + أوقات العمل)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.shopData['deliveryTime'] != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'خلال ${widget.shopData['deliveryTime']} دقيقة',
                                              style: const TextStyle(fontSize: 12, color: Colors.black),
                                            ),
                                            const SizedBox(width: 6),
                                            Image.asset('assets/images/time_delivery.png', width: 15, height: 15),
                                          ],
                                        ),
                                      const SizedBox(height: 6),

                                      if (widget.shopData['deliveryMethod'] != null)
                                        Row(
                                          children: [
                                            Text(
                                              'عبر ${widget.shopData['deliveryMethod']}',
                                              style: const TextStyle(fontSize: 12, color: Colors.black),
                                            ),
                                            const SizedBox(width: 6),
                                            Image.asset('assets/images/delivery_method.png', width: 15, height: 15),
                                          ],
                                        ),
                                      const SizedBox(height: 6),

                                      if ((widget.shopData['openTime']?.toString().isNotEmpty ?? false) &&
                                          (widget.shopData['closeTime']?.toString().isNotEmpty ?? false))
                                        Row(
                                          children: [
                                            Text(
                                              'من ${widget.shopData['openTime']} إلى ${widget.shopData['closeTime']}',
                                              style: const TextStyle(fontSize: 12, color: Colors.black),
                                            ),
                                            const SizedBox(width: 6),
                                            Image.asset('assets/images/clock.png', width: 15, height: 15),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 0)),

                  // 🔎 مربع البحث
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.black, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0x20a7a9ac),
                          hintText: "ابحث عن منتجك المٌفضَّل...",
                          hintStyle: const TextStyle(
                            color: Color(0x70000000),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: SvgPicture.asset(
                              'assets/svg/search.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                Color(0x70000000),
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                      ),
                    ),
                  ),

                  // ===== الفئات =====
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 45,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        children: [
                          // ✅ فئة "مختارة لك"
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Card(
                              color: const Color(0x20a7a9ac),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF000000),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: () {
                                  setState(() => _selectedCategory = "مُختارة لك 🔥");
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "مُختارة لك 🔥",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _selectedCategory == "مُختارة لك 🔥"
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    if (_selectedCategory == "مُختارة لك 🔥") ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.check, size: 18, color: Colors.black),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ✅ باقي الفئات
                          ..._categoryKeys.map((catName) {
                            final bool isSelected = _selectedCategory == catName;
                            return Padding(
                              padding: EdgeInsets.zero,
                              child: Card(
                                color: const Color(0x20a7a9ac),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF000000),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  onPressed: () {
                                    setState(() => _selectedCategory = catName);
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        catName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.check, size: 18, color: Colors.black),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // ===== المحتوى =====
                  if (_selectedCategory == "مُختارة لك 🔥") ...[
                    _buildRecommendedProducts(),
                  ] else ...[
                    _buildProductsGridSliver(visibleProducts),
                  ],
                ],
              ),
            ),

            // ===== زر السلة الثابت =====
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartPage(
                          shopId: widget.shopData['id'],
                          shopName: widget.shopData['name'] ?? '',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFF988561),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // ===== السعر + العملة (يسار) =====
                        Expanded(
                          child: StreamBuilder<int>(
                            stream: totalCartAmount,
                            builder: (context, snapshot) {
                              final amount = snapshot.data ?? 0;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    "ل.س",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    "$amount",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // ===== النص + العدد (يمين) =====
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                "الإطّلاع على السلّة",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7A694F),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: StreamBuilder<int>(
                                  stream: totalCartItems,
                                  builder: (context, snapshot) {
                                    final count = snapshot.data ?? 0;
                                    return Center(
                                      child: Text(
                                        "$count",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // ===== أقسام "مختارة لك" =====
  SliverPadding _buildRecommendedProducts() {
    final all = _allProductsList();

    if (all.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: const SliverToBoxAdapter(
          child: Text("لا توجد منتجات للعرض حالياً"),
        ),
      );
    }

    final recommended = all.take(20).toList();

    return _buildProductsGridSliver(recommended);
  }

  // ===== Grid Builder =====
  SliverPadding _buildProductsGridSliver(List<Map<String, dynamic>> items) {
    return SliverPadding(
      padding: const EdgeInsets.only(
        left: 6,
        right: 6,
        top: 0,
        bottom: 110, // 👈 مسافة أسفل آخر منتج
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final product = items[index];
            return _ProductCard(
              product: product,
              getQtyStream: getCartQuantity,
              onAdd: addToCart,
              onRemove: removeFromCart,
            );
          },
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.67,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
        ),
      ),
    );
  }
}

// ===== بطاقة المنتج =====
class _ProductCard extends StatelessWidget {
  final Map product;
  final Stream<int> Function(String productId) getQtyStream;
  final Future<void> Function(Map product) onAdd;
  final Future<void> Function(Map product) onRemove;

  const _ProductCard({
    required this.product,
    required this.getQtyStream,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final String name = product['name']?.toString() ?? '';
    final String desc = product['description']?.toString() ?? '';
    final String imageUrl = product['imageUrl']?.toString() ?? '';
    final String priceStr = product['price']?.toString() ?? '0'; // 👈 السعر الأصلي
    final String? discountPriceStr = product['discountPrice']?.toString(); // 👈 السعر الجديد بعد الخصم

    return Card(
      color: const Color(0x20a7a9ac),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  // صورة المنتج
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),

                  // أيقونة الخصم (يسار)
                  if (product['saving'] == true)
                    Positioned(
                      top: 0,
                      left: 8,
                      child: Image.asset(
                        'assets/images/discount_icon_above.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),

                  // ✅ السعر القديم أعلى يمين داخل مستطيل ذهبي
                  if (discountPriceStr != null && discountPriceStr.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF988561), // ذهبي
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(7),
                            bottomLeft: Radius.circular(7),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Stack(
                          alignment: Alignment.center, // 👈 خلي الخط بالنص
                          children: [
                            Text(
                              "$priceStr ل.س", // 👈 السعر الأصلي
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // خط مائل فوق النص
                            Transform.rotate(
                              angle: -0.1, // 👈 الميل (بالراديان) -0.2 ≈ -11 درجات
                              child: Container(
                                width: 50,   // 👈 عرض الخط (كبّر/صغّر حسب طول النص)
                                height: 1.5,  // 👈 سماكة الخط
                                color: Colors.redAccent, // 👈 لون الخط
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                ],
              ),
            ),

            const SizedBox(height: 6),

            // اسم
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // وصف
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ===== السعر + العداد =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (discountPriceStr != null && discountPriceStr.isNotEmpty) ...[
                  // السعر الجديد بعد الخصم
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6b1f2a),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: discountPriceStr, // 👈 السعر الجديد (2000)
                            style: const TextStyle(
                              color: Color(0xfffffcee),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const TextSpan(
                            text: " ل.س",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                  // لا يوجد خصم → عرض السعر العادي
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF988561),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: priceStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const TextSpan(
                            text: " ل.س",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ===== العداد =====
                StreamBuilder<int>(
                  stream: getQtyStream(product['id']),
                  builder: (context, snapshot) {
                    final qty = snapshot.data ?? 0;
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0x20988561),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => onAdd(product),
                            child: Image.asset(
                              "assets/images/plus.png",
                              width: 22,
                              height: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$qty",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF988561),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: qty > 0 ? () => onRemove(product) : null,
                            child: Image.asset(
                              "assets/images/minus.png",
                              width: 22,
                              height: 22,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// رسم شارة أعلى يمين مع زاوية مدوّرة (بديل الشريط المائل)
class _TopRightRibbonPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  _TopRightRibbonPainter({required this.color, this.borderRadius = 6});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final double w = size.width;
    final double h = size.height;
    final double r = borderRadius.clamp(0.0, 20.0);

    final path = Path();
    // بداية من أعلى قريب من الزاوية اليمنى لعمل تدوير
    path.moveTo(w - r, 0);
    // تدوير الزاوية العليا اليمنى
    path.quadraticBezierTo(w, 0, w, r);
    // نزول لأسفل يمين
    path.lineTo(w - (h * 0), w * 0.6);

// 👈 بدل w - h بخليها w - (h * 2) عشان يكبر عرض المثلث
    path.lineTo(w - (h * 2.7), 0);

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopRightRibbonPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
  }
}
