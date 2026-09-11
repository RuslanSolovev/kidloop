// features/dashboard/banner_detail_screen.dart
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_screen.dart';

class BannerDetailScreen extends StatelessWidget {
final BannerAd banner;

const BannerDetailScreen({
super.key,
required this.banner,
});

Future<void> _openLink(String url) async {
if (url.isEmpty) return;

try {
final uri = Uri.tryParse(url);

if (uri == null) return;

if (await canLaunchUrl(uri)) {
await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);
}
} catch (e) {
debugPrint('Ошибка открытия ссылки: $e');
}
}

@override
Widget build(BuildContext context) {
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;

final backgroundColor = isDark
? const Color(0xFF000000)
    : const Color(0xFFF2F2F7);

final surfaceColor = isDark
? const Color(0xFF1C1C1E)
    : Colors.white;

final secondarySurfaceColor = isDark
? const Color(0xFF2C2C2E)
    : const Color(0xFFF8F8FA);

final textColor = isDark
? Colors.white
    : const Color(0xFF111111);

final subTextColor = isDark
? const Color(0xFF98989F)
    : const Color(0xFF6F6F76);

final borderColor = isDark
? Colors.white.withOpacity(0.07)
    : Colors.black.withOpacity(0.06);

final accentColor = theme.colorScheme.primary;

return Scaffold(
backgroundColor: backgroundColor,
body: CustomScrollView(
physics: const BouncingScrollPhysics(),
slivers: [
SliverAppBar(
expandedHeight: 360,
pinned: true,
elevation: 0,
scrolledUnderElevation: 0,
backgroundColor: backgroundColor,
automaticallyImplyLeading: false,
leading: Padding(
padding: const EdgeInsets.only(
left: 12,
top: 7,
bottom: 7,
),
child: _GlassBackButton(
onTap: () => Navigator.pop(context),
),
),
flexibleSpace: FlexibleSpaceBar(
collapseMode: CollapseMode.parallax,
background: _buildHeroImage(
context,
isDark: isDark,
backgroundColor: backgroundColor,
accentColor: accentColor,
),
),
),
SliverToBoxAdapter(
child: Container(
decoration: BoxDecoration(
color: backgroundColor,
),
child: Padding(
padding: const EdgeInsets.fromLTRB(
18,
4,
18,
36,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const SizedBox(height: 4),

if (banner.overlayText.isNotEmpty)
_buildOverlayBadge(
banner.overlayText,
accentColor,
),

if (banner.overlayText.isNotEmpty)
const SizedBox(height: 13),

Text(
banner.title,
style: TextStyle(
color: textColor,
fontSize: 30,
fontWeight: FontWeight.w800,
letterSpacing: -0.9,
height: 1.08,
),
),

if (banner.subtitle.isNotEmpty) ...[
const SizedBox(height: 9),
Text(
banner.subtitle,
style: TextStyle(
color: subTextColor,
fontSize: 15.5,
height: 1.38,
fontWeight: FontWeight.w500,
),
),
],

const SizedBox(height: 22),

if (banner.description.isNotEmpty)
_buildDescriptionCard(
description: banner.description,
isDark: isDark,
surfaceColor: surfaceColor,
secondarySurfaceColor:
secondarySurfaceColor,
textColor: textColor,
subTextColor: subTextColor,
borderColor: borderColor,
),

if (banner.link.isNotEmpty) ...[
const SizedBox(height: 18),
_buildActionButton(
context,
accentColor: accentColor,
),
],

const SizedBox(height: 12),

_buildBackButton(
context,
textColor: textColor,
borderColor: borderColor,
secondarySurfaceColor:
secondarySurfaceColor,
),
],
),
),
),
),
],
),
);
}

Widget _buildHeroImage(
BuildContext context, {
required bool isDark,
required Color backgroundColor,
required Color accentColor,
}) {
return Stack(
fit: StackFit.expand,
children: [
Hero(
tag: 'banner_${banner.id}',
child: banner.imageUrl.isNotEmpty
? CachedNetworkImage(
imageUrl: banner.imageUrl,
fit: BoxFit.cover,
placeholder: (context, url) {
return _buildImageFallback(
accentColor,
);
},
errorWidget: (context, url, error) {
return _buildImageFallback(
accentColor,
);
},
)
    : _buildImageFallback(
accentColor,
),
),

Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.black.withOpacity(0.18),
Colors.transparent,
backgroundColor.withOpacity(0.20),
backgroundColor,
],
stops: const [
0.0,
0.35,
0.72,
1.0,
],
),
),
),
),

Positioned(
left: 18,
bottom: 22,
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 7,
),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.34),
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Colors.white.withOpacity(0.12),
),
),
child: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.campaign_outlined,
color: Colors.white,
size: 14,
),
SizedBox(width: 6),
Text(
'KIDLOOP',
style: TextStyle(
color: Colors.white,
fontSize: 9,
fontWeight: FontWeight.w800,
letterSpacing: 1.1,
),
),
],
),
),
),
],
);
}

Widget _buildImageFallback(
Color accentColor,
) {
final darkerAccent =
Color.lerp(
accentColor,
Colors.black,
0.30,
) ??
accentColor;

return Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
accentColor,
darkerAccent,
],
),
),
child: Center(
child: Container(
width: 82,
height: 82,
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.11),
shape: BoxShape.circle,
border: Border.all(
color: Colors.white.withOpacity(0.20),
),
),
child: const Icon(
Icons.campaign_outlined,
color: Colors.white,
size: 38,
),
),
),
);
}

Widget _buildOverlayBadge(
String text,
Color accentColor,
) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 6,
),
decoration: BoxDecoration(
color: accentColor.withOpacity(0.10),
borderRadius: BorderRadius.circular(10),
border: Border.all(
color: accentColor.withOpacity(0.16),
),
),
child: Text(
text,
style: TextStyle(
color: accentColor,
fontSize: 9.5,
fontWeight: FontWeight.w800,
letterSpacing: 1.0,
),
),
);
}

Widget _buildDescriptionCard({
required String description,
required bool isDark,
required Color surfaceColor,
required Color secondarySurfaceColor,
required Color textColor,
required Color subTextColor,
required Color borderColor,
}) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(17),
decoration: BoxDecoration(
color: surfaceColor,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
isDark ? 0.15 : 0.04,
),
blurRadius: 20,
offset: const Offset(0, 8),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 34,
height: 34,
decoration: BoxDecoration(
color: secondarySurfaceColor,
borderRadius: BorderRadius.circular(11),
),
child: Icon(
Icons.notes_outlined,
color: subTextColor,
size: 17,
),
),
const SizedBox(width: 9),
Text(
'Подробнее',
style: TextStyle(
color: textColor,
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
],
),

const SizedBox(height: 13),

Text(
description,
style: TextStyle(
color: textColor,
fontSize: 14,
height: 1.55,
),
),
],
),
);
}

Widget _buildActionButton(
BuildContext context, {
required Color accentColor,
}) {
return SizedBox(
width: double.infinity,
height: 54,
child: ElevatedButton(
onPressed: () => _openLink(banner.link),
style: ElevatedButton.styleFrom(
backgroundColor: accentColor,
foregroundColor: Colors.white,
elevation: 0,
shadowColor: accentColor.withOpacity(0.28),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Text(
'Перейти',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w800,
),
),
SizedBox(width: 7),
Icon(
Icons.arrow_outward_rounded,
size: 18,
),
],
),
),
);
}

Widget _buildBackButton(
BuildContext context, {
required Color textColor,
required Color borderColor,
required Color secondarySurfaceColor,
}) {
return SizedBox(
width: double.infinity,
height: 50,
child: OutlinedButton(
onPressed: () => Navigator.pop(context),
style: OutlinedButton.styleFrom(
foregroundColor: textColor,
backgroundColor: secondarySurfaceColor,
side: BorderSide(
color: borderColor,
),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(15),
),
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.arrow_back_rounded,
size: 18,
),
SizedBox(width: 7),
Text(
'Вернуться',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
],
),
),
);
}
}

class _GlassBackButton extends StatelessWidget {
final VoidCallback onTap;

const _GlassBackButton({
required this.onTap,
});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: onTap,
child: ClipRRect(
borderRadius: BorderRadius.circular(15),
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 14,
sigmaY: 14,
),
child: Container(
width: 43,
height: 43,
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.28),
borderRadius: BorderRadius.circular(15),
border: Border.all(
color: Colors.white.withOpacity(0.15),
),
),
alignment: Alignment.center,
child: const Icon(
Icons.arrow_back_rounded,
color: Colors.white,
size: 20,
),
),
),
),
);
}
}
