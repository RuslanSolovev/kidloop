// features/feed/presentation/trade_discussion_screen.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/trade_offer.dart';
import '../../../core/trades_provider.dart';
import '../../../services/notification_service.dart';
import 'chat_widget.dart';

class TradeDiscussionScreen extends StatefulWidget {
final TradeOffer offer;

const TradeDiscussionScreen({
super.key,
required this.offer,
});

@override
State<TradeDiscussionScreen> createState() => _TradeDiscussionScreenState();
}

class _TradeDiscussionScreenState extends State<TradeDiscussionScreen> {
String? _currentUserId;
String? _currentUserName;

String? _fromImageUrl;
String? _toImageUrl;

int _fromSv = 0;
int _toSv = 0;

String _fromDescription = '';
String _toDescription = '';
String _fromCondition = '';
String _toCondition = '';
String _fromCategory = '';
String _toCategory = '';

String _fromOwnerName = '';
String _toOwnerName = '';
String _fromOwnerId = '';
String _toOwnerId = '';

bool _isLoadingDetails = true;

static final Map<String, String> _imageCache = {};
static final Map<String, String> _nameCache = {};

Set<String> _pendingSteps = {};

static const String itemsApiUrl =
'https://functions.yandexcloud.net/d4ei9an1aushareidmjc';

static const String usersApiUrl =
'https://functions.yandexcloud.net/d4e8qq9aaimqibei5ga7';

bool get _isDarkMode =>
Theme.of(context).brightness == Brightness.dark;

Color get _backgroundColor =>
_isDarkMode ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

Color get _surfaceColor =>
_isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;

Color get _surfaceSecondaryColor =>
_isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF8F8FA);

Color get _textColor =>
_isDarkMode ? Colors.white : const Color(0xFF111111);

Color get _subTextColor =>
_isDarkMode ? const Color(0xFF98989F) : const Color(0xFF6F6F76);

Color get _tertiaryTextColor =>
_isDarkMode ? const Color(0xFF636366) : const Color(0xFF8E8E93);

Color get _borderColor =>
_isDarkMode
? Colors.white.withOpacity(0.07)
    : Colors.black.withOpacity(0.06);

Color get _accentColor => const Color(0xFFFF9500);

Color get _blueColor => const Color(0xFF0A84FF);

Color get _greenColor => const Color(0xFF30D158);

Color get _redColor => const Color(0xFFFF453A);

Color get _purpleColor => const Color(0xFFBF5AF2);

@override
void initState() {
super.initState();

_loadUserData();
_loadItemDetails();
}

Future<void> _loadUserData() async {
final prefs = await SharedPreferences.getInstance();

if (!mounted) return;

setState(() {
_currentUserId = prefs.getString('user_id');
_currentUserName = prefs.getString('user_name') ?? 'Вы';
});
}

Future<String> _getUserName(String userId) async {
if (userId.isEmpty) {
return 'Пользователь';
}

if (_nameCache.containsKey(userId)) {
return _nameCache[userId]!;
}

try {
final response = await http
    .post(
Uri.parse(usersApiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'list',
'query': '',
'user_id': '',
'offset': 0,
'limit': 100,
}),
)
    .timeout(const Duration(seconds: 8));

final data = jsonDecode(response.body);

if (data['ok'] == true) {
final users = data['users'] as List? ?? [];

for (final user in users) {
final uid = user['user_id']?.toString() ?? '';
final name = user['name']?.toString() ?? '';

if (uid.isNotEmpty && name.isNotEmpty) {
_nameCache[uid] = name;
}
}
}

if (!_nameCache.containsKey(userId)) {
final profileResponse = await http
    .post(
Uri.parse(usersApiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'get',
'user_id': userId,
}),
)
    .timeout(const Duration(seconds: 5));

final profileData = jsonDecode(profileResponse.body);

if (profileData['ok'] == true &&
profileData['profile'] != null) {
final name =
profileData['profile']['name']?.toString() ?? '';

if (name.isNotEmpty) {
_nameCache[userId] = name;
}
}
}
} catch (_) {}

return _nameCache[userId] ?? 'Пользователь';
}

Future<void> _loadItemDetails() async {
try {
final cacheKey =
'${widget.offer.fromItemId}_${widget.offer.toItemId}';

if (_imageCache.containsKey('${cacheKey}_from')) {
if (!mounted) return;

setState(() {
_fromImageUrl = _imageCache['${cacheKey}_from'];
_toImageUrl = _imageCache['${cacheKey}_to'];
_isLoadingDetails = false;
});

return;
}

final response = await http
    .post(
Uri.parse(itemsApiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'list',
'limit': 100,
}),
)
    .timeout(const Duration(seconds: 15));

if (!mounted) return;

final data = jsonDecode(response.body);

if (data['ok'] == true) {
bool foundFrom = false;
bool foundTo = false;

final items = data['items'] as List? ?? [];

for (final item in items) {
final itemId = item['item_id']?.toString() ?? '';
final ownerId = item['user_id']?.toString() ?? '';

if (itemId == widget.offer.fromItemId) {
foundFrom = true;

final imagePaths = item['image_paths'];

final imageUrl = imagePaths is List &&
imagePaths.isNotEmpty
? imagePaths.first.toString()
    : item['image_path']?.toString() ?? '';

final sv =
int.tryParse(item['sv']?.toString() ?? '0') ?? 0;

_fromOwnerId = ownerId;

final ownerName = await _getUserName(ownerId);

if (mounted) {
setState(() {
_fromImageUrl = imageUrl;
_fromSv = sv;
_fromDescription =
item['description']?.toString() ?? '';
_fromCondition =
item['condition']?.toString() ?? '';
_fromCategory =
item['category']?.toString() ?? '';
_fromOwnerName = ownerName;
});
}

_imageCache['${cacheKey}_from'] = imageUrl;
}

if (itemId == widget.offer.toItemId) {
foundTo = true;

final imagePaths = item['image_paths'];

final imageUrl = imagePaths is List &&
imagePaths.isNotEmpty
? imagePaths.first.toString()
    : item['image_path']?.toString() ?? '';

final sv =
int.tryParse(item['sv']?.toString() ?? '0') ?? 0;

_toOwnerId = ownerId;

final ownerName = await _getUserName(ownerId);

if (mounted) {
setState(() {
_toImageUrl = imageUrl;
_toSv = sv;
_toDescription =
item['description']?.toString() ?? '';
_toCondition =
item['condition']?.toString() ?? '';
_toCategory =
item['category']?.toString() ?? '';
_toOwnerName = ownerName;
});
}

_imageCache['${cacheKey}_to'] = imageUrl;
}

if (foundFrom && foundTo) {
break;
}
}
}
} catch (_) {}

if (!mounted) return;

setState(() {
_isLoadingDetails = false;
});
}

bool get _isFromUser =>
widget.offer.fromUserId == _currentUserId;

bool get _isToUser =>
widget.offer.toUserId == _currentUserId;

String get _fromDisplayName {
if (_isFromUser) return 'Вы';
if (_fromOwnerName.isNotEmpty) {
return _fromOwnerName;
}

return 'Пользователь';
}

String get _toDisplayName {
if (_isToUser) return 'Вы';
if (_toOwnerName.isNotEmpty) {
return _toOwnerName;
}

return 'Пользователь';
}

String get _payerName {
if (widget.offer.svDifference == 0) {
return '';
}

if (widget.offer.svDifference > 0) {
return _fromDisplayName;
}

return _toDisplayName;
}

@override
Widget build(BuildContext context) {
final tradesProvider = context.watch<TradesProvider>();

final offer = tradesProvider.offers.firstWhere(
(item) => item.id == widget.offer.id,
orElse: () => widget.offer,
);

final provider = context.read<TradesProvider>();

final methodsMatch =
offer.fromDeliveryMethod.isNotEmpty &&
offer.toDeliveryMethod.isNotEmpty &&
offer.fromDeliveryMethod ==
offer.toDeliveryMethod;

final isActive =
offer.status != 'cancelled' &&
offer.status != 'completed' &&
offer.status != 'rejected';

return Scaffold(
backgroundColor: _backgroundColor,
appBar: _buildAppBar(offer),
body: _isLoadingDetails
? _buildLoading()
    : CustomScrollView(
physics: const BouncingScrollPhysics(),
slivers: [
SliverPadding(
padding: const EdgeInsets.fromLTRB(
16,
8,
16,
100,
),
sliver: SliverList(
delegate: SliverChildListDelegate(
[
_buildTradeHero(offer),
const SizedBox(height: 14),
_buildExchangeCards(offer),
const SizedBox(height: 14),
_buildSVDifferenceCard(offer),
const SizedBox(height: 28),

_buildSectionTitle(
'Детали сделки',
Icons.receipt_long_rounded,
),
const SizedBox(height: 10),
_buildDetailCard(offer),

if (isActive) ...[
const SizedBox(height: 28),
_buildSectionTitle(
'Передача вещей',
Icons.local_shipping_outlined,
),
const SizedBox(height: 10),
_buildDeliveryMethods(
offer,
provider,
),
const SizedBox(height: 10),
_buildDeliveryChoices(offer),
if (offer.fromDeliveryMethod.isNotEmpty &&
offer.toDeliveryMethod.isNotEmpty) ...[
const SizedBox(height: 10),
_buildMatchIndicator(methodsMatch),
],
const SizedBox(height: 20),
if (methodsMatch)
_buildConfirmationPanel(
offer,
provider,
)
else if (offer.fromDeliveryMethod.isNotEmpty &&
offer.toDeliveryMethod.isNotEmpty)
_buildMismatchWarning(),

const SizedBox(height: 18),
_buildCancelButton(
offer,
provider,
),
],

if (offer.status == 'completed') ...[
const SizedBox(height: 28),
_buildSectionTitle(
'Итоги',
Icons.emoji_events_outlined,
),
const SizedBox(height: 10),
_buildCompletedResultCard(offer),
],

if (offer.status == 'cancelled') ...[
const SizedBox(height: 28),
_buildSectionTitle(
'Итоги отмены',
Icons.info_outline_rounded,
),
const SizedBox(height: 10),
_buildCancelledResultCard(offer),
],

const SizedBox(height: 28),
_buildSectionTitle(
'Обсуждение',
Icons.chat_bubble_outline_rounded,
),
const SizedBox(height: 10),
_buildChatSection(offer),
],
),
),
),
],
),
);
}

PreferredSizeWidget _buildAppBar(TradeOffer offer) {
final statusColor = _getStatusColor(offer.status);

return AppBar(
backgroundColor: _backgroundColor,
elevation: 0,
scrolledUnderElevation: 0,
centerTitle: true,
leading: Padding(
padding: const EdgeInsets.only(
left: 8,
top: 6,
bottom: 6,
),
child: _iconButton(
icon: Icons.arrow_back_rounded,
onTap: () => Navigator.pop(context),
),
),
title: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text(
'Обмен',
style: TextStyle(
color: _textColor,
fontSize: 17,
fontWeight: FontWeight.w700,
letterSpacing: -0.3,
),
),
const SizedBox(height: 2),
Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 6,
height: 6,
decoration: BoxDecoration(
color: statusColor,
shape: BoxShape.circle,
),
),
const SizedBox(width: 5),
Text(
_getStatusText(offer.status),
style: TextStyle(
color: statusColor,
fontSize: 11,
fontWeight: FontWeight.w600,
),
),
],
),
],
),
bottom: PreferredSize(
preferredSize: const Size.fromHeight(1),
child: Container(
height: 1,
color: _borderColor,
),
),
);
}

Widget _iconButton({
required IconData icon,
required VoidCallback onTap,
}) {
return Material(
color: _surfaceColor,
borderRadius: BorderRadius.circular(14),
child: InkWell(
borderRadius: BorderRadius.circular(14),
onTap: onTap,
child: Container(
width: 42,
height: 42,
alignment: Alignment.center,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: _borderColor,
),
),
child: Icon(
icon,
size: 21,
color: _textColor,
),
),
),
);
}

Widget _buildLoading() {
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
child: CircularProgressIndicator(
strokeWidth: 2.5,
valueColor: AlwaysStoppedAnimation<Color>(
_accentColor,
),
),
),
),
const SizedBox(height: 14),
Text(
'Загружаем обмен',
style: TextStyle(
color: _textColor,
fontSize: 15,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 4),
Text(
'Получаем информацию о вещах',
style: TextStyle(
color: _subTextColor,
fontSize: 12,
),
),
],
),
);
}

Widget _buildTradeHero(TradeOffer offer) {
final statusColor = _getStatusColor(offer.status);
final progress = _calculateProgress(offer);

return Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius: BorderRadius.circular(24),
border: Border.all(
color: statusColor.withOpacity(0.22),
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
_isDarkMode ? 0.16 : 0.05,
),
blurRadius: 22,
offset: const Offset(0, 8),
),
],
),
child: Column(
children: [
Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: statusColor.withOpacity(0.11),
borderRadius: BorderRadius.circular(15),
),
child: Icon(
_getStatusIcon(offer.status),
color: statusColor,
size: 23,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
_getStatusText(offer.status),
style: TextStyle(
color: _textColor,
fontSize: 18,
fontWeight: FontWeight.w700,
letterSpacing: -0.3,
),
),
const SizedBox(height: 3),
Text(
_getStatusDescription(offer.status),
style: TextStyle(
color: _subTextColor,
fontSize: 12.5,
),
),
],
),
),
_smallBadge(
text:
'#${offer.id.substring(0, offer.id.length > 6 ? 6 : offer.id.length).toUpperCase()}',
color: statusColor,
),
],
),
const SizedBox(height: 18),
if (offer.status == 'accepted' ||
offer.status == 'shipped') ...[
Row(
children: [
Expanded(
child: _progressLine(
value: progress,
color: statusColor,
),
),
const SizedBox(width: 10),
Text(
'${(progress * 100).round()}%',
style: TextStyle(
color: statusColor,
fontSize: 12,
fontWeight: FontWeight.w700,
),
),
],
),
] else
Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 11,
),
decoration: BoxDecoration(
color: statusColor.withOpacity(0.07),
borderRadius: BorderRadius.circular(14),
),
child: Row(
children: [
Icon(
Icons.info_outline_rounded,
size: 17,
color: statusColor,
),
const SizedBox(width: 8),
Expanded(
child: Text(
_getStatusDescription(offer.status),
style: TextStyle(
color: statusColor,
fontSize: 12,
fontWeight: FontWeight.w600,
),
),
),
],
),
),
],
),
);
}

double _calculateProgress(TradeOffer offer) {
final values = [
offer.fromShipped,
offer.fromReceived,
offer.toShipped,
offer.toReceived,
];

final completed =
values.where((value) => value).length;

return completed / 4;
}

Widget _progressLine({
required double value,
required Color color,
}) {
return ClipRRect(
borderRadius: BorderRadius.circular(99),
child: Stack(
children: [
Container(
height: 7,
width: double.infinity,
color: color.withOpacity(0.10),
),
FractionallySizedBox(
widthFactor: value.clamp(0.0, 1.0),
child: Container(
height: 7,
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
color.withOpacity(0.70),
color,
],
),
),
),
),
],
),
);
}

Widget _buildExchangeCards(TradeOffer offer) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: _buildItemCard(
ownerName: _fromDisplayName,
isHighlighted: _isFromUser,
title: offer.fromItemTitle,
sv: _fromSv,
imageUrl: _fromImageUrl,
category: _fromCategory,
condition: _fromCondition,
side: 'Отдаёт',
),
),
Padding(
padding: const EdgeInsets.symmetric(
horizontal: 7,
vertical: 54,
),
child: Container(
width: 42,
height: 42,
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
_accentColor,
const Color(0xFFFF6B00),
],
),
shape: BoxShape.circle,
boxShadow: [
BoxShadow(
color: _accentColor.withOpacity(0.28),
blurRadius: 16,
offset: const Offset(0, 5),
),
],
),
child: const Icon(
Icons.swap_horiz_rounded,
color: Colors.white,
size: 22,
),
),
),
Expanded(
child: _buildItemCard(
ownerName: _toDisplayName,
isHighlighted: _isToUser,
title: offer.toItemTitle,
sv: _toSv,
imageUrl: _toImageUrl,
category: _toCategory,
condition: _toCondition,
side: 'Получает',
),
),
],
);
}

Widget _buildItemCard({
required String ownerName,
required bool isHighlighted,
required String title,
required int sv,
required String side,
String? imageUrl,
String category = '',
String condition = '',
}) {
final highlightColor =
isHighlighted ? _accentColor : _blueColor;

return Container(
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: isHighlighted
? _accentColor.withOpacity(0.35)
    : _borderColor,
width: isHighlighted ? 1.5 : 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
_isDarkMode ? 0.13 : 0.045,
),
blurRadius: 18,
offset: const Offset(0, 7),
),
],
),
child: Column(
children: [
Stack(
children: [
ClipRRect(
borderRadius: const BorderRadius.vertical(
top: Radius.circular(21),
),
child: SizedBox(
height: 138,
width: double.infinity,
child: _buildItemImage(imageUrl),
),
),
Positioned(
left: 9,
top: 9,
child: _imageBadge(
side,
highlightColor,
),
),
Positioned(
right: 9,
top: 9,
child: _imageBadge(
'$sv SV',
_accentColor,
),
),
],
),
Padding(
padding: const EdgeInsets.fromLTRB(
11,
12,
11,
14,
),
child: Column(
children: [
Text(
ownerName,
maxLines: 1,
overflow: TextOverflow.ellipsis,
textAlign: TextAlign.center,
style: TextStyle(
color: highlightColor,
fontSize: 11,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 6),
Text(
title,
maxLines: 2,
overflow: TextOverflow.ellipsis,
textAlign: TextAlign.center,
style: TextStyle(
color: _textColor,
fontSize: 13.5,
fontWeight: FontWeight.w700,
height: 1.15,
),
),
if (category.isNotEmpty ||
condition.isNotEmpty) ...[
const SizedBox(height: 8),
Wrap(
spacing: 4,
runSpacing: 4,
alignment: WrapAlignment.center,
children: [
if (category.isNotEmpty)
_miniTag(
category,
_blueColor,
),
if (condition.isNotEmpty)
_miniTag(
condition,
_greenColor,
),
],
),
],
],
),
),
],
),
);
}

Widget _buildItemImage(String? imageUrl) {
if (imageUrl != null &&
imageUrl.isNotEmpty &&
imageUrl.startsWith('http')) {
return CachedNetworkImage(
imageUrl: imageUrl,
fit: BoxFit.cover,
placeholder: (_, __) => _imagePlaceholder(),
errorWidget: (_, __, ___) => _imageError(),
);
}

return _imageError();
}

Widget _imagePlaceholder() {
return Container(
color: _surfaceSecondaryColor,
child: Center(
child: SizedBox(
width: 22,
height: 22,
child: CircularProgressIndicator(
strokeWidth: 2,
valueColor: AlwaysStoppedAnimation<Color>(
_accentColor,
),
),
),
),
);
}

Widget _imageError() {
return Container(
color: _surfaceSecondaryColor,
child: Center(
child: Icon(
Icons.toys_outlined,
color: _tertiaryTextColor,
size: 38,
),
),
);
}

Widget _imageBadge(
String text,
Color color,
) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 8,
vertical: 5,
),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.50),
borderRadius: BorderRadius.circular(9),
border: Border.all(
color: Colors.white.withOpacity(0.10),
),
),
child: Text(
text,
style: TextStyle(
color: color == _accentColor
? const Color(0xFFFFC46B)
    : Colors.white,
fontSize: 9.5,
fontWeight: FontWeight.w700,
),
),
);
}

Widget _miniTag(
String text,
Color color,
) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 7,
vertical: 4,
),
decoration: BoxDecoration(
color: color.withOpacity(0.10),
borderRadius: BorderRadius.circular(7),
),
child: Text(
text,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: color,
fontSize: 9,
fontWeight: FontWeight.w700,
),
),
);
}

Widget _smallBadge({
required String text,
required Color color,
}) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 9,
vertical: 6,
),
decoration: BoxDecoration(
color: color.withOpacity(0.09),
borderRadius: BorderRadius.circular(10),
),
child: Text(
text,
style: TextStyle(
color: color,
fontSize: 10,
fontWeight: FontWeight.w700,
letterSpacing: 0.3,
),
),
);
}

Widget _buildSVDifferenceCard(TradeOffer offer) {
final hasDifference = offer.svDifference != 0;

final color = hasDifference
? const Color(0xFFFF9F0A)
    : _greenColor;

return Container(
width: double.infinity,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: color.withOpacity(0.20),
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
_isDarkMode ? 0.10 : 0.035,
),
blurRadius: 16,
offset: const Offset(0, 6),
),
],
),
child: Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: color.withOpacity(0.11),
borderRadius: BorderRadius.circular(14),
),
child: Icon(
hasDifference
? Icons.account_balance_wallet_outlined
    : Icons.balance_rounded,
color: color,
size: 23,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
hasDifference
? 'Доплата'
    : 'Стоимость обмена',
style: TextStyle(
color: _subTextColor,
fontSize: 11,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 2),
Text(
hasDifference
? '${offer.svDifference > 0 ? '+' : ''}${offer.svDifference} SV'
    : 'Равный обмен',
style: TextStyle(
color: _textColor,
fontSize: 16,
fontWeight: FontWeight.w700,
),
),
],
),
),
if (hasDifference)
_smallBadge(
text:
'${offer.svDifference.abs()} SV',
color: color,
)
else
_smallBadge(
text: '1 : 1',
color: color,
),
],
),
);
}

Widget _buildSectionTitle(
String title,
IconData icon,
) {
return Row(
children: [
Container(
width: 34,
height: 34,
decoration: BoxDecoration(
color: _accentColor.withOpacity(0.10),
borderRadius: BorderRadius.circular(11),
),
child: Icon(
icon,
size: 17,
color: _accentColor,
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
title,
style: TextStyle(
color: _textColor,
fontSize: 18,
fontWeight: FontWeight.w700,
letterSpacing: -0.35,
),
),
),
],
);
}

Widget _card({
required Widget child,
EdgeInsetsGeometry padding =
const EdgeInsets.all(16),
}) {
return Container(
width: double.infinity,
padding: padding,
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: _borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(
_isDarkMode ? 0.11 : 0.035,
),
blurRadius: 18,
offset: const Offset(0, 7),
),
],
),
child: child,
);
}

Widget _buildDetailCard(TradeOffer offer) {
final shortId = offer.id.length > 8
? offer.id.substring(0, 8)
    : offer.id;

return _card(
padding: const EdgeInsets.all(18),
child: Column(
children: [
Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
horizontal: 13,
vertical: 11,
),
decoration: BoxDecoration(
color: _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(14),
),
child: Row(
children: [
Icon(
Icons.tag_rounded,
size: 17,
color: _tertiaryTextColor,
),
const SizedBox(width: 7),
Expanded(
child: Text(
'Сделка №${shortId.toUpperCase()}',
style: TextStyle(
color: _subTextColor,
fontSize: 12,
fontWeight: FontWeight.w600,
),
),
),
],
),
),
const SizedBox(height: 18),
_buildDetailSection(
'Участники',
[
_buildParticipantRow(
_fromDisplayName,
offer.fromItemTitle,
_fromSv,
isCurrentUser: _isFromUser,
imageUrl: _fromImageUrl,
),
const SizedBox(height: 8),
_buildExchangeDivider(),
const SizedBox(height: 8),
_buildParticipantRow(
_toDisplayName,
offer.toItemTitle,
_toSv,
isCurrentUser: _isToUser,
imageUrl: _toImageUrl,
),
],
),
const SizedBox(height: 20),
_buildDetailSection(
'Стоимость',
[
_buildPriceRow(
offer.fromItemTitle,
_fromSv,
_fromDisplayName,
),
const SizedBox(height: 7),
_buildPriceRow(
offer.toItemTitle,
_toSv,
_toDisplayName,
),
],
),
if (offer.svDifference != 0) ...[
const SizedBox(height: 18),
_buildDetailSection(
'Доплата',
[
Container(
padding: const EdgeInsets.all(13),
decoration: BoxDecoration(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.08),
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.18),
),
),
child: Row(
children: [
Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.11),
borderRadius:
BorderRadius.circular(11),
),
child: const Icon(
Icons.payments_outlined,
color: Color(0xFFFF9F0A),
size: 18,
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
'$_payerName доплачивает ${offer.svDifference.abs()} SV',
style: TextStyle(
color: _textColor,
fontSize: 13,
fontWeight: FontWeight.w600,
),
),
),
],
),
),
],
),
],
if (offer.deliveryMethod.isNotEmpty) ...[
const SizedBox(height: 18),
_buildDetailSection(
'Выбранная передача',
[
_buildInfoRow(
Icons.local_shipping_outlined,
_methodName(offer.deliveryMethod),
),
],
),
],
],
),
);
}

Widget _buildExchangeDivider() {
return Row(
children: [
Expanded(
child: Container(
height: 1,
color: _borderColor,
),
),
Padding(
padding: const EdgeInsets.symmetric(
horizontal: 10,
),
child: Container(
width: 28,
height: 28,
decoration: BoxDecoration(
color: _accentColor.withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
Icons.swap_vert_rounded,
size: 16,
color: _accentColor,
),
),
),
Expanded(
child: Container(
height: 1,
color: _borderColor,
),
),
],
);
}

Widget _buildDetailSection(
String title,
List<Widget> children,
) {
return Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
color: _subTextColor,
fontSize: 11,
fontWeight: FontWeight.w700,
letterSpacing: 0.2,
),
),
const SizedBox(height: 9),
...children,
],
);
}

Widget _buildParticipantRow(
String name,
String itemTitle,
int sv, {
required bool isCurrentUser,
String? imageUrl,
}) {
final color =
isCurrentUser ? _accentColor : _blueColor;

return Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: isCurrentUser
? _accentColor.withOpacity(0.06)
    : _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(15),
border: Border.all(
color: isCurrentUser
? _accentColor.withOpacity(0.17)
    : _borderColor,
),
),
child: Row(
children: [
_participantAvatar(
imageUrl,
color,
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Flexible(
child: Text(
name,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: _textColor,
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
),
if (isCurrentUser) ...[
const SizedBox(width: 5),
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 5,
vertical: 2,
),
decoration: BoxDecoration(
color:
_accentColor.withOpacity(
0.12,
),
borderRadius:
BorderRadius.circular(5),
),
child: Text(
'ВЫ',
style: TextStyle(
color: _accentColor,
fontSize: 8,
fontWeight: FontWeight.w800,
),
),
),
],
],
),
const SizedBox(height: 3),
Text(
itemTitle,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: _subTextColor,
fontSize: 11.5,
),
),
],
),
),
const SizedBox(width: 8),
Text(
'$sv SV',
style: TextStyle(
color: color,
fontSize: 12,
fontWeight: FontWeight.w800,
),
),
],
),
);
}

Widget _participantAvatar(
String? imageUrl,
Color color,
) {
if (imageUrl != null &&
imageUrl.isNotEmpty &&
imageUrl.startsWith('http')) {
return ClipRRect(
borderRadius: BorderRadius.circular(12),
child: SizedBox(
width: 38,
height: 38,
child: CachedNetworkImage(
imageUrl: imageUrl,
fit: BoxFit.cover,
errorWidget: (_, __, ___) =>
_avatarFallback(color),
),
),
);
}

return _avatarFallback(color);
}

Widget _avatarFallback(Color color) {
return Container(
width: 38,
height: 38,
decoration: BoxDecoration(
color: color.withOpacity(0.10),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
Icons.person_outline_rounded,
color: color,
size: 20,
),
);
}

Widget _buildPriceRow(
String itemTitle,
int sv,
String ownerName,
) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 11,
),
decoration: BoxDecoration(
color: _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(13),
),
child: Row(
children: [
Container(
width: 30,
height: 30,
decoration: BoxDecoration(
color: _accentColor.withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
Icons.auto_awesome,
size: 14,
color: _accentColor,
),
),
const SizedBox(width: 9),
Expanded(
child: Text(
itemTitle,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: _subTextColor,
fontSize: 12,
),
),
),
const SizedBox(width: 6),
Text(
ownerName,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: _tertiaryTextColor,
fontSize: 9.5,
),
),
const SizedBox(width: 7),
Text(
'$sv SV',
style: TextStyle(
color: _textColor,
fontSize: 12.5,
fontWeight: FontWeight.w700,
),
),
],
),
);
}

Widget _buildInfoRow(
IconData icon,
String value,
) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(13),
),
child: Row(
children: [
Container(
width: 32,
height: 32,
decoration: BoxDecoration(
color: _accentColor.withOpacity(0.10),
borderRadius: BorderRadius.circular(10),
),
child: Icon(
icon,
color: _accentColor,
size: 17,
),
),
const SizedBox(width: 9),
Text(
value,
style: TextStyle(
color: _textColor,
fontSize: 13,
fontWeight: FontWeight.w600,
),
),
],
),
);
}

Widget _buildDeliveryMethods(
TradeOffer offer,
TradesProvider provider,
) {
final currentMethod = _isFromUser
? offer.fromDeliveryMethod
    : offer.toDeliveryMethod;

return Row(
children: [
Expanded(
child: _deliveryOptionCard(
icon: Icons.people_outline_rounded,
title: 'Встреча',
subtitle: 'Лично',
value: 'meetup',
isSelected: currentMethod == 'meetup',
onTap: currentMethod == 'meetup'
? null
    : () => provider.updateDeliveryMethod(
offer.id,
'meetup',
),
),
),
const SizedBox(width: 10),
Expanded(
child: _deliveryOptionCard(
icon: Icons.local_shipping_outlined,
title: 'Доставка',
subtitle: 'Почта / служба',
value: 'delivery',
isSelected: currentMethod == 'delivery',
onTap: currentMethod == 'delivery'
? null
    : () => provider.updateDeliveryMethod(
offer.id,
'delivery',
),
),
),
],
);
}

Widget _deliveryOptionCard({
required IconData icon,
required String title,
required String subtitle,
required String value,
required bool isSelected,
VoidCallback? onTap,
}) {
return AnimatedContainer(
duration: const Duration(milliseconds: 220),
curve: Curves.easeOut,
decoration: BoxDecoration(
color: isSelected
? _accentColor.withOpacity(0.07)
    : _surfaceColor,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: isSelected
? _accentColor.withOpacity(0.45)
    : _borderColor,
width: isSelected ? 1.5 : 1,
),
),
child: Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(18),
onTap: onTap,
child: Padding(
padding: const EdgeInsets.all(14),
child: Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: isSelected
? _accentColor.withOpacity(0.12)
    : _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(13),
),
child: Icon(
icon,
size: 21,
color: isSelected
? _accentColor
    : _subTextColor,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
color: isSelected
? _textColor
    : _textColor,
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 2),
Text(
subtitle,
style: TextStyle(
color: _subTextColor,
fontSize: 10.5,
),
),
],
),
),
if (isSelected)
Container(
width: 23,
height: 23,
decoration: BoxDecoration(
color: _accentColor,
shape: BoxShape.circle,
),
child: const Icon(
Icons.check,
color: Colors.white,
size: 14,
),
),
],
),
),
),
),
);
}

Widget _buildDeliveryChoices(TradeOffer offer) {
return Row(
children: [
Expanded(
child: _choiceChip(
_fromDisplayName,
offer.fromDeliveryMethod,
),
),
const SizedBox(width: 8),
Expanded(
child: _choiceChip(
_toDisplayName,
offer.toDeliveryMethod,
),
),
],
);
}

Widget _choiceChip(
String who,
String method,
) {
final chosen = method.isNotEmpty;
final color =
chosen ? _greenColor : _tertiaryTextColor;

return Container(
padding: const EdgeInsets.symmetric(
horizontal: 11,
vertical: 10,
),
decoration: BoxDecoration(
color: chosen
? _greenColor.withOpacity(0.06)
    : _surfaceColor,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: chosen
? _greenColor.withOpacity(0.20)
    : _borderColor,
),
),
child: Row(
children: [
Icon(
chosen
? Icons.check_circle_outline_rounded
    : Icons.schedule_rounded,
size: 17,
color: color,
),
const SizedBox(width: 7),
Expanded(
child: Text(
chosen
? '$who · ${_methodName(method)}'
    : '$who · ожидание',
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: chosen
? _textColor
    : _subTextColor,
fontSize: 10.5,
fontWeight: FontWeight.w600,
),
),
),
],
),
);
}

Widget _buildMatchIndicator(bool methodsMatch) {
final color =
methodsMatch ? _greenColor : _redColor;

return Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
horizontal: 13,
vertical: 12,
),
decoration: BoxDecoration(
color: color.withOpacity(0.07),
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: color.withOpacity(0.18),
),
),
child: Row(
children: [
Icon(
methodsMatch
? Icons.check_circle_rounded
    : Icons.warning_amber_rounded,
color: color,
size: 19,
),
const SizedBox(width: 8),
Expanded(
child: Text(
methodsMatch
? 'Способы передачи совпадают'
    : 'Способы передачи различаются',
style: TextStyle(
color: color,
fontSize: 12,
fontWeight: FontWeight.w700,
),
),
),
],
),
);
}

Widget _buildMismatchWarning() {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.07),
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.20),
),
),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.12),
borderRadius: BorderRadius.circular(12),
),
child: const Icon(
Icons.sync_problem_rounded,
color: Color(0xFFFF9F0A),
size: 21,
),
),
const SizedBox(width: 11),
Expanded(
child: Text(
'Для подтверждения выберите одинаковый способ передачи.',
style: TextStyle(
color: _textColor,
fontSize: 12,
fontWeight: FontWeight.w600,
height: 1.3,
),
),
),
],
),
);
}

Widget _buildConfirmationPanel(
TradeOffer offer,
TradesProvider provider,
) {
final fromShipped =
offer.fromShipped ||
_pendingSteps.contains('from_shipped');

final fromReceived =
offer.fromReceived ||
_pendingSteps.contains('from_received');

final toShipped =
offer.toShipped ||
_pendingSteps.contains('to_shipped');

final toReceived =
offer.toReceived ||
_pendingSteps.contains('to_received');

final myShipped =
_isFromUser ? fromShipped : toShipped;

final myReceived =
_isFromUser ? fromReceived : toReceived;

final partnerShipped =
_isFromUser ? toShipped : fromShipped;

final partnerReceived =
_isFromUser ? toReceived : fromReceived;

final myDone =
myShipped && myReceived;

final partnerDone =
partnerShipped && partnerReceived;

final allDone =
myDone && partnerDone;

final completed = [
fromShipped,
fromReceived,
toShipped,
toReceived,
].where((value) => value).length;

Future<void> handleConfirm(String step) async {
final isShipped = step.contains('shipped');
final action =
isShipped ? 'отправили' : 'получили';

final confirmed = await showDialog<bool>(
context: context,
builder: (dialogContext) {
return AlertDialog(
backgroundColor: _surfaceColor,
surfaceTintColor: Colors.transparent,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(24),
),
contentPadding: const EdgeInsets.fromLTRB(
24,
22,
24,
10,
),
title: Column(
children: [
Container(
width: 54,
height: 54,
decoration: BoxDecoration(
color: (isShipped
? _greenColor
    : _blueColor)
    .withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
isShipped
? Icons.local_shipping_outlined
    : Icons.inventory_2_outlined,
color: isShipped
? _greenColor
    : _blueColor,
size: 28,
),
),
const SizedBox(height: 12),
Text(
isShipped
? 'Подтвердить передачу?'
    : 'Подтвердить получение?',
textAlign: TextAlign.center,
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight: FontWeight.w700,
),
),
],
),
content: Text(
'Вы точно $action вещь?',
textAlign: TextAlign.center,
style: TextStyle(
color: _subTextColor,
fontSize: 14,
),
),
actionsPadding: const EdgeInsets.fromLTRB(
14,
8,
14,
14,
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(dialogContext, false),
child: Text(
'Отмена',
style: TextStyle(
color: _subTextColor,
fontWeight: FontWeight.w600,
),
),
),
TextButton(
onPressed: () =>
Navigator.pop(dialogContext, true),
child: Text(
'Подтвердить',
style: TextStyle(
color: _accentColor,
fontWeight: FontWeight.w700,
),
),
),
],
);
},
);

if (confirmed != true) {
return;
}

setState(() {
_pendingSteps.add(step);
});

try {
await provider.confirmStep(
offer.id,
step,
);

final updatedOffer = context
    .read<TradesProvider>()
    .offers
    .firstWhere(
(item) => item.id == offer.id,
orElse: () => offer,
);

final allDoneNow =
updatedOffer.fromShipped &&
updatedOffer.fromReceived &&
updatedOffer.toShipped &&
updatedOffer.toReceived;

if (allDoneNow) {
final opponentId = _isFromUser
? widget.offer.toUserId
    : widget.offer.fromUserId;

NotificationService.sendNotification(
targetUserId: opponentId,
type: 'trade_completed',
data: {
'trade_id': widget.offer.id,
'user_name':
_currentUserName ?? 'Пользователь',
},
);
}
} finally {
if (mounted) {
setState(() {
_pendingSteps.remove(step);
});
}
}
}

return _card(
padding: const EdgeInsets.all(17),
child: Column(
children: [
Row(
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: allDone
? _greenColor.withOpacity(0.11)
    : _accentColor.withOpacity(0.11),
borderRadius: BorderRadius.circular(13),
),
child: Icon(
allDone
? Icons.celebration_rounded
    : Icons.route_rounded,
color: allDone
? _greenColor
    : _accentColor,
size: 21,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
allDone
? 'Обмен завершён'
    : 'Прогресс обмена',
style: TextStyle(
color: _textColor,
fontSize: 15,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 3),
Text(
'$completed из 4 шагов',
style: TextStyle(
color: _subTextColor,
fontSize: 11,
),
),
],
),
),
Text(
'$completed/4',
style: TextStyle(
color:
allDone ? _greenColor : _accentColor,
fontSize: 14,
fontWeight: FontWeight.w800,
),
),
],
),
const SizedBox(height: 14),
_progressLine(
value: completed / 4,
color:
allDone ? _greenColor : _accentColor,
),
const SizedBox(height: 18),
_buildUserConfirmationBlock(
label: _isFromUser
? 'Вы'
    : _fromDisplayName,
shipped: myShipped,
received: myReceived,
isMe: true,
onTapShipped: !myShipped
? () => handleConfirm(
_isFromUser
? 'from_shipped'
    : 'to_shipped',
)
    : null,
onTapReceived: !myReceived
? () => handleConfirm(
_isFromUser
? 'from_received'
    : 'to_received',
)
    : null,
),
const SizedBox(height: 10),
_buildUserConfirmationBlock(
label: _isFromUser
? _toDisplayName
    : _fromDisplayName,
shipped: partnerShipped,
received: partnerReceived,
isMe: false,
onTapShipped: null,
onTapReceived: null,
),
],
),
);
}

Widget _buildUserConfirmationBlock({
required String label,
required bool shipped,
required bool received,
required bool isMe,
VoidCallback? onTapShipped,
VoidCallback? onTapReceived,
}) {
final allDone =
shipped && received;

final color = allDone
? _greenColor
    : isMe
? _accentColor
    : _subTextColor;

return Container(
padding: const EdgeInsets.all(13),
decoration: BoxDecoration(
color: allDone
? _greenColor.withOpacity(0.06)
    : isMe
? _accentColor.withOpacity(0.045)
    : _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: allDone
? _greenColor.withOpacity(0.20)
    : isMe
? _accentColor.withOpacity(0.16)
    : _borderColor,
),
),
child: Column(
children: [
Row(
children: [
Container(
width: 34,
height: 34,
decoration: BoxDecoration(
color: color.withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
isMe
? Icons.person_outline_rounded
    : Icons.person_2_outlined,
color: color,
size: 18,
),
),
const SizedBox(width: 9),
Expanded(
child: Text(
label,
style: TextStyle(
color: _textColor,
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
),
if (allDone)
_smallBadge(
text: 'ГОТОВО',
color: _greenColor,
),
],
),
const SizedBox(height: 10),
Row(
children: [
Expanded(
child: _stepBox(
icon: Icons.local_shipping_outlined,
label: 'Передал',
isDone: shipped,
isClickable:
onTapShipped != null,
color: _greenColor,
onTap: onTapShipped,
),
),
const SizedBox(width: 7),
Expanded(
child: _stepBox(
icon: Icons.inventory_2_outlined,
label: 'Получил',
isDone: received,
isClickable:
onTapReceived != null,
color: _blueColor,
onTap: onTapReceived,
),
),
],
),
],
),
);
}

Widget _stepBox({
required IconData icon,
required String label,
required bool isDone,
required bool isClickable,
required Color color,
VoidCallback? onTap,
}) {
return GestureDetector(
onTap: onTap,
child: AnimatedContainer(
duration: const Duration(milliseconds: 180),
padding: const EdgeInsets.symmetric(
horizontal: 9,
vertical: 10,
),
decoration: BoxDecoration(
color: isDone
? color.withOpacity(0.09)
    : isClickable
? color.withOpacity(0.045)
    : _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(13),
border: Border.all(
color: isDone
? color.withOpacity(0.22)
    : isClickable
? color.withOpacity(0.25)
    : _borderColor,
),
),
child: Column(
children: [
Icon(
isDone
? Icons.check_circle_rounded
    : isClickable
? icon
    : Icons.schedule_rounded,
color: isDone
? color
    : isClickable
? color
    : _tertiaryTextColor,
size: 23,
),
const SizedBox(height: 4),
Text(
label,
style: TextStyle(
color: isDone || isClickable
? color
    : _subTextColor,
fontSize: 10.5,
fontWeight: FontWeight.w700,
),
),
if (isClickable && !isDone) ...[
const SizedBox(height: 2),
Text(
'Нажмите',
style: TextStyle(
color: color.withOpacity(0.75),
fontSize: 8.5,
),
),
],
],
),
),
);
}

void _showCancelDialog(
TradeOffer offer,
TradesProvider provider,
) {
String selectedReason = '';

showDialog(
context: context,
builder: (dialogContext) {
return StatefulBuilder(
builder: (
innerContext,
setDialogState,
) {
return AlertDialog(
backgroundColor: _surfaceColor,
surfaceTintColor: Colors.transparent,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(24),
),
title: Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color:
_redColor.withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
Icons.warning_amber_rounded,
color: _redColor,
size: 24,
),
),
const SizedBox(width: 11),
Expanded(
child: Text(
'Отменить обмен?',
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight: FontWeight.w700,
),
),
),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Align(
alignment: Alignment.centerLeft,
child: Text(
'Выберите причину',
style: TextStyle(
color: _subTextColor,
fontSize: 13,
),
),
),
const SizedBox(height: 12),
_cancelReasonOption(
title:
'Подозрение на мошенника',
icon: Icons.security_outlined,
isSelected: selectedReason ==
'Подозрение на мошенника',
onTap: () {
setDialogState(
() => selectedReason =
'Подозрение на мошенника',
);
},
),
const SizedBox(height: 7),
_cancelReasonOption(
title:
'Скандальный пользователь',
icon: Icons.report_outlined,
isSelected: selectedReason ==
'Скандальный пользователь',
onTap: () {
setDialogState(
() => selectedReason =
'Скандальный пользователь',
);
},
),
const SizedBox(height: 7),
_cancelReasonOption(
title:
'Товар не соответствует',
icon: Icons.broken_image_outlined,
isSelected: selectedReason ==
'Товар не соответствует',
onTap: () {
setDialogState(
() => selectedReason =
'Товар не соответствует',
);
},
),
const SizedBox(height: 7),
_cancelReasonOption(
title: 'Передумал',
icon: Icons.psychology_outlined,
isSelected:
selectedReason ==
'Передумал',
onTap: () {
setDialogState(
() => selectedReason =
'Передумал',
);
},
),
],
),
),
actionsPadding: const EdgeInsets.fromLTRB(
14,
0,
14,
14,
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(dialogContext),
child: Text(
'Назад',
style: TextStyle(
color: _subTextColor,
fontWeight: FontWeight.w600,
),
),
),
TextButton(
onPressed: selectedReason.isEmpty
? null
    : () {
Navigator.pop(
dialogContext,
);

provider
    .cancelOffer(
offer.id,
reason: selectedReason,
)
    .then((_) {
final opponentId =
_isFromUser
? widget
    .offer.toUserId
    : widget
    .offer.fromUserId;

NotificationService
    .sendNotification(
targetUserId:
opponentId,
type:
'trade_declined',
data: {
'trade_id':
widget.offer.id,
'user_name':
_currentUserName ??
'Пользователь',
},
);
});
},
child: Text(
'Отменить',
style: TextStyle(
color: selectedReason.isEmpty
? _tertiaryTextColor
    : _redColor,
fontWeight: FontWeight.w700,
),
),
),
],
);
},
);
},
);
}

Widget _cancelReasonOption({
required String title,
required IconData icon,
required bool isSelected,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap: onTap,
child: AnimatedContainer(
duration: const Duration(milliseconds: 180),
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 11,
),
decoration: BoxDecoration(
color: isSelected
? _redColor.withOpacity(0.07)
    : _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(13),
border: Border.all(
color: isSelected
? _redColor.withOpacity(0.35)
    : _borderColor,
width: isSelected ? 1.4 : 1,
),
),
child: Row(
children: [
Icon(
icon,
size: 19,
color: isSelected
? _redColor
    : _subTextColor,
),
const SizedBox(width: 9),
Expanded(
child: Text(
title,
style: TextStyle(
color: isSelected
? _redColor
    : _textColor,
fontSize: 12.5,
fontWeight: isSelected
? FontWeight.w700
    : FontWeight.w500,
),
),
),
if (isSelected)
Icon(
Icons.check_circle_rounded,
size: 19,
color: _redColor,
),
],
),
),
);
}

Widget _buildCancelButton(
TradeOffer offer,
TradesProvider provider,
) {
return SizedBox(
width: double.infinity,
child: TextButton.icon(
onPressed: () =>
_showCancelDialog(
offer,
provider,
),
icon: Icon(
Icons.close_rounded,
color: _redColor,
size: 19,
),
label: Text(
'Отменить сделку',
style: TextStyle(
color: _redColor,
fontSize: 13,
fontWeight: FontWeight.w700,
),
),
style: TextButton.styleFrom(
backgroundColor:
_redColor.withOpacity(0.055),
padding: const EdgeInsets.symmetric(
vertical: 14,
),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(15),
side: BorderSide(
color: _redColor.withOpacity(0.13),
),
),
),
),
);
}

Widget _buildCompletedResultCard(
TradeOffer offer,
) {
return _card(
padding: const EdgeInsets.all(20),
child: Column(
children: [
Container(
width: 64,
height: 64,
decoration: BoxDecoration(
color: _greenColor.withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
Icons.verified_rounded,
color: _greenColor,
size: 35,
),
),
const SizedBox(height: 12),
Text(
'Обмен успешно завершён',
textAlign: TextAlign.center,
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 5),
Text(
'Обе стороны подтвердили получение вещей',
textAlign: TextAlign.center,
style: TextStyle(
color: _subTextColor,
fontSize: 12,
height: 1.3,
),
),
const SizedBox(height: 18),
_resultSection(
'Кто что получил',
[
_buildResultRow(
_fromDisplayName,
'получил(а)',
offer.toItemTitle,
_toSv,
isCurrentUser: _isFromUser,
),
const SizedBox(height: 7),
_buildResultRow(
_toDisplayName,
'получил(а)',
offer.fromItemTitle,
_fromSv,
isCurrentUser: _isToUser,
),
],
),
if (offer.svDifference != 0) ...[
const SizedBox(height: 16),
Container(
width: double.infinity,
padding: const EdgeInsets.all(13),
decoration: BoxDecoration(
color: const Color(0xFFFF9F0A)
    .withOpacity(0.07),
borderRadius:
BorderRadius.circular(14),
),
child: Row(
children: [
const Icon(
Icons.check_circle_outline,
color: Color(0xFFFF9F0A),
size: 20,
),
const SizedBox(width: 9),
Expanded(
child: Text(
'Доплата ${offer.svDifference.abs()} SV выполнена',
style: TextStyle(
color: _textColor,
fontSize: 12.5,
fontWeight: FontWeight.w600,
),
),
),
],
),
),
],
if (offer.deliveryMethod.isNotEmpty) ...[
const SizedBox(height: 12),
_buildInfoRow(
Icons.local_shipping_outlined,
_methodName(
offer.deliveryMethod,
),
),
],
],
),
);
}

Widget _buildCancelledResultCard(
TradeOffer offer,
) {
final reasonIcon =
_getCancelReasonIcon(
offer.cancelReason,
);

final reasonColor =
_getCancelReasonColor(
offer.cancelReason,
);

return _card(
padding: const EdgeInsets.all(20),
child: Column(
children: [
Container(
width: 62,
height: 62,
decoration: BoxDecoration(
color: _redColor.withOpacity(0.09),
shape: BoxShape.circle,
),
child: Icon(
Icons.close_rounded,
color: _redColor,
size: 34,
),
),
const SizedBox(height: 11),
Text(
'Сделка отменена',
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 5),
Text(
'Вещи остаются у своих владельцев',
textAlign: TextAlign.center,
style: TextStyle(
color: _subTextColor,
fontSize: 12,
),
),
if (offer.cancelReason.isNotEmpty) ...[
const SizedBox(height: 16),
Container(
width: double.infinity,
padding: const EdgeInsets.all(13),
decoration: BoxDecoration(
color: reasonColor.withOpacity(0.07),
borderRadius:
BorderRadius.circular(14),
border: Border.all(
color: reasonColor.withOpacity(0.18),
),
),
child: Row(
children: [
Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color:
reasonColor.withOpacity(
0.10,
),
shape: BoxShape.circle,
),
child: Icon(
reasonIcon,
color: reasonColor,
size: 18,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Причина',
style: TextStyle(
color: _subTextColor,
fontSize: 10,
),
),
const SizedBox(height: 3),
Text(
offer.cancelReason,
style: TextStyle(
color: reasonColor,
fontSize: 12.5,
fontWeight:
FontWeight.w700,
),
),
],
),
),
],
),
),
],
],
),
);
}

Widget _resultSection(
String title,
List<Widget> children,
) {
return Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
style: TextStyle(
color: _subTextColor,
fontSize: 11,
fontWeight: FontWeight.w700,
),
),
const SizedBox(height: 9),
...children,
],
);
}

Widget _buildResultRow(
String name,
String action,
String itemTitle,
int sv, {
required bool isCurrentUser,
}) {
final color =
isCurrentUser ? _accentColor : _blueColor;

return Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: isCurrentUser
? _accentColor.withOpacity(0.05)
    : _surfaceSecondaryColor,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: isCurrentUser
? _accentColor.withOpacity(0.14)
    : _borderColor,
),
),
child: Row(
children: [
Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: color.withOpacity(0.10),
shape: BoxShape.circle,
),
child: Icon(
Icons.person_outline_rounded,
color: color,
size: 18,
),
),
const SizedBox(width: 10),
Expanded(
child: RichText(
maxLines: 2,
overflow: TextOverflow.ellipsis,
text: TextSpan(
style: TextStyle(
color: _subTextColor,
fontSize: 11.5,
height: 1.25,
),
children: [
TextSpan(
text: name,
style: TextStyle(
color: _textColor,
fontWeight:
FontWeight.w700,
),
),
TextSpan(
text: ' $action ',
),
TextSpan(
text: itemTitle,
style: TextStyle(
color: _textColor,
fontWeight:
FontWeight.w600,
),
),
],
),
),
),
const SizedBox(width: 7),
Text(
'$sv SV',
style: TextStyle(
color: color,
fontSize: 11,
fontWeight: FontWeight.w800,
),
),
],
),
);
}

Widget _buildChatSection(TradeOffer offer) {
  return Container(
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: _borderColor,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(
            _isDarkMode ? 0.10 : 0.035,
          ),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 420,
        child: ChatWidget(
          offerId: offer.id,
        ),
      ),
    ),
  );
}

IconData _getCancelReasonIcon(
String reason,
) {
switch (reason) {
case 'Подозрение на мошенника':
return Icons.security_outlined;
case 'Скандальный пользователь':
return Icons.report_outlined;
case 'Товар не соответствует':
return Icons.broken_image_outlined;
case 'Передумал':
return Icons.psychology_outlined;
default:
return Icons.info_outline_rounded;
}
}

Color _getCancelReasonColor(
String reason,
) {
switch (reason) {
case 'Подозрение на мошенника':
return _redColor;
case 'Скандальный пользователь':
return const Color(0xFFFF9F0A);
case 'Товар не соответствует':
return const Color(0xFFFFCC00);
case 'Передумал':
return _subTextColor;
default:
return _subTextColor;
}
}

IconData _getStatusIcon(String status) {
switch (status) {
case 'accepted':
return Icons.check_circle_outline_rounded;
case 'shipped':
return Icons.local_shipping_outlined;
case 'completed':
return Icons.verified_rounded;
case 'rejected':
return Icons.cancel_outlined;
case 'cancelled':
return Icons.cancel_outlined;
default:
return Icons.schedule_rounded;
}
}

String _getStatusText(String status) {
switch (status) {
case 'accepted':
return 'Принято';
case 'shipped':
return 'В процессе';
case 'completed':
return 'Завершено';
case 'rejected':
return 'Отклонено';
case 'cancelled':
return 'Отменено';
default:
return 'Ожидает ответа';
}
}

String _getStatusDescription(
String status,
) {
switch (status) {
case 'accepted':
return 'Выберите способ передачи';
case 'shipped':
return 'Ожидается подтверждение';
case 'completed':
return 'Обе стороны подтвердили обмен';
case 'rejected':
return 'Предложение было отклонено';
case 'cancelled':
return 'Сделка больше не активна';
default:
return 'Ожидается решение второй стороны';
}
}

Color _getStatusColor(String status) {
switch (status) {
case 'accepted':
return _blueColor;
case 'shipped':
return _purpleColor;
case 'completed':
return _greenColor;
case 'rejected':
return _redColor;
case 'cancelled':
return _redColor;
default:
return _accentColor;
}
}

String _methodName(String method) {
switch (method) {
case 'meetup':
return 'Личная встреча';
case 'delivery':
return 'Доставка';
default:
return method;
}
}
}

class _ChatPlaceholder extends StatelessWidget {
const _ChatPlaceholder();

@override
Widget build(BuildContext context) {
return const SizedBox.shrink();
}
}

