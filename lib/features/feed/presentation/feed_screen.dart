import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../item_details/item_details_screen.dart';
import '../../../core/item_model.dart';
import '../../../core/items_provider.dart';

class FeedScreen extends StatefulWidget {
const FeedScreen({super.key});

@override
State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
@override
void initState() {
super.initState();

Future.delayed(
const Duration(milliseconds: 100),
() {
if (!mounted) return;
context.read<ItemsProvider>().loadItems();
},
);
}

bool get _isDarkMode =>
Theme.of(context).brightness == Brightness.dark;

Color get _backgroundColor =>
_isDarkMode
? const Color(0xFF000000)
    : const Color(0xFFF2F2F7);

Color get _surfaceColor =>
_isDarkMode
? const Color(0xFF1C1C1E)
    : Colors.white;

Color get _secondarySurfaceColor =>
_isDarkMode
? const Color(0xFF2C2C2E)
    : const Color(0xFFF8F8FA);

Color get _textColor =>
_isDarkMode
? Colors.white
    : const Color(0xFF111111);

Color get _secondaryTextColor =>
_isDarkMode
? const Color(0xFF98989F)
    : const Color(0xFF6F6F76);

Color get _tertiaryTextColor =>
_isDarkMode
? const Color(0xFF636366)
    : const Color(0xFF8E8E93);

Color get _borderColor =>
_isDarkMode
? Colors.white.withOpacity(0.07)
    : Colors.black.withOpacity(0.06);

Color get _accentColor =>
Theme.of(context).colorScheme.primary;

@override
Widget build(BuildContext context) {
final provider = context.watch<ItemsProvider>();
final items = provider.items;

return Scaffold(
backgroundColor: _backgroundColor,
body: SafeArea(
bottom: false,
child: CustomScrollView(
physics: const BouncingScrollPhysics(),
slivers: [
SliverToBoxAdapter(
child: _buildTopHeader(items.length),
),
SliverToBoxAdapter(
child: _buildIntro(),
),
if (provider.isLoading && items.isEmpty)
SliverFillRemaining(
hasScrollBody: false,
child: _buildLoadingState(),
)
else if (items.isEmpty)
SliverFillRemaining(
hasScrollBody: false,
child: _buildEmptyState(),
)
else
SliverPadding(
padding: const EdgeInsets.fromLTRB(
16,
4,
16,
110,
),
sliver: SliverList(
delegate: SliverChildBuilderDelegate(
(context, index) {
final item = items[index];

return Padding(
padding: const EdgeInsets.only(
bottom: 16,
),
child: _ItemCard(
item: item,
),
);
},
childCount: items.length,
),
),
),
],
),
),
);
}

Widget _buildTopHeader(int count) {
return Padding(
padding: const EdgeInsets.fromLTRB(
18,
10,
18,
4,
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Text(
'KIDLOOP',
style: TextStyle(
color: _accentColor,
fontSize: 11,
fontWeight: FontWeight.w800,
letterSpacing: 1.8,
),
),
const SizedBox(width: 8),
Container(
width: 5,
height: 5,
decoration: BoxDecoration(
color: _accentColor,
shape: BoxShape.circle,
),
),
const SizedBox(width: 6),
Text(
'$count',
style: TextStyle(
color: _tertiaryTextColor,
fontSize: 10,
fontWeight: FontWeight.w600,
),
),
],
),
const SizedBox(height: 3),
Text(
'Лента обмена',
style: TextStyle(
color: _textColor,
fontSize: 30,
fontWeight: FontWeight.w800,
letterSpacing: -1.0,
height: 1.05,
),
),
],
),
),
_buildHeaderButton(
icon: Icons.tune_rounded,
onTap: () {
// TODO: Фильтры
},
),
],
),
);
}

Widget _buildHeaderButton({
required IconData icon,
required VoidCallback onTap,
}) {
return Material(
color: Colors.transparent,
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(16),
child: Container(
width: 46,
height: 46,
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: _borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
_isDarkMode ? 0.14 : 0.045,
),
blurRadius: 12,
offset: const Offset(0, 5),
),
],
),
child: Icon(
icon,
color: _textColor,
size: 21,
),
),
),
);
}

Widget _buildIntro() {
return Padding(
padding: const EdgeInsets.fromLTRB(
18,
8,
18,
14,
),
child: Row(
children: [
Container(
width: 32,
height: 32,
decoration: BoxDecoration(
color: _accentColor.withOpacity(0.10),
borderRadius: BorderRadius.circular(11),
),
child: Icon(
Icons.swap_horiz_rounded,
color: _accentColor,
size: 17,
),
),
const SizedBox(width: 9),
Expanded(
child: Text(
'Находи вещи, которые хочется обменять',
style: TextStyle(
color: _secondaryTextColor,
fontSize: 12.5,
fontWeight: FontWeight.w500,
),
),
),
Icon(
Icons.auto_awesome_rounded,
color: _accentColor.withOpacity(0.65),
size: 17,
),
],
),
);
}

Widget _buildLoadingState() {
return Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 58,
height: 58,
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: _borderColor,
),
),
child: Center(
child: SizedBox(
width: 22,
height: 22,
child: CircularProgressIndicator(
strokeWidth: 2.3,
valueColor:
AlwaysStoppedAnimation<Color>(
_accentColor,
),
),
),
),
),
const SizedBox(height: 14),
Text(
'Загружаем ленту',
style: TextStyle(
color: _textColor,
fontSize: 15,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 5),
Text(
'Ищем новые предложения',
style: TextStyle(
color: _secondaryTextColor,
fontSize: 12,
),
),
],
),
);
}

Widget _buildEmptyState() {
return Center(
child: Padding(
padding: const EdgeInsets.all(32),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 84,
height: 84,
decoration: BoxDecoration(
color: _accentColor.withOpacity(0.09),
shape: BoxShape.circle,
),
child: Icon(
Icons.toys_outlined,
color: _accentColor,
size: 40,
),
),
const SizedBox(height: 20),
Text(
'Пока здесь пусто',
style: TextStyle(
color: _textColor,
fontSize: 21,
fontWeight: FontWeight.w800,
letterSpacing: -0.4,
),
),
const SizedBox(height: 7),
Text(
'Добавь вещь и начни обмен.',
textAlign: TextAlign.center,
style: TextStyle(
color: _secondaryTextColor,
fontSize: 13,
height: 1.35,
),
),
],
),
),
);
}
}

class _ItemCard extends StatelessWidget {
final Item item;

const _ItemCard({
required this.item,
});

Color _accentColor(BuildContext context) {
return Theme.of(context).colorScheme.primary;
}

bool _isDark(BuildContext context) {
return Theme.of(context).brightness ==
Brightness.dark;
}

Color _surfaceColor(BuildContext context) {
return _isDark(context)
? const Color(0xFF1C1C1E)
    : Colors.white;
}

Color _secondarySurfaceColor(
BuildContext context,
) {
return _isDark(context)
? const Color(0xFF2C2C2E)
    : const Color(0xFFF8F8FA);
}

Color _textColor(BuildContext context) {
return _isDark(context)
? Colors.white
    : const Color(0xFF111111);
}

Color _secondaryTextColor(
BuildContext context,
) {
return _isDark(context)
? const Color(0xFF98989F)
    : const Color(0xFF6F6F76);
}

Color _tertiaryTextColor(
BuildContext context,
) {
return _isDark(context)
? const Color(0xFF636366)
    : const Color(0xFF8E8E93);
}

Color _borderColor(BuildContext context) {
return _isDark(context)
? Colors.white.withOpacity(0.07)
    : Colors.black.withOpacity(0.06);
}

@override
Widget build(BuildContext context) {
final accent = _accentColor(context);
final isDark = _isDark(context);

return GestureDetector(
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
ItemDetailsScreen(item: item),
),
);
},
child: Container(
decoration: BoxDecoration(
color: _surfaceColor(context),
borderRadius: BorderRadius.circular(26),
border: Border.all(
color: _borderColor(context),
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
isDark ? 0.18 : 0.055,
),
blurRadius: 24,
offset: const Offset(0, 10),
),
],
),
clipBehavior: Clip.antiAlias,
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
_buildImageArea(
context,
accent,
),
_buildContent(
context,
accent,
),
],
),
),
);
}

Widget _buildImageArea(
BuildContext context,
Color accent,
) {
return SizedBox(
height: 260,
width: double.infinity,
child: Stack(
fit: StackFit.expand,
children: [
CachedNetworkImage(
imageUrl: item.imagePath,
fit: BoxFit.cover,
fadeInDuration:
const Duration(milliseconds: 240),
placeholder: (
context,
url,
) {
return Container(
color:
_secondarySurfaceColor(context),
alignment: Alignment.center,
child: SizedBox(
width: 24,
height: 24,
child: CircularProgressIndicator(
strokeWidth: 2,
valueColor:
AlwaysStoppedAnimation<Color>(
accent,
),
),
),
);
},
errorWidget: (
context,
url,
error,
) {
return Container(
color:
_secondarySurfaceColor(context),
alignment: Alignment.center,
child: Icon(
Icons.toys_outlined,
color:
_tertiaryTextColor(context),
size: 60,
),
);
},
),

Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.black.withOpacity(0.30),
Colors.transparent,
Colors.black.withOpacity(0.12),
],
stops: const [
0.0,
0.48,
1.0,
],
),
),
),
),

if (item.category.isNotEmpty)
Positioned(
left: 13,
top: 13,
child: _glassBadge(
context,
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.category_outlined,
size: 12,
color: Colors.white,
),
const SizedBox(width: 5),
Text(
item.category,
style: const TextStyle(
color: Colors.white,
fontSize: 11,
fontWeight: FontWeight.w700,
),
),
],
),
),
),

Positioned(
right: 13,
top: 13,
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 12,
vertical: 8,
),
decoration: BoxDecoration(
color: accent,
borderRadius:
BorderRadius.circular(15),
boxShadow: [
BoxShadow(
color:
accent.withOpacity(0.32),
blurRadius: 15,
offset:
const Offset(0, 5),
),
],
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.auto_awesome_rounded,
color: Colors.white,
size: 14,
),
const SizedBox(width: 5),
Text(
'${item.sv} SV',
style:
const TextStyle(
color: Colors.white,
fontSize: 12,
fontWeight:
FontWeight.w800,
),
),
],
),
),
),

Positioned(
left: 13,
bottom: 13,
child: _glassBadge(
context,
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.swap_horizontal_circle_outlined,
color: Colors.white,
size: 14,
),
const SizedBox(width: 5),
const Text(
'Обмен',
style: TextStyle(
color: Colors.white,
fontSize: 10.5,
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

Widget _glassBadge(
BuildContext context, {
required Widget child,
}) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 9,
vertical: 7,
),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.38),
borderRadius: BorderRadius.circular(13),
border: Border.all(
color: Colors.white.withOpacity(0.13),
),
),
child: child,
);
}

Widget _buildContent(
BuildContext context,
Color accent,
) {
final conditionColor =
_getConditionColor(item.condition);

return Padding(
padding: const EdgeInsets.fromLTRB(
16,
15,
16,
16,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
child: Text(
item.title,
style: TextStyle(
color: _textColor(context),
fontSize: 19,
fontWeight: FontWeight.w800,
height: 1.15,
letterSpacing: -0.3,
),
maxLines: 2,
overflow:
TextOverflow.ellipsis,
),
),
if (item.condition.isNotEmpty) ...[
const SizedBox(width: 10),
_conditionBadge(
context,
conditionColor,
),
],
],
),

if (item.description.isNotEmpty) ...[
const SizedBox(height: 9),
Text(
item.description,
style: TextStyle(
color:
_secondaryTextColor(context),
fontSize: 13,
height: 1.38,
),
maxLines: 2,
overflow:
TextOverflow.ellipsis,
),
],

const SizedBox(height: 16),

Container(
height: 1,
color: _borderColor(context),
),

const SizedBox(height: 12),

Row(
children: [
Container(
width: 34,
height: 34,
decoration: BoxDecoration(
color:
Colors.blue.withOpacity(0.09),
borderRadius:
BorderRadius.circular(11),
),
child: Icon(
Icons.location_on_outlined,
color: Colors.blue.shade400,
size: 18,
),
),
const SizedBox(width: 9),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Место',
style: TextStyle(
color:
_tertiaryTextColor(
context,
),
fontSize: 9.5,
fontWeight:
FontWeight.w600,
),
),
const SizedBox(height: 1),
Text(
item.location.isNotEmpty
? item.location
    : 'Не указано',
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color:
_textColor(context),
fontSize: 12,
fontWeight:
FontWeight.w600,
),
),
],
),
),
const SizedBox(width: 8),
Container(
height: 38,
padding:
const EdgeInsets.symmetric(
horizontal: 14,
),
decoration: BoxDecoration(
color:
accent.withOpacity(0.10),
borderRadius:
BorderRadius.circular(13),
),
alignment: Alignment.center,
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Text(
'Открыть',
style: TextStyle(
color: accent,
fontSize: 11.5,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(width: 4),
Icon(
Icons
    .arrow_forward_rounded,
color: accent,
size: 15,
),
],
),
),
],
),
],
),
);
}

Widget _conditionBadge(
BuildContext context,
Color color,
) {
return Container(
constraints:
const BoxConstraints(maxWidth: 95),
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 6,
),
decoration: BoxDecoration(
color: color.withOpacity(0.10),
borderRadius:
BorderRadius.circular(10),
border: Border.all(
color: color.withOpacity(0.18),
),
),
child: Text(
item.condition,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: color,
fontSize: 9.5,
fontWeight: FontWeight.w700,
),
),
);
}

Color _getConditionColor(
String condition,
) {
switch (condition) {
case 'Новый':
return const Color(0xFF30D158);

case 'Отличный':
return const Color(0xFF00A896);

case 'Хороший':
return const Color(0xFF0A84FF);

case 'Обычный':
return const Color(0xFF8E8E93);

default:
return const Color(0xFF8E8E93);
}
}
}

