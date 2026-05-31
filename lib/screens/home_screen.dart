import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/message.dart';
import '../services/nearby_service.dart';
import '../widgets/pin_dialog.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final NearbyService nearbyService;
  const HomeScreen({super.key, required this.nearbyService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<Peer>       _nearbyPeers  = [];
  List<Peer>             _knownPeers   = [];
  bool                   _isScanning   = false;
  final Map<String, int> _unreadCounts = {};
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _setupCallbacks();
    _requestPermissionsAndStart();
    _loadKnownPeers();
  }

  Future<void> _loadKnownPeers() async {
    final peers = await widget.nearbyService.loadKnownPeers();
    if (mounted) setState(() => _knownPeers = peers);
  }

  void _setupCallbacks() {
    final ns = widget.nearbyService;
    ns.onPeerFound = (peer) {
      if (mounted && !_nearbyPeers.any((p) => p.id == peer.id)) {
        setState(() => _nearbyPeers.add(peer));
      }
    };
    ns.onPeerLost = (id) {
      if (mounted) setState(() => _nearbyPeers.removeWhere((p) => p.id == id));
    };
    ns.onPinRequired = (peerId, peerName, pin) {
      if (!mounted) return;
      final peer = ns.peers[peerId];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PinDialog(
          peerName:  peerName,
          peerEmoji: peer?.emoji ?? '👤',
          pin:       pin,
          onConfirm: () {
            Navigator.pop(context);
            ns.confirmPin(peerId);
            HapticFeedback.mediumImpact();
          },
          onReject: () {
            Navigator.pop(context);
            ns.rejectPin(peerId);
          },
        ),
      );
    };
    ns.onPeerConnected = (peer) {
      if (mounted) setState(() {});
      _showSnack('${peer.emoji} ${peer.name} connected!', const Color(0xFF6C63FF));
    };
    ns.onPeerDisconnected = (id) {
      if (mounted) setState(() {});
    };
    ns.onPinRejected = (id) {
      _showSnack('Connection rejected', Colors.red.shade700);
    };
    ns.onMessageReceived = (peerId, message) {
      if (mounted) setState(() => _unreadCounts[peerId] = (_unreadCounts[peerId] ?? 0) + 1);
      HapticFeedback.lightImpact();
    };
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _requestPermissionsAndStart() async {
    await [
      Permission.bluetooth, Permission.bluetoothAdvertise,
      Permission.bluetoothConnect, Permission.bluetoothScan,
      Permission.locationWhenInUse, Permission.nearbyWifiDevices,
    ].request();
    setState(() => _isScanning = true);
    final ok = await widget.nearbyService.startHosting();
    if (!ok && mounted) {
      setState(() => _isScanning = false);
      _showSnack('Could not start scanning — check permissions', Colors.red.shade700);
    }
  }

  void _openChat(Peer peer) {
    setState(() => _unreadCounts.remove(peer.id));
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(peer: peer, nearbyService: widget.nearbyService)));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    widget.nearbyService.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: Text('💬', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Linko', style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text('${widget.nearbyService.myEmoji} ${widget.nearbyService.myName}',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
        ]),
        const Spacer(),
        // Scanning indicator
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2435),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _isScanning
                      ? Color.lerp(const Color(0xFF3ECFCF), const Color(0xFF6C63FF), _pulseCtrl.value)
                      : Colors.grey,
                  shape: BoxShape.circle,
                )),
              const SizedBox(width: 6),
              Text(_isScanning ? 'Scanning' : 'Idle',
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      children: [
        // Nearby section
        _sectionLabel('NEARBY', Icons.radar_rounded),
        const SizedBox(height: 12),
        if (_nearbyPeers.isEmpty) _emptyNearby() else ..._nearbyPeers.asMap().entries.map((e) =>
          _PeerCard(
            peer: e.value,
            unreadCount: _unreadCounts[e.value.id] ?? 0,
            onTap: () async {
              if (!e.value.isConnected) {
                HapticFeedback.mediumImpact();
                await widget.nearbyService.connectToPeer(e.value.id);
              } else if (e.value.isPinVerified) {
                _openChat(e.value);
              }
            },
          ).animate().fadeIn(delay: (e.key * 70).ms).slideX(begin: 0.2, end: 0)
        ),

        // Known peers (history)
        if (_knownPeers.isNotEmpty) ...[
          const SizedBox(height: 28),
          _sectionLabel('RECENT CHATS', Icons.history_rounded),
          const SizedBox(height: 12),
          ..._knownPeers.map((peer) {
            final live = _nearbyPeers.firstWhere(
                (p) => p.id == peer.id, orElse: () => peer);
            return _PeerCard(
              peer: live,
              unreadCount: _unreadCounts[peer.id] ?? 0,
              isHistory: true,
              onTap: () => live.isConnected && live.isPinVerified
                  ? _openChat(live) : null,
            );
          }),
        ],
      ],
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF6C63FF), size: 16),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.outfit(
          color: Colors.white38, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
    ]);
  }

  Widget _emptyNearby() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFF6C63FF).withOpacity(0.2),
                  const Color(0xFF3ECFCF).withOpacity(0.2),
                  _pulseCtrl.value,
                )!, width: 2,
              ),
            ),
            child: Center(
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    Color.lerp(const Color(0xFF6C63FF), const Color(0xFF3ECFCF), _pulseCtrl.value)!,
                    const Color(0xFF3ECFCF),
                  ]),
                ),
                child: const Center(child: Text('📡', style: TextStyle(fontSize: 26))),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Looking for people nearby...', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 15)),
        const SizedBox(height: 6),
        Text('Make sure friends have Linko open', style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12)),
      ]),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final Peer peer;
  final int unreadCount;
  final bool isHistory;
  final VoidCallback? onTap;

  const _PeerCard({
    required this.peer,
    required this.unreadCount,
    this.isHistory = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final connected  = peer.isConnected;
    final verified   = peer.isPinVerified;

    String statusText;
    Color  statusColor;
    if (!connected)       { statusText = isHistory ? 'Not nearby' : 'Tap to connect'; statusColor = Colors.white24; }
    else if (!verified)   { statusText = 'Verifying PIN...'; statusColor = Colors.amber; }
    else                  { statusText = 'Connected · tap to chat'; statusColor = const Color(0xFF3ECFCF); }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141828),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: verified
                ? const Color(0xFF6C63FF).withOpacity(0.35)
                : Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: verified
                    ? [const Color(0xFF6C63FF), const Color(0xFF3ECFCF)]
                    : [const Color(0xFF1E2435), const Color(0xFF252B40)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(peer.emoji, style: const TextStyle(fontSize: 24))),
            ),
            if (connected) Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 13, height: 13,
                decoration: BoxDecoration(
                  color: verified ? const Color(0xFF3ECFCF) : Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF141828), width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(peer.name,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(statusText,
                style: GoogleFonts.outfit(color: statusColor, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ])),
          if (unreadCount > 0)
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(child: Text(unreadCount > 9 ? '9+' : '$unreadCount',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
            )
          else
            Icon(
              verified ? Icons.chat_bubble_rounded : Icons.lock_rounded,
              color: verified ? const Color(0xFF6C63FF) : Colors.white24, size: 18,
            ),
        ]),
      ),
    );
  }
}
