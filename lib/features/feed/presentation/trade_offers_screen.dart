// features/feed/presentation/trade_offers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/trade_offer.dart';
import '../../../core/trades_provider.dart';
import '../../../services/notification_service.dart';
import 'trade_discussion_screen.dart';

class TradeOffersScreen extends StatefulWidget {
const TradeOffersScreen({super.key});

@override
State<TradeOffersScreen> createState() =>
_TradeOffersScreenState();
}

class _TradeOffersScreenState
extends State<TradeOffersScreen> {
String? _currentUserId;
String? _currentUserName;

@override
void initState() {
super.initState();
_loadUserId();
}

Future<void> _loadUserId() async {
final prefs =
await SharedPreferences.getInstance();

if (!mounted) return;

setState(() {
_currentUserId =
prefs.getString('user_id');

_currentUserName =
prefs.getString('user_name') ??
'Пользователь';
});
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

Color get _purpleColor =>
const Color(0xFFBF5AF2);

@override
Widget build(BuildContext context) {
final provider =
context.watch<TradesProvider>();

final offers = provider.offers;

return Scaffold(
backgroundColor: _backgroundColor,
body: SafeArea(
bottom: false,
child: offers.isEmpty
? _buildEmptyState()
    : RefreshIndicator(
onRefresh: () => context
    .read<TradesProvider>()
    .loadOffers(),
color: _accentColor,
backgroundColor:
_surfaceColor,
child: CustomScrollView(
physics:
const BouncingScrollPhysics(),
slivers: [
SliverToBoxAdapter(
child: _buildHeader(
offers,
),
),
SliverPadding(
padding:
const EdgeInsets.fromLTRB(
16,
4,
16,
110,
),
sliver: SliverList(
delegate:
SliverChildBuilderDelegate(
(context, index) {
return _buildOfferCard(
offers[index],
provider,
);
},
childCount:
offers.length,
),
),
),
],
),
),
),
);
}

Widget _buildHeader(
List<TradeOffer> offers,
) {
final pendingCount =
offers.where(
(offer) => offer.status == 'pending',
).length;

final activeCount =
offers.where(
(offer) =>
offer.status == 'accepted' ||
offer.status == 'shipped',
).length;

return Padding(
padding: const EdgeInsets.fromLTRB(
18,
10,
18,
14,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'KIDLOOP',
style: TextStyle(
color: _accentColor,
fontSize: 11,
fontWeight:
FontWeight.w800,
letterSpacing: 1.8,
),
),
const SizedBox(height: 3),
Text(
'Предложения',
style: TextStyle(
color: _textColor,
fontSize: 30,
fontWeight:
FontWeight.w800,
letterSpacing: -1,
height: 1.05,
),
),
],
),
),
Container(
width: 46,
height: 46,
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color: _borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(
_isDarkMode
? 0.14
    : 0.045,
),
blurRadius: 12,
offset:
const Offset(0, 5),
),
],
),
alignment: Alignment.center,
child: Stack(
clipBehavior:
Clip.none,
children: [
Icon(
Icons
    .swap_horizontal_circle_outlined,
color: _textColor,
size: 22,
),
if (pendingCount > 0)
Positioned(
right: -8,
top: -8,
child: Container(
constraints:
const BoxConstraints(
minWidth: 18,
minHeight: 18,
),
padding:
const EdgeInsets
    .symmetric(
horizontal: 4,
),
decoration:
BoxDecoration(
color: _accentColor,
shape:
BoxShape.circle,
border:
Border.all(
color:
_backgroundColor,
width: 2,
),
),
alignment:
Alignment.center,
child: Text(
'$pendingCount',
style:
const TextStyle(
color:
Colors.white,
fontSize: 8,
fontWeight:
FontWeight.w800,
),
),
),
),
],
),
),
],
),
const SizedBox(height: 14),
Row(
children: [
Expanded(
child: _summaryCard(
icon:
Icons.mark_email_unread_outlined,
title: 'Новые',
value:
'$pendingCount',
color:
_accentColor,
),
),
const SizedBox(width: 8),
Expanded(
child: _summaryCard(
icon:
Icons.sync_rounded,
title: 'Активные',
value:
'$activeCount',
color:
_blueColor,
),
),
const SizedBox(width: 8),
Expanded(
child: _summaryCard(
icon:
Icons.layers_outlined,
title: 'Всего',
value:
'${offers.length}',
color:
_purpleColor,
),
),
],
),
],
),
);
}

Widget _summaryCard({
required IconData icon,
required String title,
required String value,
required Color color,
}) {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal: 11,
vertical: 10,
),
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
BorderRadius.circular(15),
border: Border.all(
color: _borderColor,
),
),
child: Row(
children: [
Container(
width: 30,
height: 30,
decoration:
BoxDecoration(
color:
color.withOpacity(0.10),
borderRadius:
BorderRadius.circular(
10,
),
),
child: Icon(
icon,
color: color,
size: 16,
),
),
const SizedBox(width: 7),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color:
_tertiaryTextColor,
fontSize: 9,
fontWeight:
FontWeight.w600,
),
),
const SizedBox(height: 1),
Text(
value,
style: TextStyle(
color: _textColor,
fontSize: 14,
fontWeight:
FontWeight.w800,
),
),
],
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
const EdgeInsets.symmetric(
horizontal: 30,
),
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 86,
height: 86,
decoration:
BoxDecoration(
color:
_accentColor.withOpacity(
0.09,
),
shape: BoxShape.circle,
),
child: Icon(
Icons
    .swap_horizontal_circle_outlined,
color:
_accentColor,
size: 42,
),
),
const SizedBox(height: 20),
Text(
'Пока нет предложений',
textAlign:
TextAlign.center,
style: TextStyle(
color: _textColor,
fontSize: 21,
fontWeight:
FontWeight.w800,
letterSpacing: -0.4,
),
),
const SizedBox(height: 8),
Text(
'Когда кто-то захочет обменять свою вещь на твою, предложение появится здесь.',
textAlign:
TextAlign.center,
style: TextStyle(
color:
_subTextColor,
fontSize: 13,
height: 1.4,
),
),
],
),
),
);
}

Widget _buildOfferCard(
TradeOffer offer,
TradesProvider provider,
) {
final isTo =
_isToUser(offer);

final statusColor =
_getStatusColor(
offer.status,
);

final canTap =
offer.status == 'accepted' ||
offer.status == 'shipped' ||
offer.status == 'completed';

final itemFromTitle =
isTo
? offer.fromItemTitle
    : offer.toItemTitle;

final itemToTitle =
isTo
? offer.toItemTitle
    : offer.fromItemTitle;

final leftLabel =
isTo
? 'Предлагают тебе'
    : 'Ты предлагаешь';

final rightLabel =
isTo
? 'Ты получишь'
    : 'Взамен получишь';

return Padding(
padding:
const EdgeInsets.only(
bottom: 14,
),
child: GestureDetector(
onTap: canTap
? () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
TradeDiscussionScreen(
offer: offer,
),
),
);
}
    : null,
child: Container(
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
BorderRadius.circular(24),
border: Border.all(
color: canTap
? statusColor.withOpacity(
0.22,
)
    : _borderColor,
width:
canTap ? 1.35 : 1,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(
_isDarkMode
? 0.15
    : 0.045,
),
blurRadius: 22,
offset:
const Offset(0, 9),
),
],
),
clipBehavior:
Clip.antiAlias,
child: Column(
children: [
_buildOfferTop(
offer,
isTo,
statusColor,
canTap,
),
_buildExchangeArea(
offer,
itemFromTitle,
itemToTitle,
leftLabel,
rightLabel,
isTo,
),
_buildDifference(
offer,
),
if (offer.status ==
'pending' &&
isTo)
_buildPendingActions(
offer,
provider,
),
if (offer.status ==
'pending' &&
!isTo)
_buildWaitingState(),
if (offer.status ==
'rejected')
_buildRejectedState(),
if (offer.status ==
'cancelled')
_buildCancelledState(),
if (offer.status ==
'completed')
_buildCompletedState(),
if (canTap &&
offer.status !=
'completed')
_buildOpenHint(
statusColor,
),
],
),
),
),
);
}

Widget _buildOfferTop(
TradeOffer offer,
bool isTo,
Color statusColor,
bool canTap,
) {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
14,
15,
3,
),
child: Row(
children: [
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 6,
),
decoration: BoxDecoration(
color:
statusColor.withOpacity(
0.09,
),
borderRadius:
BorderRadius.circular(
10,
),
),
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
_getStatusIcon(
offer.status,
),
color:
statusColor,
size: 14,
),
const SizedBox(width: 5),
Text(
_getStatusText(
offer.status,
),
style: TextStyle(
color:
statusColor,
fontSize: 10.5,
fontWeight:
FontWeight.w700,
),
),
],
),
),
const Spacer(),
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 5,
),
decoration: BoxDecoration(
color: isTo
? _blueColor
    .withOpacity(0.08)
    : _accentColor
    .withOpacity(0.08),
borderRadius:
BorderRadius.circular(
9,
),
),
child: Text(
isTo ? 'Вам' : 'Вы',
style: TextStyle(
color: isTo
? _blueColor
    : _accentColor,
fontSize: 10,
fontWeight:
FontWeight.w700,
),
),
),
if (canTap) ...[
const SizedBox(width: 6),
Icon(
Icons
    .chevron_right_rounded,
color:
_tertiaryTextColor,
size: 20,
),
],
],
),
);
}

Widget _buildExchangeArea(
TradeOffer offer,
String leftTitle,
String rightTitle,
String leftLabel,
String rightLabel,
bool isTo,
) {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
14,
15,
13,
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
child: _itemBlock(
title: leftTitle,
label: leftLabel,
color:
isTo
? _blueColor
    : _accentColor,
),
),
Padding(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 20,
),
child: _swapIcon(),
),
Expanded(
child: _itemBlock(
title: rightTitle,
label: rightLabel,
color: _greenColor,
),
),
],
),
);
}

Widget _itemBlock({
  required String title,
  required String label,
  required Color color,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _subTextColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _textColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1.18,
        ),
      ),
    ],
  );
}

Widget _swapIcon() {
return Container(
width: 38,
height: 38,
decoration: BoxDecoration(
color: _accentColor
    .withOpacity(0.10),
shape: BoxShape.circle,
border: Border.all(
color: _accentColor
    .withOpacity(0.12),
),
),
child: Icon(
Icons.swap_horiz_rounded,
color: _accentColor,
size: 19,
),
);
}

Widget _buildDifference(
TradeOffer offer,
) {
final hasDifference =
offer.svDifference != 0;

final color = hasDifference
? const Color(0xFFFF9F0A)
    : _greenColor;

final icon = hasDifference
? Icons
    .account_balance_wallet_outlined
    : Icons.balance_rounded;

final text = offer.svDifference >
0
? 'Доплата +${offer.svDifference} SV'
    : offer.svDifference < 0
? 'Доплата ${offer.svDifference} SV'
    : 'Равный обмен';

return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
13,
),
child: Container(
width: double.infinity,
padding:
const EdgeInsets.symmetric(
horizontal: 12,
vertical: 10,
),
decoration: BoxDecoration(
color:
color.withOpacity(0.065),
borderRadius:
BorderRadius.circular(
13,
),
border: Border.all(
color:
color.withOpacity(0.14),
),
),
child: Row(
children: [
Container(
width: 31,
height: 31,
decoration:
BoxDecoration(
color:
color.withOpacity(
0.10,
),
shape:
BoxShape.circle,
),
child: Icon(
icon,
color: color,
size: 16,
),
),
const SizedBox(width: 9),
Expanded(
child: Text(
text,
style: TextStyle(
color: color,
fontSize: 11.5,
fontWeight:
FontWeight.w700,
),
),
),
if (hasDifference)
Text(
'${offer.svDifference.abs()} SV',
style: TextStyle(
color: color,
fontSize: 12,
fontWeight:
FontWeight.w800,
),
),
],
),
),
);
}

Widget _buildPendingActions(
TradeOffer offer,
TradesProvider provider,
) {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
15,
),
child: Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: () =>
_showRejectDialog(
offer,
provider,
),
style:
OutlinedButton.styleFrom(
foregroundColor:
_redColor,
backgroundColor:
_redColor
    .withOpacity(0.045),
side: BorderSide(
color: _redColor
    .withOpacity(0.16),
),
padding:
const EdgeInsets
    .symmetric(
vertical: 13,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius
    .circular(14),
),
),
child: const Text(
'Отклонить',
style: TextStyle(
fontWeight:
FontWeight.w700,
fontSize: 12,
),
),
),
),
const SizedBox(width: 9),
Expanded(
child: ElevatedButton(
onPressed: () =>
_acceptOffer(offer),
style:
ElevatedButton.styleFrom(
backgroundColor:
_greenColor,
foregroundColor:
Colors.white,
elevation: 0,
padding:
const EdgeInsets
    .symmetric(
vertical: 13,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius
    .circular(14),
),
),
child: const Text(
'Принять',
style: TextStyle(
fontWeight:
FontWeight.w800,
fontSize: 12,
),
),
),
),
],
),
);
}

Widget _buildWaitingState() {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
15,
),
child: Container(
width: double.infinity,
padding:
const EdgeInsets.symmetric(
vertical: 10,
horizontal: 12,
),
decoration: BoxDecoration(
color:
_accentColor.withOpacity(0.055),
borderRadius:
BorderRadius.circular(
13,
),
),
child: Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Icon(
Icons.schedule_rounded,
color: _accentColor,
size: 17,
),
const SizedBox(width: 7),
Text(
'Ожидаем ответа',
style: TextStyle(
color: _accentColor,
fontSize: 11.5,
fontWeight:
FontWeight.w700,
),
),
],
),
),
);
}

Widget _buildRejectedState() {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
15,
),
child: _stateBar(
icon:
Icons.block_rounded,
text:
'Предложение отклонено',
color:
_redColor,
),
);
}

Widget _buildCancelledState() {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
15,
),
child: _stateBar(
icon:
Icons.close_rounded,
text:
'Обмен отменён',
color:
_redColor,
),
);
}

Widget _buildCompletedState() {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
15,
),
child: _stateBar(
icon:
Icons.celebration_rounded,
text:
'Обмен завершён',
color:
_greenColor,
),
);
}

Widget _stateBar({
required IconData icon,
required String text,
required Color color,
}) {
return Container(
width: double.infinity,
padding:
const EdgeInsets.symmetric(
horizontal: 12,
vertical: 10,
),
decoration: BoxDecoration(
color:
color.withOpacity(0.065),
borderRadius:
BorderRadius.circular(13),
),
child: Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Icon(
icon,
color: color,
size: 17,
),
const SizedBox(width: 7),
Text(
text,
style: TextStyle(
color: color,
fontSize: 11.5,
fontWeight:
FontWeight.w700,
),
),
],
),
);
}

Widget _buildOpenHint(
Color color,
) {
return Padding(
padding:
const EdgeInsets.fromLTRB(
15,
0,
15,
14,
),
child: Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Text(
'Открыть детали обмена',
style: TextStyle(
color:
color.withOpacity(0.85),
fontSize: 10,
fontWeight:
FontWeight.w600,
),
),
const SizedBox(width: 3),
Icon(
Icons
    .arrow_forward_rounded,
color:
color.withOpacity(0.85),
size: 13,
),
],
),
);
}

Future<void> _acceptOffer(
TradeOffer offer,
) async {
final provider =
context.read<TradesProvider>();

final result =
await provider.updateStatus(
offer.id,
'accepted',
);

if (!mounted) return;

if (result['ok'] != true) {
final error =
result['error']?.toString() ??
'';

_showErrorDialog(
error ==
'insufficient_balance'
? 'У вас недостаточно SV для принятия обмена.'
    : 'Не удалось принять предложение.',
);

return;
}

NotificationService
    .sendNotification(
targetUserId:
offer.fromUserId,
type: 'trade_accepted',
data: {
'trade_id': offer.id,
'item_title':
offer.toItemTitle,
'user_name':
_currentUserName ??
'Пользователь',
},
);

_showMessage(
'Предложение принято',
icon:
Icons.check_circle_rounded,
color:
_greenColor,
);
}

void _showErrorDialog(
String message,
) {
showDialog(
context: context,
builder: (dialogContext) {
return AlertDialog(
backgroundColor:
_surfaceColor,
surfaceTintColor:
Colors.transparent,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(24),
),
title: Row(
children: [
Container(
width: 42,
height: 42,
decoration:
BoxDecoration(
color: _redColor
    .withOpacity(0.10),
shape:
BoxShape.circle,
),
child: Icon(
Icons
    .error_outline_rounded,
color:
_redColor,
size: 23,
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
'Не получилось',
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight:
FontWeight.w700,
),
),
),
],
),
content: Text(
message,
style: TextStyle(
color:
_subTextColor,
fontSize: 13,
height: 1.4,
),
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(
dialogContext,
),
child: Text(
'Понятно',
style: TextStyle(
color:
_accentColor,
fontWeight:
FontWeight.w700,
),
),
),
],
);
},
);
}

void _showMessage(
String text, {
required IconData icon,
required Color color,
}) {
final messenger =
ScaffoldMessenger.of(
context,
);

messenger.hideCurrentSnackBar();

messenger.showSnackBar(
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
elevation: 4,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(16),
side: BorderSide(
color:
color.withOpacity(0.18),
),
),
content: Row(
children: [
Icon(
icon,
color: color,
size: 20,
),
const SizedBox(width: 9),
Expanded(
child: Text(
text,
style: TextStyle(
color: _textColor,
fontSize: 13,
fontWeight:
FontWeight.w700,
),
),
),
],
),
),
);
}

bool _isToUser(
TradeOffer offer,
) {
return offer.toUserId ==
_currentUserId;
}

void _showRejectDialog(
TradeOffer offer,
TradesProvider provider,
) {
showDialog(
context: context,
builder: (dialogContext) {
return AlertDialog(
backgroundColor:
_surfaceColor,
surfaceTintColor:
Colors.transparent,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(24),
),
title: Row(
children: [
Container(
width: 44,
height: 44,
decoration:
BoxDecoration(
color: _redColor
    .withOpacity(0.10),
shape:
BoxShape.circle,
),
child: Icon(
Icons
    .remove_circle_outline,
color:
_redColor,
size: 24,
),
),
const SizedBox(width: 11),
Expanded(
child: Text(
'Отклонить обмен?',
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight:
FontWeight.w700,
),
),
),
],
),
content: Text(
'Предложение будет отклонено, и пользователь получит уведомление.',
style: TextStyle(
color:
_subTextColor,
fontSize: 13,
height: 1.4,
),
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(
dialogContext,
),
child: Text(
'Отмена',
style: TextStyle(
color:
_subTextColor,
fontWeight:
FontWeight.w600,
),
),
),
TextButton(
onPressed: () async {
Navigator.pop(
dialogContext,
);

final result =
await provider
    .updateStatus(
offer.id,
'rejected',
);

if (!mounted) {
return;
}

if (result['ok'] == true) {
NotificationService
    .sendNotification(
targetUserId:
offer.fromUserId,
type:
'trade_declined',
data: {
'trade_id':
offer.id,
'item_title':
offer.toItemTitle,
'user_name':
_currentUserName ??
'Пользователь',
},
);

_showMessage(
'Предложение отклонено',
icon: Icons
    .check_circle_outline,
color:
_redColor,
);
} else {
_showMessage(
'Не удалось отклонить предложение',
icon: Icons
    .error_outline,
color:
_redColor,
);
}
},
child: Text(
'Отклонить',
style: TextStyle(
color:
_redColor,
fontWeight:
FontWeight.w700,
),
),
),
],
);
},
);
}

String _getStatusText(
String status,
) {
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
return 'Ожидает';
}
}

Color _getStatusColor(
String status,
) {
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

IconData _getStatusIcon(
String status,
) {
switch (status) {
case 'accepted':
return Icons
    .check_circle_outline_rounded;
case 'shipped':
return Icons
    .local_shipping_outlined;
case 'completed':
return Icons
    .celebration_rounded;
case 'rejected':
return Icons
    .block_rounded;
case 'cancelled':
return Icons
    .cancel_outlined;
default:
return Icons
    .schedule_rounded;
}
}
}

