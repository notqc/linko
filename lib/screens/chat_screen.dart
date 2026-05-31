import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../services/nearby_service.dart';

class ChatScreen extends StatefulWidget {
  final Peer peer;
  final NearbyService nearbyService;
  const ChatScreen({super.key, required this.peer, required this.nearbyService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl  = ScrollController();
  final FocusNode              _focusNode   = FocusNode();
  List<Message> _messages = [];
  bool _isSending = false;
  bool _hasText   = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.nearbyService.onMessageReceived = (peerId, message) {
      if (peerId == widget.peer.id && mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
        HapticFeedback.lightImpact();
      }
    };
  }

  Future<void> _loadMessages() async {
    // Load from SQLite first (history)
    final saved = await widget.nearbyService.loadMessages(widget.peer.id);
    // Merge with in-memory (current session)
    final inMemory = widget.peer.messages;
    final all = {...saved, ...inMemory}.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (mounted) {
      setState(() { _messages = all; _isLoading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    Future.delayed(100.ms, () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: 280.ms, curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _inputCtrl.clear();
    setState(() => _hasText = false);

    final ok = await widget.nearbyService.sendMessage(widget.peer.id, text);
    if (ok) {
      setState(() => _messages = List.from(widget.peer.messages));
      _scrollToBottom();
      HapticFeedback.selectionClick();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send', style: GoogleFonts.outfit()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
    setState(() => _isSending = false);
  }

  Future<void> _confirmClearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear chat?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete all messages with ${widget.peer.name}.',
            style: GoogleFonts.outfit(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Clear', style: GoogleFonts.outfit(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await widget.nearbyService.clearChat(widget.peer.id);
      setState(() => _messages.clear());
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          Expanded(child: _isLoading ? _buildLoading() : _buildMessageList()),
          _buildInputBar(),
        ]),
      ),
    );
  }

  Widget _buildLoading() => const Center(
    child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
  );

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(widget.peer.emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.peer.name,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                color: widget.peer.isConnected ? const Color(0xFF3ECFCF) : Colors.white24,
                shape: BoxShape.circle,
              )),
            const SizedBox(width: 5),
            Text(
              widget.peer.isConnected ? 'Connected · RSA Encrypted' : 'Offline · showing history',
              style: GoogleFonts.outfit(
                color: widget.peer.isConnected ? const Color(0xFF3ECFCF) : Colors.white38,
                fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ]),
        ])),
        // More options
        GestureDetector(
          onTap: () => _showOptions(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 18),
          ),
        ),
      ]),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          _OptionTile(icon: Icons.delete_outline_rounded, label: 'Clear chat',
              color: Colors.red, onTap: () { Navigator.pop(context); _confirmClearChat(); }),
          _OptionTile(icon: Icons.lock_outline_rounded, label: 'RSA-2048 Encrypted',
              color: const Color(0xFF3ECFCF), onTap: () {
                Navigator.pop(context);
                _showEncryptionInfo();
              }),
        ]),
      ),
    );
  }

  void _showEncryptionInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🔐', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('End-to-End Encrypted', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _infoRow('Algorithm', 'RSA-2048 with OAEP'),
          _infoRow('Key exchange', 'On connection (handshake)'),
          _infoRow('Who can read', 'Only you and ${widget.peer.name}'),
          _infoRow('Server access', 'None — peer-to-peer only'),
          _infoRow('Internet used', 'None'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Got it', style: GoogleFonts.outfit(color: const Color(0xFF6C63FF)))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label: ', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
      Expanded(child: Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.peer.emoji, style: const TextStyle(fontSize: 48))
              .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 14),
          Text('Say hi to ${widget.peer.name}!',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF3ECFCF), size: 13),
            const SizedBox(width: 4),
            Text('Messages are RSA-2048 encrypted',
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
          ]),
        ]),
      );
    }

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final msg  = _messages[i];
          final prev = i > 0 ? _messages[i - 1] : null;
          final showDate   = prev == null || !_isSameDay(msg.timestamp, prev.timestamp);
          final showAvatar = prev == null || prev.senderId != msg.senderId ||
              msg.timestamp.difference(prev.timestamp).inMinutes > 5;
          return Column(children: [
            if (showDate) _dateDivider(msg.timestamp),
            _MessageBubble(
              message:     msg,
              showAvatar:  showAvatar && !msg.isMe,
              peerEmoji:   widget.peer.emoji,
              peerName:    widget.peer.name,
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, end: 0),
          ]);
        },
      ),
    );
  }

  Widget _dateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.07))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_formatDate(date),
            style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.07))),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141828),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
              maxLines: 4, minLines: 1,
              decoration: InputDecoration(
                hintText: 'Message ${widget.peer.name}...',
                hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (t) => setState(() => _hasText = t.isNotEmpty),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _sendMessage,
          child: AnimatedContainer(
            duration: 180.ms,
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: _hasText
                  ? const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              color: _hasText ? null : const Color(0xFF1E2435),
              borderRadius: BorderRadius.circular(15),
              boxShadow: _hasText ? [BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 12, offset: const Offset(0, 4))] : [],
            ),
            child: _isSending
                ? const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : Icon(Icons.arrow_upward_rounded,
                    color: _hasText ? Colors.white : Colors.white30, size: 20),
          ),
        ),
      ]),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (_isSameDay(d, now)) return 'TODAY';
    if (_isSameDay(d, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
    return DateFormat('MMM d, yyyy').format(d).toUpperCase();
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool    showAvatar;
  final String  peerEmoji;
  final String  peerName;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.peerEmoji,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('h:mm a').format(message.timestamp);

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 12 : 3, bottom: 2,
        left: isMe ? 52 : 0, right: isMe ? 0 : 52,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showAvatar && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 4),
              child: Text(peerName,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF3ECFCF), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(peerEmoji, style: const TextStyle(fontSize: 15))),
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 38),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe ? const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF5A54DB)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ) : null,
                    color: isMe ? null : const Color(0xFF1A1F33),
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: isMe ? [BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.25),
                      blurRadius: 8, offset: const Offset(0, 3),
                    )] : [],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Relay indicator
                      if (message.isRelayed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.sync_alt_rounded, size: 10, color: Colors.white38),
                            const SizedBox(width: 3),
                            Text('relayed', style: GoogleFonts.outfit(
                                color: Colors.white38, fontSize: 9)),
                          ]),
                        ),
                      Text(message.content,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, height: 1.4)),
                      const SizedBox(height: 3),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_rounded, size: 9, color: Colors.white30),
                        const SizedBox(width: 3),
                        Text(time,
                          style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _OptionTile({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
