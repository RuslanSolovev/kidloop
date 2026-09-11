// features/dashboard/manage_banners_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BannerAd {
final String id;
final String imageUrl;
final String title;
final String subtitle;
final String overlayText;
final String link;
final String description;
final bool isActive;
final DateTime createdAt;

BannerAd({
required this.id,
required this.imageUrl,
required this.title,
required this.subtitle,
this.overlayText = '',
this.link = '',
this.description = '',
this.isActive = true,
required this.createdAt,
});
}

class ManageBannersScreen extends StatefulWidget {
const ManageBannersScreen({
super.key,
});

@override
State<ManageBannersScreen> createState() =>
_ManageBannersScreenState();
}

class _ManageBannersScreenState
extends State<ManageBannersScreen>
with SingleTickerProviderStateMixin {
List<BannerAd> _banners = [];

bool _loading = true;
bool _isProcessing = false;

String? _currentUserId;

late AnimationController _fadeController;
late Animation<double> _fadeAnimation;

static const String _apiUrl =
'https://functions.yandexcloud.net/d4e9bd6bmvqmife91gf4';

static const String _uploadApiUrl =
'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';

bool get _isDarkMode =>
Theme.of(context).brightness ==
Brightness.dark;

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

Color get _subTextColor =>
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

Color get _greenColor =>
const Color(0xFF30D158);

Color get _redColor =>
const Color(0xFFFF453A);

Color get _blueColor =>
const Color(0xFF0A84FF);

@override
void initState() {
super.initState();

_fadeController = AnimationController(
vsync: this,
duration: const Duration(
milliseconds: 450,
),
);

_fadeAnimation =
CurvedAnimation(
parent: _fadeController,
curve: Curves.easeOutCubic,
);

_fadeController.forward();

_loadBanners();
}

@override
void dispose() {
_fadeController.dispose();
super.dispose();
}

Future<void> _loadBanners() async {
if (mounted) {
setState(() {
_loading = true;
});
}

try {
final prefs =
await SharedPreferences.getInstance();

_currentUserId =
prefs.getString('user_id');

final response = await http
    .post(
Uri.parse(_apiUrl),
headers: {
'Content-Type':
'application/json',
},
body: jsonEncode({
'action':
'get-all-banners',
}),
)
    .timeout(
const Duration(
seconds: 8,
),
);

if (!mounted) {
return;
}

final data =
jsonDecode(response.body);

if (data['ok'] == true) {
final rawBanners =
data['banners']
as List? ??
[];

final banners =
rawBanners
    .map(
(banner) {
return BannerAd(
id: banner[
'banner_id']
    ?.toString() ??
'',
imageUrl: banner[
'image_url']
    ?.toString() ??
'',
title: banner[
'title']
    ?.toString() ??
'',
subtitle: banner[
'subtitle']
    ?.toString() ??
'',
overlayText: banner[
'overlay_text']
    ?.toString() ??
'',
link: banner[
'link']
    ?.toString() ??
'',
description: banner[
'description']
    ?.toString() ??
'',
isActive:
banner[
'is_active'] ==
true ||
banner[
'is_active']
    ?.toString()
    .toLowerCase() ==
'true',
createdAt:
DateTime.tryParse(
banner[
'created_at']
    ?.toString() ??
'',
) ??
DateTime.now(),
);
},
)
    .toList();

banners.sort(
(a, b) =>
b.createdAt
    .compareTo(
a.createdAt,
),
);

setState(() {
_banners = banners;
_loading = false;
});

_fadeController.forward(
from: 0,
);
} else {
setState(() {
_loading = false;
});
}
} catch (_) {
if (mounted) {
setState(() {
_loading = false;
});

_showSnackBar(
'Не удалось загрузить баннеры',
_redColor,
);
}
}
}

Future<void> _createOrEditBanner({
BannerAd? existing,
}) async {
final titleCtrl =
TextEditingController(
text: existing?.title ?? '',
);

final subtitleCtrl =
TextEditingController(
text: existing?.subtitle ?? '',
);

final overlayCtrl =
TextEditingController(
text: existing?.overlayText ?? '',
);

final linkCtrl =
TextEditingController(
text: existing?.link ?? '',
);

final descCtrl =
TextEditingController(
text: existing?.description ?? '',
);

final result =
await Navigator.push<
Map<String, dynamic>>(
context,
PageRouteBuilder(
pageBuilder: (
_,
__,
___,
) =>
_BannerEditorScreen(
imageUrl:
existing?.imageUrl,
imageFile: null,
titleCtrl:
titleCtrl,
subtitleCtrl:
subtitleCtrl,
overlayCtrl:
overlayCtrl,
linkCtrl:
linkCtrl,
descCtrl:
descCtrl,
isEditing:
existing != null,
),
transitionsBuilder: (
_,
animation,
__,
child,
) {
return SlideTransition(
position: Tween<
Offset>(
begin:
const Offset(
0,
1,
),
end:
Offset.zero,
).animate(
CurvedAnimation(
parent: animation,
curve:
Curves.easeOutCubic,
),
),
child: child,
);
},
),
);

titleCtrl.dispose();
subtitleCtrl.dispose();
overlayCtrl.dispose();
linkCtrl.dispose();
descCtrl.dispose();

if (result == null ||
!mounted) {
return;
}

setState(() {
_isProcessing = true;
});

try {
String? finalImageUrl =
result['imageUrl']
as String?;

final imageFile =
result['imageFile'] as File?;

if (imageFile != null) {
final bytes =
await imageFile.readAsBytes();

final encoded =
base64Encode(bytes);

final uploadResponse =
await http
    .post(
Uri.parse(
_uploadApiUrl,
),
headers: {
'Content-Type':
'application/json',
},
body:
jsonEncode({
'action': 'upload',
'file_name':
'banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
'file_data':
encoded,
}),
)
    .timeout(
const Duration(
seconds: 15,
),
);

final uploadData =
jsonDecode(
uploadResponse.body,
);

if (uploadData['ok'] == true) {
finalImageUrl =
uploadData['file_url']
    ?.toString();
} else {
throw Exception(
'Upload failed',
);
}
}

final action =
existing != null
? 'update-banner'
    : 'create-banner';

final body =
<String, dynamic>{
'action': action,
'title':
result['title'] ?? '',
'subtitle':
result['subtitle'] ?? '',
'overlay_text':
result['overlay'] ?? '',
'link':
result['link'] ?? '',
'description':
result['description'] ??
'',
'image_url':
finalImageUrl ?? '',
'user_id':
_currentUserId,
};

if (existing != null) {
body['banner_id'] =
existing.id;
}

final response =
await http
    .post(
Uri.parse(_apiUrl),
headers: {
'Content-Type':
'application/json',
},
body:
jsonEncode(body),
)
    .timeout(
const Duration(
seconds: 8,
),
);

if (response.statusCode <
200 ||
response.statusCode >=
300) {
throw Exception(
'Save failed',
);
}

await _loadBanners();

if (mounted) {
_showSnackBar(
existing != null
? 'Баннер обновлён'
    : 'Баннер создан',
_greenColor,
);
}
} catch (_) {
if (mounted) {
_showSnackBar(
'Ошибка сохранения баннера',
_redColor,
);
}
} finally {
if (mounted) {
setState(() {
_isProcessing = false;
});
}
}
}

Future<void> _deleteBanner(
String bannerId,
) async {
final confirm =
await showDialog<bool>(
context: context,
builder: (ctx) =>
_DeleteDialog(
isDarkMode:
_isDarkMode,
accentColor:
_redColor,
onCancel: () =>
Navigator.pop(
ctx,
false,
),
onDelete: () =>
Navigator.pop(
ctx,
true,
),
),
);

if (confirm != true ||
!mounted) {
return;
}

setState(() {
_isProcessing = true;
});

try {
final response =
await http
    .post(
Uri.parse(_apiUrl),
headers: {
'Content-Type':
'application/json',
},
body:
jsonEncode({
'action':
'delete-banner',
'banner_id':
bannerId,
'user_id':
_currentUserId,
}),
)
    .timeout(
const Duration(
seconds: 8,
),
);

if (response.statusCode <
200 ||
response.statusCode >=
300) {
throw Exception(
'Delete failed',
);
}

await _loadBanners();

if (mounted) {
_showSnackBar(
'Баннер удалён',
_redColor,
);
}
} catch (_) {
if (mounted) {
_showSnackBar(
'Не удалось удалить баннер',
_redColor,
);
}
} finally {
if (mounted) {
setState(() {
_isProcessing = false;
});
}
}
}

Future<void> _toggleActive(
BannerAd banner,
) async {
if (_isProcessing) {
return;
}

setState(() {
_isProcessing = true;
});

try {
final response =
await http
    .post(
Uri.parse(_apiUrl),
headers: {
'Content-Type':
'application/json',
},
body:
jsonEncode({
'action':
'toggle-banner',
'banner_id':
banner.id,
'is_active':
!banner.isActive,
'user_id':
_currentUserId,
}),
)
    .timeout(
const Duration(
seconds: 8,
),
);

if (response.statusCode <
200 ||
response.statusCode >=
300) {
throw Exception(
'Toggle failed',
);
}

await _loadBanners();
} catch (_) {
if (mounted) {
_showSnackBar(
'Не удалось изменить статус',
_redColor,
);
}
} finally {
if (mounted) {
setState(() {
_isProcessing = false;
});
}
}
}

@override
Widget build(
BuildContext context,
) {
return Scaffold(
backgroundColor:
_backgroundColor,
body: SafeArea(
bottom: false,
child: Column(
children: [
_buildHeader(),
Expanded(
child: _loading
? _buildLoadingState()
    : _banners.isEmpty
? _buildEmptyState()
    : Stack(
children: [
FadeTransition(
opacity:
_fadeAnimation,
child:
RefreshIndicator(
onRefresh:
_loadBanners,
color:
_accentColor,
backgroundColor:
_surfaceColor,
child:
ListView.builder(
physics:
const BouncingScrollPhysics(
parent:
AlwaysScrollableScrollPhysics(),
),
padding:
const EdgeInsets.fromLTRB(
16,
3,
16,
120,
),
itemCount:
_banners.length,
itemBuilder:
(
context,
index,
) {
return _buildBannerCard(
_banners[
index],
);
},
),
),
),
if (_isProcessing)
Positioned.fill(
child:
Container(
color: Colors
    .black
    .withOpacity(
0.08,
),
child:
Center(
child:
Container(
width: 48,
height:
48,
decoration:
BoxDecoration(
color:
_surfaceColor,
shape:
BoxShape.circle,
),
child:
Center(
child:
CircularProgressIndicator(
strokeWidth:
2.2,
valueColor:
AlwaysStoppedAnimation<Color>(
_accentColor,
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
],
),
),
floatingActionButton:
_buildFloatingActionButton(),
floatingActionButtonLocation:
FloatingActionButtonLocation
    .centerFloat,
);
}

Widget _buildHeader() {
final activeCount =
_banners.where(
(banner) => banner.isActive,
).length;

return Padding(
padding:
const EdgeInsets.fromLTRB(
18,
10,
18,
14,
),
child: Row(
children: [
_buildBackButton(),
const SizedBox(
width: 12,
),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'KIDLOOP',
style: TextStyle(
color:
_accentColor,
fontSize: 10,
fontWeight:
FontWeight.w800,
letterSpacing:
1.7,
),
),
const SizedBox(
height: 2,
),
Text(
'Баннеры',
style: TextStyle(
color:
_textColor,
fontSize: 26,
fontWeight:
FontWeight.w800,
letterSpacing:
-0.7,
height: 1,
),
),
],
),
),
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
vertical: 8,
),
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius.circular(
13,
),
border: Border.all(
color:
_borderColor,
),
),
child: Row(
children: [
Container(
width: 7,
height: 7,
decoration:
BoxDecoration(
color:
_greenColor,
shape:
BoxShape.circle,
),
),
const SizedBox(
width: 6,
),
Text(
'$activeCount активно',
style:
TextStyle(
color:
_subTextColor,
fontSize: 10,
fontWeight:
FontWeight.w600,
),
),
],
),
),
],
),
);
}

Widget _buildBackButton() {
return GestureDetector(
onTap: () =>
Navigator.pop(context),
child: Container(
width: 44,
height: 44,
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius.circular(
15,
),
border:
Border.all(
color:
_borderColor,
),
boxShadow: [
BoxShadow(
color:
Colors.black.withOpacity(
_isDarkMode
? 0.14
    : 0.04,
),
blurRadius:
12,
offset:
const Offset(0, 5),
),
],
),
alignment:
Alignment.center,
child: Icon(
Icons
    .arrow_back_rounded,
color:
_textColor,
size: 21,
),
),
);
}

Widget _buildFloatingActionButton() {
return Padding(
padding:
const EdgeInsets.only(
bottom: 8,
),
child: Container(
decoration:
BoxDecoration(
borderRadius:
BorderRadius.circular(
17,
),
boxShadow: [
BoxShadow(
color:
_accentColor.withOpacity(
0.28,
),
blurRadius:
16,
offset:
const Offset(0, 7),
),
],
),
child:
FloatingActionButton.extended(
onPressed: _isProcessing
? null
    : () =>
_createOrEditBanner(),
backgroundColor:
_accentColor,
foregroundColor:
Colors.white,
elevation: 0,
icon: const Icon(
Icons.add_rounded,
size: 21,
),
label:
const Text(
'Новый баннер',
style:
TextStyle(
fontSize: 13,
fontWeight:
FontWeight.w800,
),
),
),
),
);
}

Widget _buildLoadingState() {
return Center(
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 56,
height: 56,
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius.circular(
17,
),
border:
Border.all(
color:
_borderColor,
),
),
child:
Center(
child:
CircularProgressIndicator(
strokeWidth:
2.2,
valueColor:
AlwaysStoppedAnimation<
Color>(
_accentColor,
),
),
),
),
const SizedBox(
height: 13,
),
Text(
'Загружаем баннеры',
style:
TextStyle(
color:
_textColor,
fontSize:
14,
fontWeight:
FontWeight.w700,
),
),
],
),
);
}

Widget _buildEmptyState() {
return Center(
child: Padding(
padding:
const EdgeInsets.all(
30,
),
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 84,
height: 84,
decoration:
BoxDecoration(
color:
_accentColor
    .withOpacity(
0.09,
),
shape:
BoxShape.circle,
),
child: Icon(
Icons
    .campaign_outlined,
color:
_accentColor,
size: 40,
),
),
const SizedBox(
height: 19,
),
Text(
'Пока нет баннеров',
textAlign:
TextAlign.center,
style:
TextStyle(
color:
_textColor,
fontSize:
20,
fontWeight:
FontWeight.w800,
letterSpacing:
-0.4,
),
),
const SizedBox(
height: 7,
),
Text(
'Создайте первый баннер для главного экрана KidLoop.',
textAlign:
TextAlign.center,
style:
TextStyle(
color:
_subTextColor,
fontSize:
12.5,
height:
1.4,
),
),
const SizedBox(
height: 18,
),
Text(
'Используйте кнопку «Новый баннер» снизу.',
textAlign:
TextAlign.center,
style:
TextStyle(
color:
_tertiaryTextColor,
fontSize:
10.5,
),
),
],
),
),
);
}

Widget _buildBannerCard(
BannerAd banner,
) {
final statusColor =
banner.isActive
? _greenColor
    : _tertiaryTextColor;

return Padding(
padding:
const EdgeInsets.only(
bottom: 14,
),
child: Container(
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius.circular(
23,
),
border:
Border.all(
color:
_borderColor,
),
boxShadow: [
BoxShadow(
color:
Colors.black.withOpacity(
_isDarkMode
? 0.14
    : 0.04,
),
blurRadius:
20,
offset:
const Offset(0, 8),
),
],
),
clipBehavior:
Clip.antiAlias,
child: Column(
children: [
_buildBannerPreview(
banner,
statusColor,
),
_buildBannerInfo(
banner,
),
],
),
),
);
}

Widget _buildBannerPreview(
BannerAd banner,
Color statusColor,
) {
return AspectRatio(
aspectRatio:
16 / 8.8,
child: Stack(
fit:
StackFit.expand,
children: [
if (banner.imageUrl
    .isNotEmpty)
CachedNetworkImage(
imageUrl:
banner.imageUrl,
fit:
BoxFit.cover,
placeholder:
(_, __) =>
_previewFallback(),
errorWidget:
(_, __, ___) =>
_previewFallback(),
)
else
_previewFallback(),
Positioned.fill(
child:
DecoratedBox(
decoration:
BoxDecoration(
gradient:
LinearGradient(
begin:
Alignment.topCenter,
end:
Alignment.bottomCenter,
colors: [
Colors.black
    .withOpacity(
0.06,
),
Colors.black
    .withOpacity(
0.55,
),
],
),
),
),
),
Positioned(
left:
13,
right:
13,
bottom:
13,
child:
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
if (banner.overlayText
    .isNotEmpty)
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal:
8,
vertical:
5,
),
decoration:
BoxDecoration(
color:
Colors.white
    .withOpacity(
0.15,
),
borderRadius:
BorderRadius
    .circular(
8,
),
border:
Border.all(
color:
Colors.white
    .withOpacity(
0.16,
),
),
),
child:
Text(
banner
    .overlayText,
style:
const TextStyle(
color:
Colors.white,
fontSize:
8.5,
fontWeight:
FontWeight
    .w800,
letterSpacing:
0.8,
),
),
),
if (banner.overlayText
    .isNotEmpty)
const SizedBox(
height:
5,
),
Text(
banner.title,
maxLines:
2,
overflow:
TextOverflow
    .ellipsis,
style:
const TextStyle(
color:
Colors.white,
fontSize:
17,
fontWeight:
FontWeight
    .w800,
height:
1.08,
),
),
if (banner.subtitle
    .isNotEmpty)
const SizedBox(
height:
3,
),
if (banner.subtitle
    .isNotEmpty)
Text(
banner.subtitle,
maxLines:
1,
overflow:
TextOverflow
    .ellipsis,
style:
TextStyle(
color:
Colors.white
    .withOpacity(
0.82,
),
fontSize:
10.5,
fontWeight:
FontWeight.w500,
),
),
],
),
),
Positioned(
top:
12,
right:
12,
child:
ClipRRect(
borderRadius:
BorderRadius.circular(
10,
),
child:
BackdropFilter(
filter:
ImageFilter.blur(
sigmaX:
10,
sigmaY:
10,
),
child:
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal:
9,
vertical:
6,
),
decoration:
BoxDecoration(
color:
Colors.black
    .withOpacity(
0.25,
),
borderRadius:
BorderRadius
    .circular(
10,
),
border:
Border.all(
color:
Colors.white
    .withOpacity(
0.12,
),
),
),
child:
Row(
mainAxisSize:
MainAxisSize
    .min,
children: [
Container(
width:
6,
height:
6,
decoration:
BoxDecoration(
color:
statusColor,
shape:
BoxShape
    .circle,
),
),
const SizedBox(
width:
5,
),
Text(
banner
    .isActive
? 'АКТИВЕН'
    : 'СКРЫТ',
style:
TextStyle(
color:
Colors.white,
fontSize:
8.5,
fontWeight:
FontWeight
    .w800,
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
);
}

Widget _previewFallback() {
return Container(
decoration:
BoxDecoration(
gradient:
LinearGradient(
begin:
Alignment.topLeft,
end:
Alignment.bottomRight,
colors: [
_accentColor,
Color.lerp(
_accentColor,
Colors.black,
0.30,
) ??
_accentColor,
],
),
),
child:
Center(
child:
Icon(
Icons
    .campaign_outlined,
color:
Colors.white
    .withOpacity(
0.55,
),
size:
48,
),
),
);
}

Widget _buildBannerInfo(
BannerAd banner,
) {
final statusColor =
banner.isActive
? _greenColor
    : _tertiaryTextColor;

return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
14,
15,
14,
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
banner.title,
maxLines:
2,
overflow:
TextOverflow
    .ellipsis,
style:
TextStyle(
color:
_textColor,
fontSize:
16,
fontWeight:
FontWeight.w800,
height:
1.15,
),
),
),
const SizedBox(
width:
8,
),
_smallStatusBadge(
banner
    .isActive,
statusColor,
),
],
),
if (banner
    .subtitle
    .isNotEmpty)
Padding(
padding:
const EdgeInsets.only(
top:
5,
),
child:
Text(
banner.subtitle,
maxLines:
2,
overflow:
TextOverflow.ellipsis,
style:
TextStyle(
color:
_subTextColor,
fontSize:
11.5,
height:
1.3,
),
),
),
if (banner.link.isNotEmpty)
Padding(
padding:
const EdgeInsets.only(
top:
9,
),
child:
Row(
children: [
Icon(
Icons
    .link_rounded,
color:
_blueColor,
size:
15,
),
const SizedBox(
width:
5,
),
Expanded(
child:
Text(
banner.link,
maxLines:
1,
overflow:
TextOverflow
    .ellipsis,
style:
TextStyle(
color:
_blueColor,
fontSize:
10.5,
fontWeight:
FontWeight
    .w500,
),
),
),
],
),
),
const SizedBox(
height:
12,
),
Container(
height:
1,
color:
_borderColor,
),
const SizedBox(
height:
10,
),
Row(
children: [
Icon(
Icons
    .calendar_today_outlined,
color:
_tertiaryTextColor,
size:
14,
),
const SizedBox(
width:
5,
),
Text(
_formatDate(
banner.createdAt,
),
style:
TextStyle(
color:
_tertiaryTextColor,
fontSize:
10,
fontWeight:
FontWeight.w600,
),
),
const Spacer(),
_buildActionButton(
icon:
Icons
    .toggle_on_outlined,
color:
banner
    .isActive
? _greenColor
    : _tertiaryTextColor,
text:
banner.isActive
? 'Выключить'
    : 'Включить',
onTap: () =>
_toggleActive(
banner,
),
),
const SizedBox(
width:
6,
),
_buildIconAction(
icon:
Icons.edit_outlined,
color:
_blueColor,
onTap: () =>
_createOrEditBanner(
existing:
banner,
),
),
const SizedBox(
width:
6,
),
_buildIconAction(
icon:
Icons.delete_outline_rounded,
color:
_redColor,
onTap: () =>
_deleteBanner(
banner.id,
),
),
],
),
],
),
);
}

Widget _smallStatusBadge(
bool active,
Color color,
) {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal:
8,
vertical:
5,
),
decoration:
BoxDecoration(
color:
color.withOpacity(
0.09,
),
borderRadius:
BorderRadius.circular(
9,
),
),
child:
Text(
active
? 'АКТИВЕН'
    : 'СКРЫТ',
style:
TextStyle(
color:
color,
fontSize:
8.5,
fontWeight:
FontWeight.w800,
),
),
);
}

Widget _buildActionButton({
required IconData icon,
required Color color,
required String text,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap:
_isProcessing
? null
    : onTap,
child:
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal:
8,
vertical:
7,
),
decoration:
BoxDecoration(
color:
color.withOpacity(
0.08,
),
borderRadius:
BorderRadius.circular(
10,
),
),
child:
Row(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
icon,
color:
color,
size:
15,
),
const SizedBox(
width:
4,
),
Text(
text,
style:
TextStyle(
color:
color,
fontSize:
9,
fontWeight:
FontWeight.w700,
),
),
],
),
),
);
}

Widget _buildIconAction({
required IconData icon,
required Color color,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap:
_isProcessing
? null
    : onTap,
child:
Container(
width:
34,
height:
34,
decoration:
BoxDecoration(
color:
color.withOpacity(
0.08,
),
borderRadius:
BorderRadius.circular(
10,
),
),
alignment:
Alignment.center,
child:
Icon(
icon,
color:
color,
size:
17,
),
),
);
}

void _showSnackBar(
String text,
Color color,
) {
if (!mounted) return;

ScaffoldMessenger.of(context)
    .hideCurrentSnackBar();

ScaffoldMessenger.of(context)
    .showSnackBar(
SnackBar(
behavior:
SnackBarBehavior.floating,
margin:
const EdgeInsets.fromLTRB(
14,
0,
14,
14,
),
backgroundColor:
_surfaceColor,
elevation:
4,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
15,
),
side:
BorderSide(
color:
color.withOpacity(
0.18,
),
),
),
content:
Row(
children: [
Icon(
Icons
    .check_circle_outline,
color:
color,
size:
20,
),
const SizedBox(
width:
9,
),
Expanded(
child:
Text(
text,
style:
TextStyle(
color:
_textColor,
fontSize:
12.5,
fontWeight:
FontWeight
    .w700,
),
),
),
],
),
),
);
}

String _formatDate(
DateTime date,
) {
return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
}

// ============================================================================
// DELETE DIALOG
// ============================================================================
class _DeleteDialog
extends StatelessWidget {
final bool isDarkMode;
final Color accentColor;
final VoidCallback onCancel;
final VoidCallback onDelete;

const _DeleteDialog({
required this.isDarkMode,
required this.accentColor,
required this.onCancel,
required this.onDelete,
});

Color get surfaceColor =>
isDarkMode
? const Color(0xFF1C1C1E)
    : Colors.white;

Color get textColor =>
isDarkMode
? Colors.white
    : const Color(0xFF111111);

Color get subTextColor =>
isDarkMode
? const Color(0xFF98989F)
    : const Color(0xFF6F6F76);

@override
Widget build(
BuildContext context,
) {
return AlertDialog(
backgroundColor:
surfaceColor,
surfaceTintColor:
Colors.transparent,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
25,
),
),
titlePadding:
const EdgeInsets.fromLTRB(
22,
22,
22,
0,
),
contentPadding:
const EdgeInsets.fromLTRB(
22,
14,
22,
0,
),
actionsPadding:
const EdgeInsets.fromLTRB(
14,
6,
14,
14,
),
title:
Column(
children: [
Container(
width:
55,
height:
55,
decoration:
BoxDecoration(
color:
accentColor.withOpacity(
0.10,
),
shape:
BoxShape.circle,
),
child:
Icon(
Icons
    .delete_outline_rounded,
color:
accentColor,
size:
28,
),
),
const SizedBox(
height:
12,
),
Text(
'Удалить баннер?',
textAlign:
TextAlign.center,
style:
TextStyle(
color:
textColor,
fontSize:
19,
fontWeight:
FontWeight.w800,
),
),
],
),
content:
Text(
'Это действие нельзя отменить. Баннер будет удалён из списка.',
textAlign:
TextAlign.center,
style:
TextStyle(
color:
subTextColor,
fontSize:
13,
height:
1.4,
),
),
actions: [
TextButton(
onPressed:
onCancel,
child:
Text(
'Отмена',
style:
TextStyle(
color:
subTextColor,
fontWeight:
FontWeight.w600,
),
),
),
TextButton(
onPressed:
onDelete,
child:
Text(
'Удалить',
style:
TextStyle(
color:
accentColor,
fontWeight:
FontWeight.w800,
),
),
),
],
);
}
}

// ============================================================================
// BANNER EDITOR
// ============================================================================
class _BannerEditorScreen
extends StatefulWidget {
final String? imageUrl;
final File? imageFile;

final TextEditingController
titleCtrl;

final TextEditingController
subtitleCtrl;

final TextEditingController
overlayCtrl;

final TextEditingController
linkCtrl;

final TextEditingController
descCtrl;

final bool isEditing;

const _BannerEditorScreen({
this.imageUrl,
this.imageFile,
required this.titleCtrl,
required this.subtitleCtrl,
required this.overlayCtrl,
required this.linkCtrl,
required this.descCtrl,
required this.isEditing,
});

@override
State<_BannerEditorScreen>
createState() =>
_BannerEditorScreenState();
}

class _BannerEditorScreenState
extends State<_BannerEditorScreen> {
File? _imageFile;
String? _imageUrl;

@override
void initState() {
super.initState();

_imageFile =
widget.imageFile;

_imageUrl =
widget.imageUrl;

widget.titleCtrl.addListener(
_update,
);

widget.subtitleCtrl.addListener(
_update,
);

widget.overlayCtrl.addListener(
_update,
);
}

@override
void dispose() {
widget.titleCtrl.removeListener(
_update,
);

widget.subtitleCtrl.removeListener(
_update,
);

widget.overlayCtrl.removeListener(
_update,
);

super.dispose();
}

void _update() {
if (mounted) {
setState(() {});
}
}

bool get _isDarkMode =>
Theme.of(context).brightness ==
Brightness.dark;

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

Color get _subTextColor =>
_isDarkMode
? const Color(0xFF98989F)
    : const Color(0xFF6F6F76);

Color get _borderColor =>
_isDarkMode
? Colors.white.withOpacity(0.07)
    : Colors.black.withOpacity(0.06);

Color get _accentColor =>
Theme.of(context).colorScheme.primary;

Future<void> _pickImage() async {
final picker =
ImagePicker();

final picked =
await picker.pickImage(
source:
ImageSource.gallery,
imageQuality:
85,
);

if (picked == null) {
return;
}

setState(() {
_imageFile =
File(picked.path);

_imageUrl = null;
});
}

void _save() {
Navigator.pop(
context,
{
'title':
widget.titleCtrl.text
    .trim(),
'subtitle':
widget.subtitleCtrl.text
    .trim(),
'overlay':
widget.overlayCtrl.text
    .trim(),
'link':
widget.linkCtrl.text
    .trim(),
'description':
widget.descCtrl.text
    .trim(),
'imageFile':
_imageFile,
'imageUrl':
_imageUrl,
},
);
}

@override
Widget build(
BuildContext context,
) {
return Scaffold(
backgroundColor:
_backgroundColor,
body: SafeArea(
child: Column(
children: [
_buildEditorHeader(),
Expanded(
child:
SingleChildScrollView(
physics:
const BouncingScrollPhysics(),
padding:
const EdgeInsets.fromLTRB(
16,
5,
16,
30,
),
child:
Column(
children: [
_buildPreview(),
const SizedBox(
height:
20,
),
_buildFormCard(),
],
),
),
),
],
),
),
);
}

Widget _buildEditorHeader() {
return Padding(
padding:
const EdgeInsets.fromLTRB(
12,
4,
12,
10,
),
child:
Row(
children: [
GestureDetector(
onTap: () =>
Navigator.pop(
context,
),
child:
Container(
width:
42,
height:
42,
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius
    .circular(
14,
),
border:
Border.all(
color:
_borderColor,
),
),
alignment:
Alignment.center,
child:
Icon(
Icons.close_rounded,
color:
_textColor,
size:
21,
),
),
),
const SizedBox(
width:
10,
),
Expanded(
child:
Text(
widget.isEditing
? 'Редактирование'
    : 'Новый баннер',
style:
TextStyle(
color:
_textColor,
fontSize:
17,
fontWeight:
FontWeight.w800,
),
),
),
GestureDetector(
onTap:
_save,
child:
Container(
padding:
const EdgeInsets.symmetric(
horizontal:
14,
vertical:
10,
),
decoration:
BoxDecoration(
color:
_accentColor,
borderRadius:
BorderRadius.circular(
13,
),
),
child:
const Text(
'Сохранить',
style:
TextStyle(
color:
Colors.white,
fontSize:
11.5,
fontWeight:
FontWeight.w800,
),
),
),
),
],
),
);
}

Widget _buildPreview() {
return Container(
width:
double.infinity,
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius.circular(
23,
),
border:
Border.all(
color:
_borderColor,
),
boxShadow: [
BoxShadow(
color:
Colors.black.withOpacity(
_isDarkMode
? 0.16
    : 0.05,
),
blurRadius:
22,
offset:
const Offset(0, 8),
),
],
),
clipBehavior:
Clip.antiAlias,
child:
Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
AspectRatio(
aspectRatio:
16 / 9.2,
child:
Stack(
fit:
StackFit.expand,
children: [
if (_imageFile !=
null)
Image.file(
_imageFile!,
fit:
BoxFit.cover,
)
else if (_imageUrl !=
null &&
_imageUrl!
    .isNotEmpty)
CachedNetworkImage(
imageUrl:
_imageUrl!,
fit:
BoxFit.cover,
errorWidget:
(
_,
__,
___,
) =>
_previewFallback(),
)
else
_previewFallback(),
Positioned.fill(
child:
DecoratedBox(
decoration:
BoxDecoration(
gradient:
LinearGradient(
begin:
Alignment.topCenter,
end:
Alignment.bottomCenter,
colors: [
Colors
    .transparent,
Colors.black
    .withOpacity(
0.65,
),
],
),
),
),
),
Positioned(
left:
14,
right:
14,
bottom:
14,
child:
Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
if (widget
    .overlayCtrl
    .text
    .trim()
    .isNotEmpty)
Container(
padding:
const EdgeInsets
    .symmetric(
horizontal:
8,
vertical:
5,
),
decoration:
BoxDecoration(
color: Colors
    .white
    .withOpacity(
0.16,
),
borderRadius:
BorderRadius
    .circular(
8,
),
),
child:
Text(
widget
    .overlayCtrl
    .text
    .trim(),
style:
const TextStyle(
color:
Colors.white,
fontSize:
8.5,
fontWeight:
FontWeight
    .w800,
letterSpacing:
0.8,
),
),
),
if (widget
    .overlayCtrl
    .text
    .trim()
    .isNotEmpty)
const SizedBox(
height:
6,
),
Text(
widget.titleCtrl
    .text
    .trim()
    .isNotEmpty
? widget.titleCtrl.text
    : 'Заголовок баннера',
maxLines:
2,
overflow:
TextOverflow
    .ellipsis,
style:
const TextStyle(
color:
Colors.white,
fontSize:
20,
fontWeight:
FontWeight
    .w800,
height:
1.05,
),
),
const SizedBox(
height:
4,
),
Text(
widget.subtitleCtrl
    .text
    .trim()
    .isNotEmpty
? widget.subtitleCtrl.text
    : 'Краткое описание',
maxLines:
1,
overflow:
TextOverflow
    .ellipsis,
style:
TextStyle(
color:
Colors.white
    .withOpacity(
0.82,
),
fontSize:
11.5,
fontWeight:
FontWeight.w500,
),
),
],
),
),
Positioned(
top:
12,
right:
12,
child:
GestureDetector(
onTap:
_pickImage,
child:
ClipRRect(
borderRadius:
BorderRadius
    .circular(
11,
),
child:
BackdropFilter(
filter:
ImageFilter
    .blur(
sigmaX:
10,
sigmaY:
10,
),
child:
Container(
width:
40,
height:
40,
decoration:
BoxDecoration(
color: Colors
    .black
    .withOpacity(
0.26,
),
borderRadius:
BorderRadius
    .circular(
11,
),
border:
Border.all(
color: Colors
    .white
    .withOpacity(
0.12,
),
),
),
alignment:
Alignment
    .center,
child:
const Icon(
Icons
    .photo_camera_outlined,
color:
Colors.white,
size:
19,
),
),
),
),
),
),
],
),
),
Padding(
padding:
const EdgeInsets.all(
13,
),
child:
Row(
children: [
Icon(
Icons
    .visibility_outlined,
color:
_subTextColor,
size:
16,
),
const SizedBox(
width:
6,
),
Text(
'Превью как на главном экране',
style:
TextStyle(
color:
_subTextColor,
fontSize:
10.5,
fontWeight:
FontWeight.w500,
),
),
],
),
),
],
),
);
}

Widget _previewFallback() {
return Container(
decoration:
BoxDecoration(
gradient:
LinearGradient(
begin:
Alignment.topLeft,
end:
Alignment.bottomRight,
colors: [
_accentColor,
Color.lerp(
_accentColor,
Colors.black,
0.30,
) ??
_accentColor,
],
),
),
child:
Center(
child:
Icon(
Icons
    .campaign_outlined,
color:
Colors.white
    .withOpacity(
0.48,
),
size:
48,
),
),
);
}

Widget _buildFormCard() {
return Container(
padding:
const EdgeInsets.all(
16,
),
decoration:
BoxDecoration(
color:
_surfaceColor,
borderRadius:
BorderRadius.circular(
21,
),
border:
Border.all(
color:
_borderColor,
),
),
child:
Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
_field(
controller:
widget.titleCtrl,
label:
'Заголовок',
hint:
'Например: Большая распродажа!',
icon:
Icons
    .title_outlined,
),
const SizedBox(
height:
13,
),
_field(
controller:
widget.subtitleCtrl,
label:
'Подзаголовок',
hint:
'Короткий текст под заголовком',
icon:
Icons
    .short_text_rounded,
),
const SizedBox(
height:
13,
),
_field(
controller:
widget.overlayCtrl,
label:
'Бейдж',
hint:
'Например: НОВИНКА',
icon:
Icons
    .sell_outlined,
),
const SizedBox(
height:
13,
),
_field(
controller:
widget.linkCtrl,
label:
'Ссылка',
hint:
'https://example.com',
icon:
Icons
    .link_rounded,
keyboardType:
TextInputType.url,
),
const SizedBox(
height:
13,
),
_field(
controller:
widget.descCtrl,
label:
'Описание',
hint:
'Подробности для экрана баннера',
icon:
Icons
    .notes_outlined,
maxLines:
5,
),
],
),
);
}

Widget _field({
required TextEditingController
controller,
required String label,
required String hint,
required IconData icon,
int maxLines = 1,
TextInputType keyboardType =
TextInputType.text,
}) {
return Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
label,
style:
TextStyle(
color:
_textColor,
fontSize:
11,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(
height:
6,
),
Container(
decoration:
BoxDecoration(
color:
_secondarySurfaceColor,
borderRadius:
BorderRadius.circular(
15,
),
border:
Border.all(
color:
_borderColor,
),
),
child:
TextField(
controller:
controller,
maxLines:
maxLines,
keyboardType:
keyboardType,
style:
TextStyle(
color:
_textColor,
fontSize:
13,
fontWeight:
FontWeight.w500,
),
decoration:
InputDecoration(
prefixIcon:
Padding(
padding:
EdgeInsets.only(
bottom:
maxLines > 1
? 45
    : 0,
),
child:
Icon(
icon,
color:
_accentColor,
size:
18,
),
),
hintText:
hint,
hintStyle:
TextStyle(
color:
_subTextColor
    .withOpacity(
0.50,
),
fontSize:
12,
),
border:
InputBorder.none,
contentPadding:
const EdgeInsets
    .symmetric(
horizontal:
13,
vertical:
13,
),
),
),
),
],
);
}
}

