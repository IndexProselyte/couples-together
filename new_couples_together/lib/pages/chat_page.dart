import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme_notifier.dart';
import '../design_tokens.dart';
import '../services/message_cache.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dateLabel(String dateStr) {
  final d = DateTime.parse(dateStr);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final msgDay = DateTime(d.year, d.month, d.day);
  if (msgDay == today) return 'Today';
  if (msgDay == yesterday) return 'Yesterday';
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _nowTime() {
  final t = TimeOfDay.now();
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

int _parseMinutes(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

// ── Status drawer data ─────────────────────────────────────────────────────────

class _Service {
  const _Service({required this.name, required this.icon, required this.detail, required this.status});
  final String name;
  final String icon;
  final String detail;
  final String status;
}

const _services = [
  _Service(name: 'Discord',   icon: '🎮', detail: 'Online',                status: 'online'),
  _Service(name: 'Instagram', icon: '📷', detail: 'Active 5m ago',         status: 'online'),
  _Service(name: 'Steam',     icon: '🕹️', detail: 'Playing Stardew Valley', status: 'playing'),
  _Service(name: 'Spotify',   icon: '🎵', detail: 'Listening · Chill mix', status: 'online'),
];

// ── List item types ────────────────────────────────────────────────────────────

class _MsgListItem {
  const _MsgListItem({
    required this.msg,
    required this.msgIndex,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
  final ChatMessage msg;
  final int msgIndex;
  final bool isFirstInGroup;
  final bool isLastInGroup;
}

class _DateDividerItem {
  const _DateDividerItem({required this.label});
  final String label;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  bool _drawerOpen = false;
  bool _loading = true;
  bool _searchActive = false;
  String _searchQuery = '';

  late AnimationController _drawerAnim;
  late Animation<double> _drawerSlide;

  // Messages — stored newest-first (index 0 = latest)
  List<ChatMessage> _messages = [];
  List<Object> _listItems = [];

  @override
  void initState() {
    super.initState();
    _drawerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _drawerSlide = CurvedAnimation(parent: _drawerAnim, curve: Curves.easeOutCubic);
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _drawerAnim.dispose();
    super.dispose();
  }

  // ── Cache I/O ──────────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    final cached = await MessageCache.load();
    setState(() {
      _messages = cached;
      _loading = false;
    });
    _computeListItems();
    if (_messages.isNotEmpty) await _persistMessages();
  }

  Future<void> _persistMessages() async => MessageCache.save(_messages);

  // ── List items ─────────────────────────────────────────────────────────────

  void _computeListItems() {
    final source = _searchQuery.isEmpty
        ? _messages
        : _messages
            .where((m) => m.text.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    final items = <Object>[];
    for (int i = 0; i < source.length; i++) {
      final msg = source[i];
      final prevMsg = i > 0 ? source[i - 1] : null;
      final nextMsg = i < source.length - 1 ? source[i + 1] : null;

      final isLastInGroup = prevMsg == null || !_sameGroup(msg, prevMsg);
      final isFirstInGroup = nextMsg == null || !_sameGroup(msg, nextMsg);
      final originalIndex = _messages.indexOf(msg);

      items.add(_MsgListItem(
        msg: msg,
        msgIndex: originalIndex,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      ));

      if (nextMsg != null &&
          msg.date != null &&
          nextMsg.date != null &&
          msg.date != nextMsg.date) {
        items.add(_DateDividerItem(label: _dateLabel(msg.date!)));
      }
    }
    if (source.isNotEmpty && source.last.date != null) {
      items.add(_DateDividerItem(label: _dateLabel(source.last.date!)));
    }
    setState(() => _listItems = items);
  }

  bool _sameGroup(ChatMessage a, ChatMessage b) {
    if (a.isSent != b.isSent) return false;
    if (a.date != b.date) return false;
    return (_parseMinutes(a.time) - _parseMinutes(b.time)).abs() <= 3;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
    _drawerOpen ? _drawerAnim.forward() : _drawerAnim.reverse();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final msg = ChatMessage(text: text, isSent: true, time: _nowTime(), date: _dateStr(DateTime.now()));
    _inputController.clear();
    setState(() => _messages.insert(0, msg));
    _computeListItems();
    await _persistMessages();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1280);
    if (file == null) return;
    final msg = ChatMessage(
      text: '', isSent: true, time: _nowTime(), date: _dateStr(DateTime.now()), imagePath: file.path,
    );
    setState(() => _messages.insert(0, msg));
    _computeListItems();
    await _persistMessages();
  }

  void _toggleReaction(int msgIndex, String emoji) {
    final msg = _messages[msgIndex];
    final reactions = List<String>.from(msg.reactions);
    if (reactions.contains(emoji)) {
      reactions.remove(emoji);
    } else {
      reactions.add(emoji);
    }
    setState(() => _messages[msgIndex] = msg.copyWith(reactions: reactions));
    _computeListItems();
    _persistMessages();
  }

  void _toggleStar(int msgIndex) {
    final msg = _messages[msgIndex];
    setState(() => _messages[msgIndex] = msg.copyWith(isStarred: !msg.isStarred));
    _computeListItems();
    _persistMessages();
  }

  void _deleteMessage(int msgIndex) {
    setState(() => _messages.removeAt(msgIndex));
    _computeListItems();
    _persistMessages();
  }

  void _showContextMenu(int msgIndex) {
    FocusScope.of(context).unfocus();
    final msg = _messages[msgIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeScope.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
      builder: (ctx) => _ContextMenuSheet(
        msg: msg,
        onReact: (e) { Navigator.pop(ctx); _toggleReaction(msgIndex, e); },
        onStar: () { Navigator.pop(ctx); _toggleStar(msgIndex); },
        onDelete: () { Navigator.pop(ctx); _deleteMessage(msgIndex); },
      ),
    );
  }

  void _showStarredPanel() {
    FocusScope.of(context).unfocus();
    final starred = _messages.where((m) => m.isStarred).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppThemeScope.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      barrierColor: AppColors.pinkDeep.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (_) => _StarredPanel(messages: starred),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              searchActive: _searchActive,
              onStatusTap: _toggleDrawer,
              onSearchTap: () {
                setState(() {
                  _searchActive = !_searchActive;
                  if (!_searchActive) {
                    _searchController.clear();
                    _searchQuery = '';
                    _computeListItems();
                  }
                });
              },
              onStarTap: _showStarredPanel,
            ),
            if (_searchActive)
              _SearchBar(
                controller: _searchController,
                matchCount: _searchQuery.isEmpty
                    ? 0
                    : _messages.where((m) => m.text.toLowerCase().contains(_searchQuery.toLowerCase())).length,
                onChanged: (q) {
                  setState(() => _searchQuery = q);
                  _computeListItems();
                },
                onClose: () {
                  setState(() {
                    _searchActive = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _computeListItems();
                },
              ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(gradient: t.gradientChat),
                    child: _loading
                        ? Center(child: CircularProgressIndicator(color: t.primaryMid, strokeWidth: 2))
                        : _listItems.isEmpty
                            ? const _EmptyChat()
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n is ScrollEndNotification &&
                                      n.metrics.pixels <= n.metrics.minScrollExtent - 40 &&
                                      !_drawerOpen) {
                                    _toggleDrawer();
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: _listItems.length,
                                  itemBuilder: (_, i) {
                                    final item = _listItems[i];
                                    if (item is _DateDividerItem) return _DateDivider(label: item.label);
                                    if (item is _MsgListItem) return _buildBubble(item);
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                  ),
                  SizeTransition(
                    sizeFactor: _drawerSlide,
                    axisAlignment: -1,
                    child: _StatusDrawer(onClose: _toggleDrawer),
                  ),
                ],
              ),
            ),
            _ChatInputBar(
              controller: _inputController,
              onSend: _sendMessage,
              onPickGallery: () => _pickImage(ImageSource.gallery),
              onPickCamera: () => _pickImage(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_MsgListItem item) {
    final msg = item.msg;
    void onLongPress() => _showContextMenu(item.msgIndex);
    if (msg.isFile) return _FileBubble(msg: msg, item: item, onLongPress: onLongPress);
    if (msg.isImage) return _ImageBubble(msg: msg, item: item, onLongPress: onLongPress);
    return _ChatBubble(msg: msg, item: item, searchQuery: _searchQuery, onLongPress: onLongPress);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: t.pinkPale, shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: t.border, width: 1)),
            ),
            child: const Center(child: Text('💬', style: TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 14),
          Text('No messages yet', style: AppTextStyles.cardTitle.copyWith(color: t.textSecondary)),
          const SizedBox(height: 6),
          Text('Send the first one ♥', style: AppTextStyles.cardDesc),
        ],
      ),
    );
  }
}

// ── Chat Header ───────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.searchActive,
    required this.onStatusTap,
    required this.onSearchTap,
    required this.onStarTap,
  });
  final bool searchActive;
  final VoidCallback onStatusTap;
  final VoidCallback onSearchTap;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onStatusTap,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: t.bluePale, shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: AppColors.blueMid, width: 2)),
              ),
              child: const Center(child: Text('🥰', style: TextStyle(fontSize: 16))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppThemeScope.of(context).partnerLabel} ♡', style: AppTextStyles.chatName),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: AppColors.statusOnline, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('Online now',
                        style: AppTextStyles.moodLabel.copyWith(color: AppColors.statusOnline)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onStarTap,
            icon: Icon(Icons.star_outline_rounded, color: t.textMuted),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: onSearchTap,
            icon: Icon(
              searchActive ? Icons.search_off_rounded : Icons.search_rounded,
              color: searchActive ? AppThemeScope.of(context).primary : t.textMuted,
            ),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: onStatusTap,
            icon: Icon(Icons.expand_more_rounded, color: t.textMuted),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.matchCount,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController controller;
  final int matchCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Container(
      color: t.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              style: TextStyle(fontFamily: AppTextStyles.fontFamily, fontSize: 13, color: t.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search messages…',
                hintStyle: AppTextStyles.inputHint,
                filled: true,
                fillColor: t.surfaceMain,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                border: OutlineInputBorder(borderRadius: AppRadius.inputField, borderSide: BorderSide(color: t.border)),
                enabledBorder: OutlineInputBorder(borderRadius: AppRadius.inputField, borderSide: BorderSide(color: t.border)),
                focusedBorder: OutlineInputBorder(borderRadius: AppRadius.inputField, borderSide: BorderSide(color: t.primaryMid, width: 1.5)),
              ),
            ),
          ),
          if (controller.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('$matchCount', style: TextStyle(fontFamily: AppTextStyles.fontFamily, fontSize: 11, color: t.textMuted)),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close_rounded, size: 18, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Date Divider ──────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: t.border, thickness: 0.5)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.surfaceCream,
              borderRadius: AppRadius.chip,
              border: Border.all(color: t.borderCream),
            ),
            child: Text(label,
                style: AppTextStyles.widgetSince.copyWith(color: t.textFaint, fontSize: 10)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: t.border, thickness: 0.5)),
        ],
      ),
    );
  }
}

// ── Text Bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.msg,
    required this.item,
    required this.searchQuery,
    required this.onLongPress,
  });
  final ChatMessage msg;
  final _MsgListItem item;
  final String searchQuery;
  final VoidCallback onLongPress;

  Widget _buildText(BuildContext context, AppThemeData t) {
    final style = AppTextStyles.bubbleText.copyWith(color: t.textPrimary);
    if (searchQuery.isEmpty) return Text(msg.text, style: style);
    final lower = msg.text.toLowerCase();
    final lowerQ = searchQuery.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int matchStart;
    while ((matchStart = lower.indexOf(lowerQ, start)) != -1) {
      if (matchStart > start) spans.add(TextSpan(text: msg.text.substring(start, matchStart), style: style));
      spans.add(TextSpan(
        text: msg.text.substring(matchStart, matchStart + searchQuery.length),
        style: style.copyWith(backgroundColor: AppColors.pinkPale),
      ));
      start = matchStart + searchQuery.length;
    }
    if (start < msg.text.length) spans.add(TextSpan(text: msg.text.substring(start), style: style));
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final maxW = MediaQuery.of(context).size.width * 0.72;
    final bubbleColor = msg.isSent ? t.sentBubble : t.recvBubble;
    final borderColor = msg.isSent ? t.sentBorder : t.recvBorder;

    final bubbleBody = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: AppSpacing.bubblePadding,
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: msg.isSent ? AppRadius.bubbleSent : AppRadius.bubbleRecv,
          border: Border.all(color: borderColor),
        ),
        child: _buildText(context, t),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: item.isLastInGroup ? 10 : 3),
      child: Row(
        mainAxisAlignment: msg.isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isSent) ...[
            item.isFirstInGroup
                ? Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: t.bluePale, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.blueMid, width: 1.5),
                    ),
                    child: const Center(child: Text('🥰', style: TextStyle(fontSize: 12))),
                  )
                : const SizedBox(width: 26),
            const SizedBox(width: 6),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: msg.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(onLongPress: onLongPress, child: bubbleBody),
              if (msg.reactions.isNotEmpty)
                _ReactionsRow(reactions: msg.reactions, isSent: msg.isSent),
              if (item.isLastInGroup)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.isStarred) ...[
                        Icon(Icons.star_rounded, size: 9, color: AppColors.pinkDeep),
                        const SizedBox(width: 3),
                      ],
                      Text(msg.time, style: AppTextStyles.timestamp),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Image Bubble ──────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.msg, required this.item, required this.onLongPress});
  final ChatMessage msg;
  final _MsgListItem item;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final maxW = MediaQuery.of(context).size.width * 0.72;
    final imageFile = File(msg.imagePath!);

    return Padding(
      padding: EdgeInsets.only(bottom: item.isLastInGroup ? 10 : 3),
      child: Row(
        mainAxisAlignment: msg.isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isSent) ...[
            item.isFirstInGroup
                ? Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: t.bluePale, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.blueMid, width: 1.5)),
                    child: const Center(child: Text('🥰', style: TextStyle(fontSize: 12))),
                  )
                : const SizedBox(width: 26),
            const SizedBox(width: 6),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: msg.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showFullImage(context, imageFile),
                onLongPress: onLongPress,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: ClipRRect(
                    borderRadius: msg.isSent ? AppRadius.bubbleSent : AppRadius.bubbleRecv,
                    child: imageFile.existsSync()
                        ? Image.file(imageFile, fit: BoxFit.cover, cacheWidth: 600,
                            errorBuilder: (_, __, ___) => _brokenImage(context))
                        : _brokenImage(context),
                  ),
                ),
              ),
              if (msg.reactions.isNotEmpty)
                _ReactionsRow(reactions: msg.reactions, isSent: msg.isSent),
              if (item.isLastInGroup)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(msg.time, style: AppTextStyles.timestamp),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _brokenImage(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Container(
      width: 160, height: 120,
      decoration: BoxDecoration(color: t.surfaceCream, borderRadius: AppRadius.card),
      child: Icon(Icons.broken_image_rounded, color: t.textFaint, size: 32),
    );
  }

  void _showFullImage(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: AppRadius.card,
              child: Image.file(file, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppThemeScope.of(context).surface, shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 16, color: AppThemeScope.of(context).textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File Bubble ───────────────────────────────────────────────────────────────

class _FileBubble extends StatelessWidget {
  const _FileBubble({required this.msg, required this.item, required this.onLongPress});
  final ChatMessage msg;
  final _MsgListItem item;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    final maxW = MediaQuery.of(context).size.width * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: item.isLastInGroup ? 10 : 3),
      child: Row(
        mainAxisAlignment: msg.isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isSent) ...[
            item.isFirstInGroup
                ? Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: t.bluePale, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.blueMid, width: 1.5)),
                    child: const Center(child: Text('🥰', style: TextStyle(fontSize: 12))),
                  )
                : const SizedBox(width: 26),
            const SizedBox(width: 6),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: msg.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: onLongPress,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.surface, borderRadius: AppRadius.card,
                      border: Border.all(color: t.border), boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(color: t.pinkPale, borderRadius: AppRadius.serviceIcon),
                          child: const Icon(Icons.audio_file_rounded, size: 18, color: AppColors.pinkDeep),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.fileName ?? 'file',
                                  style: AppTextStyles.cardTitle.copyWith(fontSize: 11),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(msg.fileSize ?? '', style: AppTextStyles.fileMeta),
                              const SizedBox(height: 2),
                              Text('Download',
                                  style: AppTextStyles.fileMeta.copyWith(color: AppColors.blueDeep)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (item.isLastInGroup)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(msg.time, style: AppTextStyles.timestamp),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reactions ─────────────────────────────────────────────────────────────────

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.reactions, required this.isSent});
  final List<String> reactions;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: reactions.map((r) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: t.surfaceBlush,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSent ? AppColors.pinkDeep : AppColors.borderBlue, width: 0.8),
          ),
          child: Text(r, style: const TextStyle(fontSize: 12)),
        )).toList(),
      ),
    );
  }
}

// ── Context Menu Sheet ────────────────────────────────────────────────────────

class _ContextMenuSheet extends StatelessWidget {
  const _ContextMenuSheet({
    required this.msg,
    required this.onReact,
    required this.onStar,
    required this.onDelete,
  });
  final ChatMessage msg;
  final ValueChanged<String> onReact;
  final VoidCallback onStar;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['♥', '😂', '😮', '😢', '👍', '🔥'].map((e) => GestureDetector(
              onTap: () => onReact(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: msg.reactions.contains(e) ? t.primaryPale : t.surfaceBlush,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: msg.reactions.contains(e) ? t.primary : t.border,
                  ),
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Divider(color: t.border),
          ListTile(
            dense: true,
            leading: Icon(
              msg.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: AppColors.pinkDeep, size: 20,
            ),
            title: Text(msg.isStarred ? 'Unstar' : 'Star',
                style: TextStyle(fontFamily: AppTextStyles.fontFamily, fontSize: 13, color: t.textPrimary)),
            onTap: onStar,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            title: Text('Delete',
                style: TextStyle(fontFamily: AppTextStyles.fontFamily, fontSize: 13, color: t.textPrimary)),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Starred Messages Panel ────────────────────────────────────────────────────

class _StarredPanel extends StatelessWidget {
  const _StarredPanel({required this.messages});
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.pinkDeep, size: 18),
                const SizedBox(width: 8),
                Text('Starred Messages',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 15)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, size: 20, color: t.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_outline_rounded, size: 40, color: t.textFaint),
                        const SizedBox(height: 10),
                        Text('No starred messages yet',
                            style: AppTextStyles.cardDesc.copyWith(color: t.textFaint)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: m.isSent ? t.sentBubble : t.recvBubble,
                          borderRadius: AppRadius.card,
                          border: const Border(
                            left: BorderSide(color: AppColors.pinkDeep, width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(
                                m.isSent ? 'You' : AppThemeScope.of(context).partnerLabel,
                                style: AppTextStyles.moodLabel.copyWith(color: t.primary, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(m.time, style: AppTextStyles.timestamp),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              m.text,
                              style: AppTextStyles.bubbleText.copyWith(color: AppThemeScope.of(context).textPrimary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Chat Input Bar ────────────────────────────────────────────────────────────

class _ChatInputBar extends StatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickGallery,
    required this.onPickCamera,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  @override
  State<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<_ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border, width: 1.0)),
      ),
      padding: AppSpacing.inputBarPadding,
      child: Row(
        children: [
          _IconBtn(icon: Icons.attach_file_rounded, onTap: widget.onPickGallery),
          const SizedBox(width: 6),
          _IconBtn(icon: Icons.camera_alt_rounded, onTap: widget.onPickCamera),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: TextStyle(fontFamily: AppTextStyles.fontFamily, fontSize: 13, color: t.textPrimary),
              decoration: InputDecoration(
                hintText: 'Message…',
                filled: true,
                fillColor: t.surfaceMain,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: AppRadius.inputField, borderSide: BorderSide(color: t.border)),
                enabledBorder: OutlineInputBorder(borderRadius: AppRadius.inputField, borderSide: BorderSide(color: t.border)),
                focusedBorder: OutlineInputBorder(borderRadius: AppRadius.inputField, borderSide: BorderSide(color: t.primaryMid, width: 1.5)),
                hintStyle: AppTextStyles.inputHint,
              ),
              onSubmitted: (_) => widget.onSend(),
            ),
          ),
          if (_hasText) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onSend,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: t.primaryPale, borderRadius: AppRadius.serviceIcon, border: AppBorders.defaultBorder,
        ),
        child: Icon(icon, size: 16, color: t.textMuted),
      ),
    );
  }
}

// ── Status Drawer ─────────────────────────────────────────────────────────────

class _StatusDrawer extends StatelessWidget {
  const _StatusDrawer({required this.onClose});
  final VoidCallback onClose;

  Color _dotColor(String status) {
    switch (status) {
      case 'online':  return AppColors.statusOnline;
      case 'playing': return AppColors.statusPlaying;
      default:        return AppColors.statusOffline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border.all(color: t.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: t.gradientCard,
              border: Border(bottom: BorderSide(color: t.border, width: 1.0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text('Online Status', style: AppTextStyles.serviceName),
                const Spacer(),
                GestureDetector(onTap: onClose, child: Text('⚙ Manage', style: AppTextStyles.moodLabel)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: t.textMuted),
                ),
              ],
            ),
          ),
          ...List.generate(_services.length, (i) {
            final s = _services[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: i < _services.length - 1
                  ? BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5)))
                  : null,
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: t.surfaceCream, borderRadius: AppRadius.serviceIcon),
                    child: Center(child: Text(s.icon, style: const TextStyle(fontSize: 14))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.name, style: AppTextStyles.serviceName)),
                  Text(s.detail, style: AppTextStyles.moodLabel.copyWith(fontSize: 10)),
                  const SizedBox(width: 8),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: _dotColor(s.status), shape: BoxShape.circle),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
