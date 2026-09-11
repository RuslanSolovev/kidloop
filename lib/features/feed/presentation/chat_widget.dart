import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
final String messageId;
final String offerId;
final String senderId;
final String senderName;
final String senderAvatar;
final String text;
final String imageUrl;
final String replyToId;
final String replyToText;
final String replyToImageUrl;
final String replyToName;
final String replyToAvatar;
final bool isEdited;
final String createdAt;

ChatMessage({
required this.messageId,
required this.offerId,
required this.senderId,
this.senderName = '',
this.senderAvatar = '',
required this.text,
this.imageUrl = '',
this.replyToId = '',
this.replyToText = '',
this.replyToImageUrl = '',
this.replyToName = '',
this.replyToAvatar = '',
this.isEdited = false,
this.createdAt = '',
});
}

class ChatWidget extends StatefulWidget {
final String offerId;

const ChatWidget({
super.key,
required this.offerId,
});

@override
State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
final List<ChatMessage> _messages = [];

final TextEditingController _textController =
TextEditingController();

final ScrollController _scrollController =
ScrollController();

final FocusNode _textFocusNode = FocusNode();

String? _currentUserId;
String? _currentUserName;
String? _currentUserAvatar;

Timer? _pollTimer;

String? _replyToId;
String? _replyToText;
String? _replyToImageUrl;
String? _replyToName;
String? _replyToAvatar;

String? _editingId;

bool _isLoading = true;
bool _sending = false;

static const String apiUrl =
'https://functions.yandexcloud.net/d4e40k9g2avoblb1of29';

static const String uploadApiUrl =
'https://functions.yandexcloud.net/d4e3c2me21eou683ic6d';

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
const Color(0xFFFF9500);

Color get _blueColor =>
const Color(0xFF0A84FF);

Color get _redColor =>
const Color(0xFFFF453A);

@override
void initState() {
super.initState();

_loadUser();
_loadMessages();

_pollTimer = Timer.periodic(
const Duration(seconds: 3),
(_) {
_loadMessages(
silent: true,
);
},
);
}

@override
void dispose() {
_pollTimer?.cancel();
_textController.dispose();
_scrollController.dispose();
_textFocusNode.dispose();
super.dispose();
}

Future<void> _loadUser() async {
try {
final prefs =
await SharedPreferences.getInstance();

if (!mounted) return;

setState(() {
_currentUserId =
prefs.getString('user_id');

_currentUserName =
prefs.getString('user_name') ??
'Пользователь';

_currentUserAvatar =
prefs.getString('avatar_url') ?? '';
});
} catch (_) {}
}

Future<void> _loadMessages({
bool silent = false,
}) async {
try {
final response = await http
    .post(
Uri.parse(apiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'get-messages',
'chat_id': widget.offerId,
}),
)
    .timeout(
const Duration(seconds: 5),
);

final data =
jsonDecode(response.body);

if (data['ok'] != true || !mounted) {
if (!silent && mounted) {
setState(() {
_isLoading = false;
});
}
return;
}

final serverMessages =
(data['messages'] as List? ?? [])
    .map(
(message) => ChatMessage(
messageId:
message['message_id']
    ?.toString() ??
'',
offerId: widget.offerId,
senderId:
message['sender_id']
    ?.toString() ??
'',
senderName:
message['sender_name']
    ?.toString() ??
'',
senderAvatar:
message['sender_avatar']
    ?.toString() ??
'',
text:
message['text']
    ?.toString() ??
'',
imageUrl:
message['image_url']
    ?.toString() ??
'',
replyToId:
message['reply_to_message']
?['message_id']
    ?.toString() ??
'',
replyToText:
message['reply_to_message']
?['text']
    ?.toString() ??
'',
replyToImageUrl:
message['reply_to_message']
?['image_url']
    ?.toString() ??
'',
replyToName:
message['reply_to_message']
?['sender_name']
    ?.toString() ??
'',
replyToAvatar:
message['reply_to_message']
?['sender_avatar']
    ?.toString() ??
'',
isEdited:
message['is_edited'] == true,
createdAt:
message['created_at']
    ?.toString() ??
'',
),
)
    .toList();

final wasAtBottom =
_isNearBottom();

if (!mounted) return;

setState(() {
_messages
..clear()
..addAll(serverMessages);

_isLoading = false;
});

if (!silent || wasAtBottom) {
_scrollToBottom(
animated: !silent,
);
}
} catch (_) {
if (mounted && !silent) {
setState(() {
_isLoading = false;
});
}
}
}

bool _isNearBottom() {
if (!_scrollController.hasClients) {
return true;
}

final position =
_scrollController.position;

return position.maxScrollExtent -
position.pixels <
100;
}

Future<void> _sendMessage({
String? imageUrl,
}) async {
if (_sending) return;

final text =
_textController.text.trim();

if (text.isEmpty && imageUrl == null) {
return;
}

final body =
<String, dynamic>{
'action': 'send-message',
'chat_id': widget.offerId,
'sender_id': _currentUserId,
'text': text,
};

if (imageUrl != null) {
body['image_url'] = imageUrl;
}

if (_replyToId != null) {
body['reply_to'] = _replyToId;
}

setState(() {
_sending = true;
});

_textController.clear();
_cancelReply(
keepFocus: true,
);
_cancelEdit(
keepFocus: true,
);

try {
final response = await http
    .post(
Uri.parse(apiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode(body),
)
    .timeout(
const Duration(seconds: 5),
);

if (response.statusCode >= 200 &&
response.statusCode < 300) {
await _loadMessages();
}
} catch (_) {
if (mounted) {
_showMessage(
'Не удалось отправить сообщение',
isError: true,
);
}
} finally {
if (mounted) {
setState(() {
_sending = false;
});
}
}
}

Future<void> _pickAndSendImage() async {
if (_sending) return;

final picker = ImagePicker();

final picked =
await picker.pickImage(
source: ImageSource.gallery,
imageQuality: 75,
);

if (picked == null) return;

setState(() {
_sending = true;
});

try {
final bytes =
await File(picked.path)
    .readAsBytes();

final encoded =
base64Encode(bytes);

final uploadResponse = await http
    .post(
Uri.parse(uploadApiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'upload',
'file_name':
'chat_${DateTime.now().millisecondsSinceEpoch}.jpg',
'file_data': encoded,
}),
)
    .timeout(
const Duration(seconds: 20),
);

final uploadData =
jsonDecode(uploadResponse.body);

if (uploadData['ok'] == true) {
final uploadedUrl =
uploadData['file_url']
    ?.toString();

if (uploadedUrl != null &&
uploadedUrl.isNotEmpty) {
setState(() {
_sending = false;
});

await _sendMessage(
imageUrl: uploadedUrl,
);
} else {
throw Exception(
'Empty file url',
);
}
} else {
throw Exception(
'Upload failed',
);
}
} catch (_) {
if (mounted) {
setState(() {
_sending = false;
});

_showMessage(
'Не удалось загрузить фото',
isError: true,
);
}
}
}

Future<void> _deleteMessage(
String messageId,
) async {
try {
await http
    .post(
Uri.parse(apiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'delete-message',
'message_id': messageId,
'user_id': _currentUserId,
'chat_id': widget.offerId,
}),
)
    .timeout(
const Duration(seconds: 5),
);

await _loadMessages();
} catch (_) {
if (mounted) {
_showMessage(
'Не удалось удалить сообщение',
isError: true,
);
}
}
}

Future<void> _editMessage(
String messageId,
String newText,
) async {
final text = newText.trim();

if (text.isEmpty) {
return;
}

try {
await http
    .post(
Uri.parse(apiUrl),
headers: {
'Content-Type': 'application/json',
},
body: jsonEncode({
'action': 'edit-message',
'message_id': messageId,
'sender_id': _currentUserId,
'text': text,
'chat_id': widget.offerId,
}),
)
    .timeout(
const Duration(seconds: 5),
);

_textController.clear();

if (mounted) {
setState(() {
_editingId = null;
});
}

await _loadMessages();
} catch (_) {
if (mounted) {
_showMessage(
'Не удалось изменить сообщение',
isError: true,
);
}
}
}

void _startReply(ChatMessage message) {
setState(() {
_replyToId = message.messageId;
_replyToText = message.text;
_replyToImageUrl = message.imageUrl;
_replyToName = message.senderName;
_replyToAvatar = message.senderAvatar;
_editingId = null;
});

_focusInput();
}

void _startEdit(ChatMessage message) {
setState(() {
_editingId = message.messageId;

_replyToId = null;
_replyToText = null;
_replyToImageUrl = null;
_replyToName = null;
_replyToAvatar = null;
});

_textController.text =
message.text;

_textController.selection =
TextSelection.fromPosition(
TextPosition(
offset:
_textController.text.length,
),
);

_focusInput();
}

void _cancelReply({
bool keepFocus = false,
}) {
if (!mounted) return;

setState(() {
_replyToId = null;
_replyToText = null;
_replyToImageUrl = null;
_replyToName = null;
_replyToAvatar = null;
});

if (keepFocus) {
_focusInput();
}
}

void _cancelEdit({
bool keepFocus = false,
}) {
if (!mounted) return;

setState(() {
_editingId = null;
});

if (!keepFocus) {
_textController.clear();
}

if (keepFocus) {
_focusInput();
}
}

void _focusInput() {
WidgetsBinding.instance
    .addPostFrameCallback((_) {
if (mounted) {
_textFocusNode.requestFocus();
}
});
}

void _scrollToBottom({
bool animated = true,
}) {
WidgetsBinding.instance
    .addPostFrameCallback((_) {
if (!_scrollController
    .hasClients) {
return;
}

final target =
_scrollController
    .position
    .maxScrollExtent;

if (animated) {
_scrollController.animateTo(
target,
duration:
const Duration(
milliseconds: 260,
),
curve: Curves.easeOut,
);
} else {
_scrollController.jumpTo(
target,
);
}
});
}

void _showFullImage(
String url,
) {
Navigator.push(
context,
PageRouteBuilder(
opaque: false,
pageBuilder: (
context,
animation,
secondaryAnimation,
) {
return _FullScreenImage(
url: url,
);
},
transitionsBuilder: (
context,
animation,
secondaryAnimation,
child,
) {
return FadeTransition(
opacity: animation,
child: child,
);
},
),
);
}

Widget _buildAvatar(
String? url,
String name, {
double radius = 17,
}) {
if (url != null &&
url.isNotEmpty &&
url.startsWith('http')) {
return Container(
width: radius * 2,
height: radius * 2,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: _secondarySurfaceColor,
border: Border.all(
color: _borderColor,
),
),
child: ClipOval(
child: CachedNetworkImage(
imageUrl: url,
width: radius * 2,
height: radius * 2,
fit: BoxFit.cover,
placeholder: (
context,
url,
) =>
_buildInitial(
name,
radius,
),
errorWidget: (
context,
url,
error,
) =>
_buildInitial(
name,
radius,
),
),
),
);
}

return _buildInitial(
name,
radius,
);
}

Widget _buildInitial(
String name,
double radius,
) {
const colors = [
Color(0xFF5856D6),
Color(0xFF0A84FF),
Color(0xFF30D158),
Color(0xFFFF9F0A),
Color(0xFFBF5AF2),
Color(0xFFFF375F),
];

final index =
name.hashCode.abs() %
colors.length;

return Container(
width: radius * 2,
height: radius * 2,
decoration: BoxDecoration(
color: colors[index],
shape: BoxShape.circle,
),
alignment: Alignment.center,
child: Text(
name.isNotEmpty
? name[0].toUpperCase()
    : '?',
style: TextStyle(
color: Colors.white,
fontSize: radius * 0.8,
fontWeight: FontWeight.w700,
),
),
);
}

@override
Widget build(BuildContext context) {
return Container(
decoration: BoxDecoration(
color: _backgroundColor,
borderRadius:
BorderRadius.circular(22),
border: Border.all(
color: _borderColor,
),
),
child: Column(
children: [
_buildChatHeader(),
Expanded(
child: _buildMessagesArea(),
),
if (_replyToId != null)
_buildReplyBar(),
if (_editingId != null)
_buildEditingBar(),
_buildComposer(),
],
),
);
}

Widget _buildChatHeader() {
return Container(
padding:
const EdgeInsets.fromLTRB(
15,
12,
15,
12,
),
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
const BorderRadius.vertical(
top: Radius.circular(22),
),
border: Border(
bottom: BorderSide(
color: _borderColor,
),
),
),
child: Row(
children: [
Container(
width: 38,
height: 38,
decoration: BoxDecoration(
color:
_accentColor.withOpacity(
0.10,
),
borderRadius:
BorderRadius.circular(12),
),
child: Icon(
Icons.chat_bubble_rounded,
color: _accentColor,
size: 19,
),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Обсуждение обмена',
style: TextStyle(
color: _textColor,
fontSize: 14,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(height: 2),
Text(
_messages.isEmpty
? 'Начните разговор'
    : '${_messages.length} сообщений',
style: TextStyle(
color: _secondaryTextColor,
fontSize: 10.5,
),
),
],
),
),
if (_isLoading)
SizedBox(
width: 16,
height: 16,
child:
CircularProgressIndicator(
strokeWidth: 2,
valueColor:
AlwaysStoppedAnimation<
Color>(
_accentColor,
),
),
),
],
),
);
}

Widget _buildMessagesArea() {
if (_isLoading) {
return _buildLoadingState();
}

if (_messages.isEmpty) {
return _buildEmptyState();
}

return Stack(
children: [
ListView.builder(
controller:
_scrollController,
physics:
const BouncingScrollPhysics(),
padding:
const EdgeInsets.fromLTRB(
10,
14,
10,
16,
),
itemCount:
_messages.length,
itemBuilder:
(context, index) {
final message =
_messages[index];

final mine =
message.senderId ==
_currentUserId;

final showAvatar =
!mine &&
(index == 0 ||
_messages[index - 1]
    .senderId !=
message.senderId);

final showDay =
index == 0 ||
_getDayLabel(
_messages[
index - 1],
) !=
_getDayLabel(
message,
);

return Column(
children: [
if (showDay)
_buildDateDivider(
message.createdAt,
),
_buildMessageBubble(
message,
mine,
showAvatar,
),
],
);
},
),
if (_messages.isNotEmpty)
Positioned(
right: 10,
bottom: 8,
child:
_buildScrollButton(),
),
],
);
}

Widget _buildLoadingState() {
return Center(
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 50,
height: 50,
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
BorderRadius.circular(16),
border: Border.all(
color: _borderColor,
),
),
child: Center(
child:
CircularProgressIndicator(
strokeWidth: 2.2,
valueColor:
AlwaysStoppedAnimation<
Color>(
_accentColor,
),
),
),
),
const SizedBox(height: 10),
Text(
'Загружаем чат',
style: TextStyle(
color: _textColor,
fontSize: 13,
fontWeight:
FontWeight.w600,
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
const EdgeInsets.all(24),
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 64,
height: 64,
decoration: BoxDecoration(
color: _accentColor
    .withOpacity(0.09),
shape: BoxShape.circle,
),
child: Icon(
Icons.chat_bubble_outline_rounded,
color: _accentColor,
size: 29,
),
),
const SizedBox(height: 14),
Text(
'Начните обсуждение',
textAlign:
TextAlign.center,
style: TextStyle(
color: _textColor,
fontSize: 16,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(height: 5),
Text(
'Обсудите передачу вещей, сроки и детали обмена.',
textAlign:
TextAlign.center,
style: TextStyle(
color:
_secondaryTextColor,
fontSize: 11.5,
height: 1.35,
),
),
],
),
),
);
}

Widget _buildMessageBubble(
ChatMessage message,
bool mine,
bool showAvatar,
) {
final maxWidth =
MediaQuery.of(context)
    .size
    .width *
0.70;

return Padding(
padding:
EdgeInsets.only(
top: showAvatar ? 8 : 2,
bottom: 3,
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.end,
mainAxisAlignment: mine
? MainAxisAlignment.end
    : MainAxisAlignment.start,
children: [
if (!mine)
SizedBox(
width: 32,
child: showAvatar
? _buildAvatar(
message.senderAvatar,
message.senderName,
radius: 16,
)
    : null,
),
if (!mine)
const SizedBox(width: 6),
Flexible(
child: GestureDetector(
onLongPress: () =>
_showMessageMenu(
context,
message,
mine,
),
child: Container(
constraints:
BoxConstraints(
maxWidth: maxWidth,
),
padding:
const EdgeInsets.fromLTRB(
11,
8,
10,
7,
),
decoration: BoxDecoration(
color: mine
? _accentColor
    : _surfaceColor,
borderRadius:
BorderRadius.only(
topLeft:
const Radius.circular(
18,
),
topRight:
const Radius.circular(
18,
),
bottomLeft:
Radius.circular(
mine ? 18 : 5,
),
bottomRight:
Radius.circular(
mine ? 5 : 18,
),
),
border: mine
? null
    : Border.all(
color:
_borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(
_isDarkMode
? 0.10
    : 0.035,
),
blurRadius: 8,
offset:
const Offset(0, 3),
),
],
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
if (!mine && showAvatar)
Padding(
padding:
const EdgeInsets.only(
bottom: 5,
),
child: Text(
message.senderName
    .isNotEmpty
? message.senderName
    : 'Пользователь',
style: TextStyle(
color:
_accentColor,
fontSize: 10,
fontWeight:
FontWeight.w700,
),
),
),

if (message.replyToId
    .isNotEmpty)
_buildReplyPreview(
message,
mine,
),

if (message.imageUrl
    .isNotEmpty)
_buildMessageImage(
message.imageUrl,
),

if (message.text.isNotEmpty)
Padding(
padding: EdgeInsets.only(
top: message.imageUrl
    .isNotEmpty
? 5
    : 0,
),
child: Text(
message.text,
style: TextStyle(
color: mine
? Colors.white
    : _textColor,
fontSize: 13.5,
height: 1.3,
),
),
),

const SizedBox(height: 4),

Row(
mainAxisSize:
MainAxisSize.min,
mainAxisAlignment:
MainAxisAlignment.end,
children: [
Text(
_formatTime(
message.createdAt,
),
style: TextStyle(
color: mine
? Colors.white
    .withOpacity(
0.62,
)
    : _tertiaryTextColor,
fontSize: 9,
),
),
if (message.isEdited)
Padding(
padding:
const EdgeInsets
    .only(
left: 4,
),
child: Text(
'изменено',
style: TextStyle(
color: mine
? Colors.white
    .withOpacity(
0.60,
)
    : _tertiaryTextColor,
fontSize: 8.5,
),
),
),
if (mine) ...[
const SizedBox(width: 4),
Icon(
Icons.done_all_rounded,
color: Colors.white
    .withOpacity(
0.62,
),
size: 12,
),
],
],
),
],
),
),
),
),
if (mine)
const SizedBox(width: 6),
if (mine)
SizedBox(
width: 32,
child: showAvatar
? _buildAvatar(
_currentUserAvatar,
_currentUserName ??
'Вы',
radius: 16,
)
    : null,
),
],
),
);
}

Widget _buildReplyPreview(
ChatMessage message,
bool mine,
) {
final previewColor = mine
? Colors.white.withOpacity(0.82)
    : _accentColor;

return Container(
margin:
const EdgeInsets.only(
bottom: 5,
),
padding:
const EdgeInsets.fromLTRB(
8,
6,
8,
6,
),
decoration: BoxDecoration(
color: mine
? Colors.white.withOpacity(
0.13,
)
    : _secondarySurfaceColor,
borderRadius:
BorderRadius.circular(10),
border: Border(
left: BorderSide(
color: previewColor,
width: 2.5,
),
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
if (message.replyToName
    .isNotEmpty)
Text(
message.replyToName,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: previewColor,
fontSize: 9.5,
fontWeight:
FontWeight.w700,
),
),
if (message.replyToImageUrl
    .isNotEmpty)
Padding(
padding:
const EdgeInsets.only(
top: 4,
bottom: 3,
),
child: ClipRRect(
borderRadius:
BorderRadius.circular(6),
child:
CachedNetworkImage(
imageUrl:
message.replyToImageUrl,
width: 34,
height: 34,
fit: BoxFit.cover,
),
),
),
if (message.replyToText
    .isNotEmpty)
Text(
message.replyToText,
maxLines: 2,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: mine
? Colors.white
    .withOpacity(
0.72,
)
    : _secondaryTextColor,
fontSize: 10,
height: 1.2,
),
),
],
),
);
}

Widget _buildMessageImage(
String url,
) {
final width =
MediaQuery.of(context)
    .size
    .width *
0.43;

return GestureDetector(
onTap: () =>
_showFullImage(url),
child: ClipRRect(
borderRadius:
BorderRadius.circular(12),
child: CachedNetworkImage(
imageUrl: url,
fit: BoxFit.cover,
width: width,
height: width * 0.78,
placeholder: (
context,
url,
) =>
Container(
width: width,
height: width * 0.78,
color:
_secondarySurfaceColor,
child: Center(
child:
CircularProgressIndicator(
strokeWidth: 2,
valueColor:
AlwaysStoppedAnimation<
Color>(
_accentColor,
),
),
),
),
errorWidget: (
context,
url,
error,
) =>
Container(
width: width,
height: width * 0.60,
color:
_secondarySurfaceColor,
child: Icon(
Icons.broken_image_outlined,
color: _tertiaryTextColor,
size: 28,
),
),
),
),
);
}

Widget _buildReplyBar() {
return Container(
padding:
const EdgeInsets.fromLTRB(
12,
8,
8,
8,
),
decoration: BoxDecoration(
color: _surfaceColor,
border: Border(
top: BorderSide(
color: _borderColor,
),
),
),
child: Row(
children: [
Container(
width: 3,
height: 38,
decoration: BoxDecoration(
color: _accentColor,
borderRadius:
BorderRadius.circular(3),
),
),
const SizedBox(width: 8),
Icon(
Icons.reply_rounded,
color: _accentColor,
size: 17,
),
const SizedBox(width: 7),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Ответ ${_replyToName?.isNotEmpty == true ? _replyToName : 'пользователю'}',
style: TextStyle(
color: _accentColor,
fontSize: 10,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(height: 2),
if (_replyToText != null &&
_replyToText!
    .isNotEmpty)
Text(
_replyToText!,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color:
_secondaryTextColor,
fontSize: 10.5,
),
)
else
Text(
'Фото',
style: TextStyle(
color:
_secondaryTextColor,
fontSize: 10.5,
),
),
],
),
),
IconButton(
onPressed:
_cancelReply,
icon: Icon(
Icons.close_rounded,
color:
_secondaryTextColor,
size: 18,
),
padding: EdgeInsets.zero,
constraints:
const BoxConstraints(
minWidth: 36,
minHeight: 36,
),
),
],
),
);
}

Widget _buildEditingBar() {
return Container(
padding:
const EdgeInsets.fromLTRB(
12,
8,
8,
8,
),
decoration: BoxDecoration(
color: _surfaceColor,
border: Border(
top: BorderSide(
color: _borderColor,
),
),
),
child: Row(
children: [
Container(
width: 34,
height: 34,
decoration: BoxDecoration(
color:
_blueColor.withOpacity(
0.10,
),
borderRadius:
BorderRadius.circular(10),
),
child: Icon(
Icons.edit_rounded,
color: _blueColor,
size: 17,
),
),
const SizedBox(width: 9),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Редактирование',
style: TextStyle(
color: _blueColor,
fontSize: 10,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(height: 2),
Text(
'Измените текст и нажмите отправить',
style: TextStyle(
color:
_secondaryTextColor,
fontSize: 10,
),
),
],
),
),
TextButton(
onPressed:
_cancelEdit,
child: Text(
'Отмена',
style: TextStyle(
color: _secondaryTextColor,
fontSize: 11,
fontWeight:
FontWeight.w600,
),
),
),
],
),
);
}

Widget _buildComposer() {
final canSend =
_textController.text
    .trim()
    .isNotEmpty &&
!_sending;

return Container(
padding:
const EdgeInsets.fromLTRB(
9,
8,
9,
10,
),
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
const BorderRadius.vertical(
bottom: Radius.circular(22),
),
border: Border(
top: BorderSide(
color: _borderColor,
),
),
),
child: SafeArea(
top: false,
child: Row(
crossAxisAlignment:
CrossAxisAlignment.end,
children: [
_composerIconButton(
icon:
Icons.photo_outlined,
onTap: _sending
? null
    : _pickAndSendImage,
color: _accentColor,
),
const SizedBox(width: 6),
Expanded(
child: Container(
constraints:
const BoxConstraints(
minHeight: 42,
maxHeight: 110,
),
decoration:
BoxDecoration(
color:
_secondarySurfaceColor,
borderRadius:
BorderRadius.circular(
22,
),
border: Border.all(
color: _borderColor,
),
),
child: TextField(
controller:
_textController,
focusNode:
_textFocusNode,
textCapitalization:
TextCapitalization
    .sentences,
keyboardType:
TextInputType
    .multiline,
minLines: 1,
maxLines: 4,
onChanged: (_) {
setState(() {});
},
style: TextStyle(
color: _textColor,
fontSize: 13.5,
),
decoration:
InputDecoration(
hintText:
_editingId != null
? 'Изменить сообщение...'
    : 'Сообщение',
hintStyle:
TextStyle(
color:
_tertiaryTextColor,
fontSize: 13.5,
),
border:
InputBorder.none,
contentPadding:
const EdgeInsets
    .symmetric(
horizontal: 15,
vertical: 10,
),
),
),
),
),
const SizedBox(width: 6),
_buildSendButton(
enabled: canSend,
),
],
),
),
);
}

Widget _composerIconButton({
required IconData icon,
required VoidCallback? onTap,
required Color color,
}) {
return GestureDetector(
onTap: onTap,
child: Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: color.withOpacity(
onTap == null ? 0.05 : 0.09,
),
shape: BoxShape.circle,
),
child: Icon(
icon,
color: onTap == null
? _tertiaryTextColor
    : color,
size: 20,
),
),
);
}

Widget _buildSendButton({
required bool enabled,
}) {
return GestureDetector(
onTap: enabled
? () {
if (_editingId != null) {
_editMessage(
_editingId!,
_textController.text,
);
} else {
_sendMessage();
}
}
    : null,
child: AnimatedContainer(
duration:
const Duration(milliseconds: 180),
width: 42,
height: 42,
decoration: BoxDecoration(
color: enabled
? _accentColor
    : _secondarySurfaceColor,
shape: BoxShape.circle,
boxShadow: enabled
? [
BoxShadow(
color: _accentColor
    .withOpacity(0.24),
blurRadius: 10,
offset:
const Offset(0, 4),
),
]
    : null,
),
child: _sending
? const Padding(
padding:
EdgeInsets.all(12),
child:
CircularProgressIndicator(
strokeWidth: 2,
valueColor:
AlwaysStoppedAnimation<
Color>(
Colors.white,
),
),
)
    : Icon(
_editingId != null
? Icons.check_rounded
    : Icons.arrow_upward_rounded,
color: enabled
? Colors.white
    : _tertiaryTextColor,
size: 20,
),
),
);
}

Widget _buildScrollButton() {
return IgnorePointer(
child: AnimatedOpacity(
duration:
const Duration(milliseconds: 150),
opacity:
_isNearBottom() ? 0 : 1,
child: Container(
width: 36,
height: 36,
decoration: BoxDecoration(
color: _surfaceColor,
shape: BoxShape.circle,
border: Border.all(
color: _borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(0.12),
blurRadius: 10,
offset:
const Offset(0, 3),
),
],
),
child: Icon(
Icons.keyboard_arrow_down_rounded,
color: _textColor,
size: 20,
),
),
),
);
}

Widget _buildDateDivider(
String createdAt,
) {
final label =
_getDayLabelFromString(
createdAt,
);

if (label.isEmpty) {
return const SizedBox.shrink();
}

return Padding(
padding:
const EdgeInsets.symmetric(
vertical: 9,
),
child: Row(
children: [
Expanded(
child: Container(
height: 1,
color: _borderColor,
),
),
Padding(
padding:
const EdgeInsets.symmetric(
horizontal: 10,
),
child: Text(
label,
style: TextStyle(
color:
_tertiaryTextColor,
fontSize: 9.5,
fontWeight:
FontWeight.w600,
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
),
);
}

String _getDayLabel(
ChatMessage message,
) {
return _getDayLabelFromString(
message.createdAt,
);
}

String _getDayLabelFromString(
String iso,
) {
if (iso.isEmpty) {
return '';
}

try {
final date =
DateTime.parse(iso);
final now = DateTime.now();

final messageDate = DateTime(
date.year,
date.month,
date.day,
);

final today = DateTime(
now.year,
now.month,
now.day,
);

final difference =
today.difference(
messageDate,
).inDays;

if (difference == 0) {
return 'Сегодня';
}

if (difference == 1) {
return 'Вчера';
}

return DateFormat(
'd MMMM',
'ru',
).format(date);
} catch (_) {
return '';
}
}

String _formatTime(
String iso,
) {
if (iso.isEmpty) {
return '';
}

try {
final date =
DateTime.parse(iso);

return DateFormat(
'HH:mm',
).format(date);
} catch (_) {
return '';
}
}

void _showMessageMenu(
BuildContext context,
ChatMessage message,
bool mine,
) {
showModalBottomSheet(
context: context,
backgroundColor: Colors.transparent,
builder: (sheetContext) {
return SafeArea(
child: Container(
margin:
const EdgeInsets.all(8),
padding:
const EdgeInsets.only(
top: 8,
bottom: 8,
),
decoration: BoxDecoration(
color: _surfaceColor,
borderRadius:
BorderRadius.circular(26),
border: Border.all(
color: _borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black
    .withOpacity(0.18),
blurRadius: 30,
offset:
const Offset(0, -4),
),
],
),
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Container(
width: 34,
height: 4,
decoration: BoxDecoration(
color:
_tertiaryTextColor
    .withOpacity(
0.35,
),
borderRadius:
BorderRadius.circular(
10,
),
),
),
const SizedBox(height: 8),
if (!mine)
_menuAction(
icon:
Icons.reply_rounded,
iconColor:
_accentColor,
title: 'Ответить',
onTap: () {
Navigator.pop(
sheetContext,
);
_startReply(
message,
);
},
),
if (mine)
_menuAction(
icon:
Icons.edit_rounded,
iconColor:
_blueColor,
title:
'Редактировать',
onTap: () {
Navigator.pop(
sheetContext,
);
_startEdit(
message,
);
},
),
if (mine)
_menuAction(
icon:
Icons.delete_outline_rounded,
iconColor:
_redColor,
title: 'Удалить',
titleColor:
_redColor,
onTap: () {
Navigator.pop(
sheetContext,
);
_showDeleteConfirmDialog(
message.messageId,
);
},
),
_menuAction(
icon:
Icons.close_rounded,
iconColor:
_secondaryTextColor,
title: 'Закрыть',
onTap: () =>
Navigator.pop(
sheetContext,
),
),
],
),
),
);
},
);
}

Widget _menuAction({
required IconData icon,
required Color iconColor,
required String title,
Color? titleColor,
required VoidCallback onTap,
}) {
return InkWell(
onTap: onTap,
child: Padding(
padding:
const EdgeInsets.symmetric(
horizontal: 15,
vertical: 7,
),
child: Row(
children: [
Container(
width: 38,
height: 38,
decoration: BoxDecoration(
color: iconColor
    .withOpacity(0.09),
borderRadius:
BorderRadius.circular(
12,
),
),
child: Icon(
icon,
color: iconColor,
size: 19,
),
),
const SizedBox(width: 12),
Text(
title,
style: TextStyle(
color:
titleColor ??
_textColor,
fontSize: 14,
fontWeight:
FontWeight.w600,
),
),
],
),
),
);
}

void _showDeleteConfirmDialog(
String messageId,
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
title: Text(
'Удалить сообщение?',
style: TextStyle(
color: _textColor,
fontSize: 19,
fontWeight:
FontWeight.w700,
),
),
content: Text(
'Сообщение будет удалено без возможности восстановления.',
style: TextStyle(
color:
_secondaryTextColor,
fontSize: 13,
height: 1.35,
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
_secondaryTextColor,
fontWeight:
FontWeight.w600,
),
),
),
TextButton(
onPressed: () {
Navigator.pop(
dialogContext,
);
_deleteMessage(
messageId,
);
},
child: Text(
'Удалить',
style: TextStyle(
color: _redColor,
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
bool isError = false,
}) {
if (!mounted) return;

final messenger =
ScaffoldMessenger.of(context);

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
backgroundColor: isError
? _redColor
    : _accentColor,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(14),
),
content: Text(
text,
style: const TextStyle(
color: Colors.white,
fontWeight:
FontWeight.w600,
),
),
),
);
}
}

class _FullScreenImage
extends StatelessWidget {
final String url;

const _FullScreenImage({
required this.url,
});

@override
Widget build(
BuildContext context,
) {
return Scaffold(
backgroundColor:
Colors.black,
body: Stack(
children: [
Positioned.fill(
child:
InteractiveViewer(
minScale: 0.5,
maxScale: 4,
child:
CachedNetworkImage(
imageUrl: url,
fit: BoxFit.contain,
width: double.infinity,
height: double.infinity,
placeholder: (
context,
url,
) =>
const Center(
child:
CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
),
),
errorWidget: (
context,
url,
error,
) =>
const Center(
child: Column(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
Icons
    .broken_image_outlined,
color:
Colors.white54,
size: 58,
),
SizedBox(
height: 10,
),
Text(
'Не удалось загрузить изображение',
style: TextStyle(
color:
Colors.white54,
fontSize: 13,
),
),
],
),
),
),
),
),
SafeArea(
child: Align(
alignment:
Alignment.topLeft,
child: Padding(
padding:
const EdgeInsets.all(
14,
),
child:
GestureDetector(
onTap: () =>
Navigator.pop(
context,
),
child: Container(
width: 42,
height: 42,
decoration:
BoxDecoration(
color: Colors.white
    .withOpacity(
0.14,
),
shape:
BoxShape.circle,
border: Border.all(
color: Colors.white
    .withOpacity(
0.10,
),
),
),
child: const Icon(
Icons
    .close_rounded,
color:
Colors.white,
size: 21,
),
),
),
),
),
),
],
),
);
}
}

