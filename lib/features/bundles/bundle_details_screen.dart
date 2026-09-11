// features/bundles/bundle_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bundle_model.dart';
import '../../core/bundle_provider.dart';
import '../../core/items_provider.dart';
import '../../widgets/image_gallery_widget.dart';
import '../my_items/select_item_to_trade_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../core/item_model.dart';

// ==================== iOS DESIGN SYSTEM ====================

class _IOS {
static const Color lightBg = Color(0xFFF2F2F7);
static const Color darkBg = Color(0xFF000000);

static const Color lightCard = Color(0xFFFFFFFF);
static const Color darkCard = Color(0xFF1C1C1E);
static const Color darkCardElevated = Color(0xFF2C2C2E);

static const Color blue = Color(0xFF007AFF);
static const Color green = Color(0xFF34C759);
static const Color orange = Color(0xFFFF9500);
static const Color yellow = Color(0xFFFFCC00);
static const Color purple = Color(0xFFAF52DE);
static const Color teal = Color(0xFF5AC8FA);
static const Color indigo = Color(0xFF5856D6);
static const Color pink = Color(0xFFFF2D55);
static const Color red = Color(0xFFFF3B30);
static const Color gray = Color(0xFF8E8E93);

static Color separator(bool isDark) {
return isDark
? Colors.white.withOpacity(0.08)
    : Colors.black.withOpacity(0.06);
}

static Color card(bool isDark) {
return isDark ? darkCard : lightCard;
}

static Color bg(bool isDark) {
return isDark ? darkBg : lightBg;
}

static Color textPrimary(bool isDark) {
return isDark ? Colors.white : Colors.black;
}

static Color textSecondary(bool isDark) {
return isDark
? Colors.white.withOpacity(0.6)
    : const Color(0xFF3C3C43).withOpacity(0.6);
}

static Color textTertiary(bool isDark) {
return isDark
? Colors.white.withOpacity(0.3)
    : const Color(0xFF3C3C43).withOpacity(0.3);
}
}

class BundleDetailsScreen extends StatefulWidget {
final Bundle bundle;

const BundleDetailsScreen({
super.key,
required this.bundle,
});

@override
State<BundleDetailsScreen> createState() =>
_BundleDetailsScreenState();
}

class _BundleDetailsScreenState extends State<BundleDetailsScreen>
with SingleTickerProviderStateMixin {
Map<String, dynamic>? _ownerData;
bool _loadingOwner = true;
String? _currentUserId;

late AnimationController _fadeController;
late Animation<double> _fadeAnimation;

late AnimationController _slideController;
late Animation<Offset> _slideAnimation;

bool get _isDarkMode =>
Theme.of(context).brightness == Brightness.dark;

@override
void initState() {
super.initState();

_fadeController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 500),
);

_fadeAnimation = CurvedAnimation(
parent: _fadeController,
curve: Curves.easeOutCubic,
);

_slideController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 400),
);

_slideAnimation = Tween<Offset>(
begin: const Offset(0, 0.05),
end: Offset.zero,
).animate(
CurvedAnimation(
parent: _slideController,
curve: Curves.easeOutCubic,
),
);

_fadeController.forward();
_slideController.forward();

_loadOwnerData();
}

@override
void dispose() {
_fadeController.dispose();
_slideController.dispose();
super.dispose();
}

Future<void> _loadOwnerData() async {
final prefs = await SharedPreferences.getInstance();

_currentUserId = prefs.getString('user_id');

if (widget.bundle.userId == _currentUserId) {
if (mounted) {
setState(() {
_ownerData = {
'name': prefs.getString('user_name') ?? 'Вы',
'avatar_url': prefs.getString('avatar_url') ?? '',
};
_loadingOwner = false;
});
}

return;
}

try {
final provider = context.read<ItemsProvider>();

final ownerData = await provider.getUserProfile(
widget.bundle.userId,
);

if (mounted) {
setState(() {
_ownerData = ownerData;
_loadingOwner = false;
});
}
} catch (e) {
if (mounted) {
setState(() {
_loadingOwner = false;
});
}
}
}

@override
Widget build(BuildContext context) {
final bundle = widget.bundle;
final isMine = bundle.userId == _currentUserId;
final isDark = _isDarkMode;

return Scaffold(
backgroundColor: _IOS.bg(isDark),
body: CustomScrollView(
physics: const BouncingScrollPhysics(),
slivers: [
// ==========================================================
// HERO GALLERY
// ==========================================================

SliverAppBar(
expandedHeight: 340,
pinned: true,
stretch: true,
backgroundColor:
_IOS.bg(isDark).withOpacity(0.85),
surfaceTintColor: Colors.transparent,
elevation: 0,
scrolledUnderElevation: 0,
leadingWidth: 60,
leading: Padding(
padding: const EdgeInsets.only(
left: 16,
top: 10,
bottom: 10,
),
child: GestureDetector(
onTap: () {
HapticFeedback.selectionClick();
Navigator.pop(context);
},
child: Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.35),
shape: BoxShape.circle,
),
child: const Icon(
Icons.chevron_left_rounded,
color: Colors.white,
size: 22,
),
),
),
),
actions: [
if (isMine)
Padding(
padding: const EdgeInsets.only(
right: 16,
top: 10,
bottom: 10,
),
child: GestureDetector(
onTap: () {
HapticFeedback.selectionClick();
_showDeleteDialog();
},
child: Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color:
Colors.black.withOpacity(0.35),
shape: BoxShape.circle,
),
child: const Icon(
Icons.delete_outline_rounded,
color: _IOS.red,
size: 20,
),
),
),
),
],
flexibleSpace: FlexibleSpaceBar(
stretchModes: const [
StretchMode.zoomBackground,
],
background: Hero(
tag: 'bundle_${bundle.bundleId}',
child: Stack(
fit: StackFit.expand,
children: [
ImageGalleryWidget(
imageUrls: bundle.imagePaths,
height: 340,
borderRadius: 0,
showIndicators: true,
),

Positioned(
bottom: 0,
left: 0,
right: 0,
height: 100,
child: Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.bottomCenter,
end: Alignment.topCenter,
colors: [
_IOS.bg(isDark),
_IOS.bg(isDark)
    .withOpacity(0.6),
Colors.transparent,
],
stops: const [
0.0,
0.5,
1.0,
],
),
),
),
),

// НАБОР
Positioned(
top: 60,
left: 16,
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 12,
vertical: 6,
),
decoration: BoxDecoration(
color: _IOS.purple,
borderRadius:
BorderRadius.circular(10),
boxShadow: [
BoxShadow(
color: _IOS.purple
    .withOpacity(0.4),
blurRadius: 12,
offset:
const Offset(0, 4),
),
],
),
child: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.inventory_2_rounded,
color: Colors.white,
size: 14,
),
SizedBox(width: 6),
Text(
'НАБОР',
style: TextStyle(
color: Colors.white,
fontWeight:
FontWeight.w800,
fontSize: 11,
letterSpacing: 0.8,
),
),
],
),
),
),

// COUNT
Positioned(
top: 60,
right: 16,
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
vertical: 6,
),
decoration: BoxDecoration(
color:
Colors.black.withOpacity(0.55),
borderRadius:
BorderRadius.circular(10),
),
child: Text(
_itemsCountText(
bundle.items.length,
),
style: const TextStyle(
color: Colors.white,
fontSize: 11,
fontWeight:
FontWeight.w700,
height: 1,
),
),
),
),
],
),
),
),
),

// ==========================================================
// CONTENT
// ==========================================================

SliverToBoxAdapter(
child: FadeTransition(
opacity: _fadeAnimation,
child: SlideTransition(
position: _slideAnimation,
child: Padding(
padding: const EdgeInsets.fromLTRB(
16,
0,
16,
120,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
// TITLE + SV
Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
child: Text(
bundle.title,
style: TextStyle(
fontSize: 26,
fontWeight:
FontWeight.w800,
letterSpacing: -0.6,
color:
_IOS.textPrimary(
isDark,
),
height: 1.15,
),
),
),
const SizedBox(width: 10),
_buildSvBadge(
bundle.totalSv,
),
],
),

if (bundle.description
    .isNotEmpty) ...[
const SizedBox(height: 10),
Text(
bundle.description,
style: TextStyle(
fontSize: 15,
color:
_IOS.textSecondary(
isDark,
),
height: 1.45,
),
),
],

const SizedBox(height: 14),

// TAGS
Wrap(
spacing: 8,
runSpacing: 8,
children: [
...bundle.categories.map(
(cat) => _buildTag(
cat,
_IOS.blue,
),
),
if (bundle.condition
    .isNotEmpty)
_buildTag(
bundle.condition,
_IOS.green,
icon:
Icons.verified_rounded,
),
if (bundle.location
    .isNotEmpty)
_buildTag(
bundle.location,
_IOS.orange,
icon:
Icons.location_on_rounded,
),
],
),

const SizedBox(height: 20),

// OWNER
_buildOwnerCard(isMine),

const SizedBox(height: 24),

// SECTION
_buildSectionHeader(
title: 'Состав набора',
count: bundle.items.length,
isDark: isDark,
),

const SizedBox(height: 10),

...List.generate(
bundle.items.length,
(index) {
final item =
bundle.items[index];

return _buildItemInBundleCard(
item,
index,
);
},
),

const SizedBox(height: 24),

// SUMMARY
_buildSummaryCard(bundle),

const SizedBox(height: 24),

// TRADE
if (!isMine)
_buildTradeButton(bundle),
],
),
),
),
),
),
],
),
);
}

// ============================================================
// HELPERS
// ============================================================

String _itemsCountText(int count) {
if (count == 1) {
return '1 предмет';
}

if (count >= 2 && count <= 4) {
return '$count предмета';
}

return '$count предметов';
}

// ============================================================
// SV BADGE
// ============================================================

Widget _buildSvBadge(int sv) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 10,
),
decoration: BoxDecoration(
color: _IOS.orange.withOpacity(0.14),
borderRadius: BorderRadius.circular(14),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.auto_awesome_rounded,
color: _IOS.orange,
size: 18,
),
const SizedBox(width: 6),
Text(
'$sv',
style: const TextStyle(
color: _IOS.orange,
fontWeight: FontWeight.w900,
fontSize: 18,
letterSpacing: -0.5,
height: 1,
),
),
const SizedBox(width: 3),
const Text(
'SV',
style: TextStyle(
color: _IOS.orange,
fontWeight: FontWeight.w700,
fontSize: 12,
height: 1,
),
),
],
),
);
}

// ============================================================
// TAG
// ============================================================

Widget _buildTag(
String text,
Color color, {
IconData? icon,
}) {
if (text.trim().isEmpty) {
return const SizedBox.shrink();
}

return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 6,
),
decoration: BoxDecoration(
color: color.withOpacity(0.13),
borderRadius: BorderRadius.circular(10),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
if (icon != null) ...[
Icon(
icon,
size: 13,
color: color,
),
const SizedBox(width: 4),
],
Text(
text,
style: TextStyle(
color: color,
fontWeight: FontWeight.w700,
fontSize: 12,
letterSpacing: -0.1,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
],
),
);
}

// ============================================================
// OWNER CARD
// ============================================================

Widget _buildOwnerCard(bool isMine) {
final isDark = _isDarkMode;

if (_loadingOwner) {
return Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: _IOS.card(isDark),
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color: _IOS.separator(isDark),
),
),
child: const Center(
child: SizedBox(
width: 20,
height: 20,
child:
CircularProgressIndicator(
strokeWidth: 2,
color: _IOS.blue,
),
),
),
);
}

final name =
_ownerData?['name'] ??
(isMine ? 'Вы' : 'Пользователь');

final avatarUrl =
_ownerData?['avatar_url'] ?? '';

return Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: _IOS.card(isDark),
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color: _IOS.separator(isDark),
),
),
child: Row(
children: [
Container(
width: 52,
height: 52,
decoration: BoxDecoration(
color:
_IOS.blue.withOpacity(0.12),
shape: BoxShape.circle,
),
clipBehavior: Clip.antiAlias,
child: avatarUrl
    .toString()
    .isNotEmpty
? CachedNetworkImage(
imageUrl:
avatarUrl.toString(),
fit: BoxFit.cover,
placeholder:
(_, __) => Center(
child: Text(
(name
    .toString()
    .isNotEmpty
? name
    .toString()[0]
    : '?')
    .toUpperCase(),
style: const TextStyle(
color: _IOS.blue,
fontWeight:
FontWeight.w700,
fontSize: 20,
),
),
),
errorWidget:
(_, __, ___) =>
Center(
child: Text(
(name
    .toString()
    .isNotEmpty
? name
    .toString()[0]
    : '?')
    .toUpperCase(),
style: const TextStyle(
color: _IOS.blue,
fontWeight:
FontWeight.w700,
fontSize: 20,
),
),
),
)
    : Center(
child: Text(
(name
    .toString()
    .isNotEmpty
? name
    .toString()[0]
    : '?')
    .toUpperCase(),
style: const TextStyle(
color: _IOS.blue,
fontWeight:
FontWeight.w700,
fontSize: 20,
),
),
),
),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
isMine
? 'Это ваш набор'
    : 'Владелец',
style: TextStyle(
color:
_IOS.textTertiary(
isDark,
),
fontSize: 11,
fontWeight:
FontWeight.w600,
letterSpacing: 0.4,
),
),
const SizedBox(height: 3),
Text(
name.toString(),
style: TextStyle(
fontWeight:
FontWeight.w700,
fontSize: 16,
letterSpacing: -0.3,
color:
_IOS.textPrimary(
isDark,
),
),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
),
],
),
),

if (!isMine)
GestureDetector(
onTap: () {
HapticFeedback
    .selectionClick();

Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
PublicProfileScreen(
userId:
widget.bundle.userId,
),
),
);
},
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 14,
vertical: 8,
),
decoration: BoxDecoration(
color:
_IOS.blue.withOpacity(
0.14,
),
borderRadius:
BorderRadius.circular(
11,
),
),
child: const Row(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
Icons.person_rounded,
color: _IOS.blue,
size: 15,
),
SizedBox(width: 5),
Text(
'Профиль',
style: TextStyle(
color: _IOS.blue,
fontSize: 13,
fontWeight:
FontWeight.w700,
),
),
],
),
),
),
],
),
);
}

// ============================================================
// SECTION HEADER
// ============================================================

Widget _buildSectionHeader({
required String title,
required int count,
required bool isDark,
}) {
return Row(
children: [
Text(
title,
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
letterSpacing: -0.4,
color:
_IOS.textPrimary(isDark),
),
),
const SizedBox(width: 10),
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 3,
),
decoration: BoxDecoration(
color:
_IOS.purple.withOpacity(0.14),
borderRadius:
BorderRadius.circular(8),
),
child: Text(
'$count',
style: const TextStyle(
color: _IOS.purple,
fontWeight: FontWeight.w800,
fontSize: 12,
height: 1,
),
),
),
],
);
}

// ============================================================
// ITEM IN BUNDLE
// ============================================================

Widget _buildItemInBundleCard(
BundleItem item,
int index,
) {
final isDark = _isDarkMode;

return GestureDetector(
behavior: HitTestBehavior.opaque,
onTap: () {
HapticFeedback.selectionClick();
_showBundleItemSheet(item);
},
child: Container(
margin: const EdgeInsets.only(
bottom: 8,
),
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: _IOS.card(isDark),
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color: _IOS.separator(isDark),
),
),
child: Row(
children: [
// NUMBER
Container(
width: 32,
height: 32,
decoration: BoxDecoration(
color:
_IOS.purple.withOpacity(
0.14,
),
shape: BoxShape.circle,
),
alignment: Alignment.center,
child: Text(
'${index + 1}',
style: const TextStyle(
color: _IOS.purple,
fontWeight:
FontWeight.w800,
fontSize: 13,
height: 1,
),
),
),

const SizedBox(width: 12),

// ITEM IMAGE
_buildItemThumbnail(
item,
isDark,
),

const SizedBox(width: 10),

// TITLE + TAGS
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
item.title,
style: TextStyle(
fontWeight:
FontWeight.w700,
fontSize: 14,
letterSpacing: -0.2,
color:
_IOS.textPrimary(
isDark,
),
height: 1.25,
),
maxLines: 2,
overflow:
TextOverflow.ellipsis,
),

if (item.category
    .isNotEmpty ||
item.condition
    .isNotEmpty) ...[
const SizedBox(height: 5),
Row(
children: [
if (item
    .category
    .isNotEmpty)
Flexible(
child:
_buildMiniTag(
item.category,
_IOS.blue,
),
),
if (item
    .category
    .isNotEmpty &&
item
    .condition
    .isNotEmpty)
const SizedBox(
width: 5,
),
if (item
    .condition
    .isNotEmpty)
Flexible(
child:
_buildMiniTag(
item.condition,
_IOS.green,
),
),
],
),
],
],
),
),

const SizedBox(width: 8),

// SV + ARROW
Column(
mainAxisSize:
MainAxisSize.min,
crossAxisAlignment:
CrossAxisAlignment.end,
children: [
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal: 10,
vertical: 5,
),
decoration:
BoxDecoration(
color: _IOS.orange
    .withOpacity(
0.12,
),
borderRadius:
BorderRadius.circular(
9,
),
),
child: Text(
'${item.sv}',
style:
const TextStyle(
color: _IOS.orange,
fontWeight:
FontWeight.w800,
fontSize: 13,
height: 1,
),
),
),
const SizedBox(height: 4),
Icon(
Icons
    .chevron_right_rounded,
color:
_IOS.textTertiary(
isDark,
),
size: 18,
),
],
),
],
),
),
);
}

Widget _buildItemThumbnail(
BundleItem item,
bool isDark,
) {
final imageUrl =
item.imagePath.trim();

return Container(
width: 46,
height: 46,
decoration: BoxDecoration(
color: isDark
? _IOS.darkCardElevated
    : const Color(0xFFE5E5EA),
borderRadius:
BorderRadius.circular(12),
),
clipBehavior: Clip.antiAlias,
child: imageUrl.isNotEmpty
? CachedNetworkImage(
imageUrl: imageUrl,
fit: BoxFit.cover,
errorWidget:
(_, __, ___) =>
_buildThumbnailFallback(
isDark,
),
placeholder:
(_, __) =>
_buildThumbnailFallback(
isDark,
),
)
    : _buildThumbnailFallback(
isDark,
),
);
}

Widget _buildThumbnailFallback(
bool isDark,
) {
return Center(
child: Icon(
Icons.inventory_2_rounded,
color: _IOS.textTertiary(
isDark,
),
size: 20,
),
);
}

Widget _buildMiniTag(
String text,
Color color,
) {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal: 7,
vertical: 3,
),
decoration: BoxDecoration(
color: color.withOpacity(0.12),
borderRadius:
BorderRadius.circular(6),
),
child: Text(
text,
style: TextStyle(
color: color,
fontSize: 10,
fontWeight:
FontWeight.w700,
letterSpacing: -0.1,
height: 1,
),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
),
);
}

// ============================================================
// ITEM BOTTOM SHEET
// ============================================================

void _showBundleItemSheet(
BundleItem item,
) {
final isDark = _isDarkMode;

showModalBottomSheet<void>(
context: context,
backgroundColor:
Colors.transparent,
isScrollControlled: true,
useSafeArea: true,
enableDrag: true,
builder: (sheetContext) {
return DraggableScrollableSheet(
initialChildSize: 0.62,
minChildSize: 0.42,
maxChildSize: 0.92,
expand: false,
builder: (
context,
scrollController,
) {
return Container(
decoration:
BoxDecoration(
color: _IOS.bg(isDark),
borderRadius:
const BorderRadius
    .vertical(
top: Radius.circular(
28,
),
),
),
child: Column(
children: [
// DRAG HANDLE
Padding(
padding:
const EdgeInsets.only(
top: 10,
bottom: 5,
),
child: Container(
width: 38,
height: 4,
decoration:
BoxDecoration(
color:
_IOS.textTertiary(
isDark,
),
borderRadius:
BorderRadius
    .circular(
10,
),
),
),
),

// HEADER
Padding(
padding:
const EdgeInsets.fromLTRB(
18,
5,
12,
8,
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
'Предмет набора',
style:
TextStyle(
color:
_IOS.textTertiary(
isDark,
),
fontSize: 11,
fontWeight:
FontWeight
    .w600,
letterSpacing:
0.3,
),
),
const SizedBox(
height: 3,
),
Text(
item.title,
maxLines: 2,
overflow:
TextOverflow
    .ellipsis,
style:
TextStyle(
color:
_IOS.textPrimary(
isDark,
),
fontSize: 20,
fontWeight:
FontWeight
    .w800,
letterSpacing:
-0.45,
height: 1.1,
),
),
],
),
),
const SizedBox(
width: 10,
),
GestureDetector(
onTap: () =>
Navigator.pop(
sheetContext,
),
child:
Container(
width: 34,
height: 34,
decoration:
BoxDecoration(
color: isDark
? _IOS
    .darkCardElevated
    : Colors.white,
shape:
BoxShape
    .circle,
),
alignment:
Alignment
    .center,
child: Icon(
Icons
    .close_rounded,
color:
_IOS.textSecondary(
isDark,
),
size: 18,
),
),
),
],
),
),

Expanded(
child:
SingleChildScrollView(
controller:
scrollController,
physics:
const BouncingScrollPhysics(),
padding:
const EdgeInsets
    .fromLTRB(
16,
8,
16,
30,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
// IMAGE
_buildSheetImage(
item,
isDark,
),

const SizedBox(
height: 16,
),

// CHIPS
Wrap(
spacing: 8,
runSpacing: 8,
children: [
_buildSheetInfoChip(
icon: Icons
    .auto_awesome_rounded,
label:
'${item.sv} SV',
color:
_IOS.orange,
),

if (item
    .category
    .isNotEmpty)
_buildSheetInfoChip(
icon: Icons
    .category_rounded,
label:
item.category,
color:
_IOS.blue,
),

if (item
    .condition
    .isNotEmpty)
_buildSheetInfoChip(
icon: Icons
    .verified_rounded,
label:
item.condition,
color:
_IOS.green,
),
],
),

const SizedBox(
height: 18,
),

// INFO CARD
_buildSheetInfoCard(
isDark: isDark,
item: item,
),

const SizedBox(
height: 12,
),

// BUNDLE INFO
_buildSheetSectionCard(
isDark: isDark,
icon: Icons
    .inventory_2_rounded,
title:
'В составе набора',
child: Text(
'Этот предмет входит в набор «${widget.bundle.title}».',
style:
TextStyle(
color:
_IOS.textSecondary(
isDark,
),
fontSize: 14,
height: 1.4,
),
),
),
],
),
),
),
],
),
);
},
);
},
);
}

Widget _buildSheetImage(
BundleItem item,
bool isDark,
) {
final imageUrl =
item.imagePath.trim();

return Container(
width: double.infinity,
height: 250,
decoration: BoxDecoration(
color: isDark
? _IOS.darkCardElevated
    : const Color(0xFFE5E5EA),
borderRadius:
BorderRadius.circular(22),
border: Border.all(
color: _IOS.separator(isDark),
),
),
clipBehavior: Clip.antiAlias,
child: imageUrl.isNotEmpty
? CachedNetworkImage(
imageUrl: imageUrl,
fit: BoxFit.cover,
placeholder:
(_, __) =>
_buildSheetImageFallback(
isDark,
),
errorWidget:
(_, __, ___) =>
_buildSheetImageFallback(
isDark,
),
)
    : _buildSheetImageFallback(
isDark,
),
);
}

Widget _buildSheetImageFallback(
bool isDark,
) {
return Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin:
Alignment.topLeft,
end:
Alignment.bottomRight,
colors: [
_IOS.purple
    .withOpacity(0.24),
_IOS.blue
    .withOpacity(0.10),
],
),
),
child: Center(
child: Container(
width: 68,
height: 68,
decoration:
BoxDecoration(
color:
_IOS.textPrimary(
isDark,
).withOpacity(0.06),
shape: BoxShape.circle,
),
child: Icon(
Icons.inventory_2_rounded,
color:
_IOS.textSecondary(
isDark,
),
size: 30,
),
),
),
);
}

Widget _buildSheetInfoChip({
required IconData icon,
required String label,
required Color color,
}) {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
vertical: 7,
),
decoration: BoxDecoration(
color: color.withOpacity(0.12),
borderRadius:
BorderRadius.circular(11),
),
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
icon,
color: color,
size: 14,
),
const SizedBox(width: 5),
Text(
label,
style: TextStyle(
color: color,
fontWeight:
FontWeight.w700,
fontSize: 12,
),
),
],
),
);
}

Widget _buildSheetInfoCard({
required bool isDark,
required BundleItem item,
}) {
return Container(
width: double.infinity,
padding:
const EdgeInsets.all(15),
decoration: BoxDecoration(
color: _IOS.card(isDark),
borderRadius:
BorderRadius.circular(18),
border: Border.all(
color:
_IOS.separator(isDark),
),
),
child: Column(
children: [
_buildDetailRow(
icon: Icons.auto_awesome_rounded,
label: 'Стоимость',
value: '${item.sv} SV',
valueColor: _IOS.orange,
isDark: isDark,
),
if (item.category.isNotEmpty) ...[
_sheetDivider(isDark),
_buildDetailRow(
icon: Icons.category_rounded,
label: 'Категория',
value: item.category,
valueColor: _IOS.blue,
isDark: isDark,
),
],
if (item.condition.isNotEmpty) ...[
_sheetDivider(isDark),
_buildDetailRow(
icon:
Icons.verified_rounded,
label: 'Состояние',
value: item.condition,
valueColor: _IOS.green,
isDark: isDark,
),
],
],
),
);
}

Widget _buildDetailRow({
required IconData icon,
required String label,
required String value,
required Color valueColor,
required bool isDark,
}) {
return Row(
children: [
Container(
width: 30,
height: 30,
decoration:
BoxDecoration(
color: valueColor
    .withOpacity(0.12),
borderRadius:
BorderRadius.circular(9),
),
child: Icon(
icon,
color: valueColor,
size: 15,
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
label,
style: TextStyle(
color:
_IOS.textSecondary(
isDark,
),
fontSize: 13,
fontWeight:
FontWeight.w500,
),
),
),
const SizedBox(width: 10),
Flexible(
child: Text(
value,
textAlign:
TextAlign.right,
maxLines: 2,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: valueColor,
fontSize: 13,
fontWeight:
FontWeight.w700,
),
),
),
],
);
}

Widget _sheetDivider(bool isDark) {
return Padding(
padding:
const EdgeInsets.symmetric(
vertical: 11,
),
child: Container(
height: 0.5,
color:
_IOS.separator(isDark),
),
);
}

Widget _buildSheetSectionCard({
required bool isDark,
required IconData icon,
required String title,
required Widget child,
}) {
return Container(
width: double.infinity,
padding:
const EdgeInsets.all(15),
decoration: BoxDecoration(
color: _IOS.card(isDark),
borderRadius:
BorderRadius.circular(18),
border: Border.all(
color:
_IOS.separator(isDark),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 30,
height: 30,
decoration:
BoxDecoration(
color: _IOS.purple
    .withOpacity(0.12),
borderRadius:
BorderRadius.circular(
9,
),
),
child: Icon(
icon,
color: _IOS.purple,
size: 15,
),
),
const SizedBox(width: 9),
Text(
title,
style: TextStyle(
color:
_IOS.textPrimary(
isDark,
),
fontSize: 13,
fontWeight:
FontWeight.w800,
letterSpacing: -0.2,
),
),
],
),
const SizedBox(height: 11),
child,
],
),
);
}

// ============================================================
// SUMMARY CARD
// ============================================================

Widget _buildSummaryCard(
Bundle bundle,
) {
final isDark = _isDarkMode;

final averageSv = bundle.items.isEmpty
? 0
    : (bundle.totalSv /
bundle.items.length)
    .round();

return Container(
padding:
const EdgeInsets.all(16),
decoration:
BoxDecoration(
color: _IOS.card(isDark),
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color:
_IOS.separator(isDark),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 32,
height: 32,
decoration:
BoxDecoration(
color: _IOS.purple
    .withOpacity(0.14),
borderRadius:
BorderRadius.circular(
10,
),
),
child: const Icon(
Icons.summarize_rounded,
color: _IOS.purple,
size: 17,
),
),
const SizedBox(width: 10),
Text(
'Сводка набора',
style: TextStyle(
color:
_IOS.textPrimary(
isDark,
),
fontWeight:
FontWeight.w800,
fontSize: 15,
letterSpacing: -0.3,
),
),
],
),

const SizedBox(height: 14),

_buildSummaryRow(
label: 'Предметов',
value:
'${bundle.items.length}',
isDark: isDark,
),

_rowDivider(isDark),

_buildSummaryRow(
label: 'Общая стоимость',
value:
'${bundle.totalSv} SV',
valueColor: _IOS.orange,
isDark: isDark,
),

_rowDivider(isDark),

_buildSummaryRow(
label: 'Средняя',
value: '$averageSv SV',
valueColor: _IOS.yellow,
isDark: isDark,
),

if (bundle.categories
    .isNotEmpty) ...[
_rowDivider(isDark),
_buildSummaryRow(
label: 'Категории',
value: bundle.categories
    .join(', '),
valueColor: _IOS.blue,
isDark: isDark,
),
],
],
),
);
}

Widget _rowDivider(bool isDark) {
return Padding(
padding:
const EdgeInsets.symmetric(
vertical: 10,
),
child: Container(
height: 0.5,
color:
_IOS.separator(isDark),
),
);
}

Widget _buildSummaryRow({
required String label,
required String value,
required bool isDark,
Color? valueColor,
}) {
return Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
flex: 3,
child: Text(
label,
style: TextStyle(
color:
_IOS.textSecondary(
isDark,
),
fontSize: 14,
fontWeight:
FontWeight.w500,
letterSpacing: -0.1,
),
),
),
const SizedBox(width: 12),
Expanded(
flex: 5,
child: Text(
value,
style: TextStyle(
color: valueColor ??
_IOS.textPrimary(
isDark,
),
fontWeight:
FontWeight.w700,
fontSize: 14,
letterSpacing: -0.2,
),
textAlign:
TextAlign.right,
maxLines: 2,
overflow:
TextOverflow.ellipsis,
),
),
],
);
}

// ============================================================
// TRADE BUTTON
// ============================================================

Widget _buildTradeButton(
Bundle bundle,
) {
return SizedBox(
width: double.infinity,
height: 52,
child: ElevatedButton(
onPressed: () {
HapticFeedback
    .mediumImpact();

final tempItem = Item(
itemId: bundle.bundleId,
ownerId: bundle.userId,
title:
'📦 ${bundle.title}',
description:
bundle.description,
sv: bundle.totalSv,
imagePath:
bundle.imagePaths
    .isNotEmpty
? bundle
    .imagePaths
    .first
    : '',
imagePaths:
bundle.imagePaths,
location:
bundle.location,
category:
bundle.primaryCategory,
condition:
bundle.condition,
isMine: false,
status: 'available',
);

Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
SelectItemToTradeScreen(
wantedItem: tempItem,
wantedBundle: bundle,
),
),
);
},
style:
ElevatedButton.styleFrom(
backgroundColor: _IOS.blue,
foregroundColor:
Colors.white,
elevation: 0,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
14,
),
),
),
child: const Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Icon(
Icons.swap_horiz_rounded,
color: Colors.white,
size: 20,
),
SizedBox(width: 8),
Text(
'Предложить обмен',
style: TextStyle(
color: Colors.white,
fontSize: 16,
fontWeight:
FontWeight.w700,
letterSpacing: -0.2,
),
),
],
),
),
);
}

// ============================================================
// DELETE DIALOG
// ============================================================

void _showDeleteDialog() {
final isDark = _isDarkMode;

showDialog(
context: context,
builder: (ctx) => Dialog(
backgroundColor:
Colors.transparent,
insetPadding:
const EdgeInsets.symmetric(
horizontal: 60,
),
child: Container(
decoration:
BoxDecoration(
color: isDark
? _IOS.darkCardElevated
    : Colors.white,
borderRadius:
BorderRadius.circular(14),
),
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Padding(
padding:
const EdgeInsets.fromLTRB(
20,
20,
20,
16,
),
child: Column(
children: [
Text(
'Удалить набор?',
textAlign:
TextAlign.center,
style: TextStyle(
fontSize: 17,
fontWeight:
FontWeight.w700,
color:
_IOS.textPrimary(
isDark,
),
),
),
const SizedBox(
height: 6,
),
Text(
'Это действие нельзя отменить. Все предметы останутся у вас, но сам набор будет удалён.',
textAlign:
TextAlign.center,
style: TextStyle(
fontSize: 13,
color:
_IOS.textSecondary(
isDark,
),
height: 1.4,
),
),
],
),
),

Divider(
height: 0.5,
color:
_IOS.separator(
isDark,
),
),

Row(
children: [
Expanded(
child:
GestureDetector(
onTap: () =>
Navigator.pop(
ctx,
),
child: Container(
padding:
const EdgeInsets
    .symmetric(
vertical: 14,
),
alignment:
Alignment
    .center,
child:
const Text(
'Отмена',
style:
TextStyle(
fontSize: 17,
fontWeight:
FontWeight
    .w400,
color:
_IOS.blue,
),
),
),
),
),

Container(
width: 0.5,
height: 50,
color:
_IOS.separator(
isDark,
),
),

Expanded(
child:
GestureDetector(
onTap: () {
HapticFeedback
    .mediumImpact();

Navigator.pop(
ctx,
);

context
    .read<
BundleProvider>()
    .deleteBundle(
widget
    .bundle
    .bundleId,
);

Navigator.pop(
context,
);

ScaffoldMessenger
    .of(context)
    .showSnackBar(
SnackBar(
content:
const Text(
'Набор удалён',
),
backgroundColor:
_IOS.red,
behavior:
SnackBarBehavior
    .floating,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius
    .circular(
14,
),
),
),
);
},
child: Container(
padding:
const EdgeInsets
    .symmetric(
vertical: 14,
),
alignment:
Alignment
    .center,
child:
const Text(
'Удалить',
style:
TextStyle(
fontSize: 17,
fontWeight:
FontWeight
    .w600,
color:
_IOS.red,
),
),
),
),
),
],
),
],
),
),
),
);
}
}
