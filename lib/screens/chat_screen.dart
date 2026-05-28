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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  List<Message> _messages = [];
  bool _isSending = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.peer.messages);
    widget.nearbyService.onMessageReceived = (peerId, message) {
      if (peerId == widget.peer.id && mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
        HapticFeedback.lightImpact();
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputController.clear();

    final success = await widget.nearbyService.sendMessage(widget.peer.id, text);
    if (success) {
      setState(() {
        _messages = List.from(widget.peer.messages);
      });
      _scrollToBottom();
      HapticFeedback.selectionClick();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send. Are you still connected?'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    setState(() => _isSending = false);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(widget.peer.emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peer.name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.peer.isConnected
                            ? const Color(0xFF3ECFCF)
                            : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.peer.isConnected
                          ? 'Connected via Bluetooth'
                          : 'Disconnected',
                      style: GoogleFonts.outfit(
                        color: widget.peer.isConnected
                            ? const Color(0xFF3ECFCF)
                            : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2435),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('✈️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.peer.emoji}',
              style: const TextStyle(fontSize: 48),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(
              'Say hi to ${widget.peer.name}!',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Messages are sent peer-to-peer\nno internet required ✈️',
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final prev = index > 0 ? _messages[index - 1] : null;
          final showDate = prev == null ||
              !_isSameDay(msg.timestamp, prev.timestamp);
          final showSender = prev == null ||
              prev.senderId != msg.senderId ||
              msg.timestamp.difference(prev.timestamp).inMinutes > 5;

          return Column(
            children: [
              if (showDate) _buildDateDivider(msg.timestamp),
              _MessageBubble(
                message: msg,
                showSender: showSender && !msg.isMe,
                peerName: widget.peer.name,
                peerEmoji: widget.peer.emoji,
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.07))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: GoogleFonts.outfit(
                color: Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.07))),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141828),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? const Color(0xFF6C63FF).withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Message ${widget.peer.name}...',
                  hintStyle: GoogleFonts.outfit(
                    color: Colors.white24,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (text) {
                  setState(() => _isTyping = text.isNotEmpty);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: 200.ms,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: _isTyping
                    ? const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _isTyping ? null : const Color(0xFF1E2435),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isTyping
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: _isTyping ? Colors.white : Colors.white30,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'TODAY';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
    return DateFormat('MMM d').format(date).toUpperCase();
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool showSender;
  final String peerName;
  final String peerEmoji;

  const _MessageBubble({
    required this.message,
    required this.showSender,
    required this.peerName,
    required this.peerEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('h:mm a').format(message.timestamp);

    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? 12 : 3,
        bottom: 2,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 4),
              child: Text(
                peerName,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF3ECFCF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showSender)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(peerEmoji,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 40),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF5A54DB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : const Color(0xFF1A1F33),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
