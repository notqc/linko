import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/message.dart';
import '../services/nearby_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final NearbyService nearbyService;
  const HomeScreen({super.key, required this.nearbyService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<Peer> _peers = [];
  bool _isScanning = false;
  late AnimationController _pulseController;
  final Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _setupCallbacks();
    _requestPermissionsAndStart();
  }

  void _setupCallbacks() {
    widget.nearbyService.onPeerFound = (peer) {
      if (mounted) setState(() => _peers.add(peer));
    };
    widget.nearbyService.onPeerLost = (id) {
      if (mounted) setState(() => _peers.removeWhere((p) => p.id == id));
    };
    widget.nearbyService.onPeerConnected = (peer) {
      if (mounted) setState(() {});
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${peer.emoji} ${peer.name} connected!'),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    };
    widget.nearbyService.onPeerDisconnected = (id) {
      if (mounted) setState(() {});
    };
    widget.nearbyService.onMessageReceived = (peerId, message) {
      if (mounted) {
        setState(() {
          _unreadCounts[peerId] = (_unreadCounts[peerId] ?? 0) + 1;
        });
        HapticFeedback.lightImpact();
      }
    };
  }

  Future<void> _requestPermissionsAndStart() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];
    await permissions.request();
    await _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);
    final success = await widget.nearbyService.startHosting();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not start scanning. Check permissions.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _isScanning = false);
    }
  }

  void _openChat(Peer peer) {
    setState(() => _unreadCounts.remove(peer.id));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peer: peer,
          nearbyService: widget.nearbyService,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.nearbyService.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildScanStatus(),
            Expanded(child: _buildPeerList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('✈️', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SkyLink',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '${widget.nearbyService.myEmoji} ${widget.nearbyService.myName}',
                style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2435),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isScanning
                          ? Color.lerp(
                              const Color(0xFF3ECFCF),
                              const Color(0xFF6C63FF),
                              _pulseController.value,
                            )
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isScanning ? 'Scanning' : 'Idle',
                  style: GoogleFonts.outfit(
                    color: Colors.white60,
                    fontSize: 12,
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

  Widget _buildScanStatus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _peers.isEmpty ? 'Searching for crewmates...' : 'Nearby Passengers',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 4),
          Text(
            _peers.isEmpty
                ? 'Make sure your friends also have SkyLink open'
                : '${_peers.length} found · tap to connect & chat',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerList() {
    if (_peers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color.lerp(
                      const Color(0xFF6C63FF).withOpacity(0.3),
                      const Color(0xFF3ECFCF).withOpacity(0.3),
                      _pulseController.value,
                    )!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color.lerp(
                          const Color(0xFF6C63FF).withOpacity(0.5),
                          const Color(0xFF3ECFCF).withOpacity(0.5),
                          _pulseController.value,
                        )!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(
                                const Color(0xFF6C63FF),
                                const Color(0xFF3ECFCF),
                                _pulseController.value,
                              )!,
                              const Color(0xFF3ECFCF),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Text('📡', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No one nearby yet',
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask your friends to open SkyLink',
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      itemCount: _peers.length,
      itemBuilder: (context, index) {
        final peer = _peers[index];
        final unread = _unreadCounts[peer.id] ?? 0;
        return _PeerCard(
          peer: peer,
          unreadCount: unread,
          onTap: () async {
            if (!peer.isConnected) {
              HapticFeedback.mediumImpact();
              await widget.nearbyService.connectToPeer(peer.id);
            } else {
              _openChat(peer);
            }
          },
        ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.2, end: 0);
      },
    );
  }
}

class _PeerCard extends StatelessWidget {
  final Peer peer;
  final int unreadCount;
  final VoidCallback onTap;

  const _PeerCard({
    required this.peer,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141828),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: peer.isConnected
                ? const Color(0xFF6C63FF).withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: peer.isConnected
                          ? [const Color(0xFF6C63FF), const Color(0xFF3ECFCF)]
                          : [const Color(0xFF1E2435), const Color(0xFF252B40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(peer.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                if (peer.isConnected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3ECFCF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF141828),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.name,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: peer.isConnected
                              ? const Color(0xFF3ECFCF)
                              : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        peer.isConnected ? 'Connected · tap to chat' : 'Tap to connect',
                        style: GoogleFonts.outfit(
                          color: peer.isConnected
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
            if (unreadCount > 0)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            else
              Icon(
                peer.isConnected ? Icons.chat_bubble_rounded : Icons.bluetooth_rounded,
                color: peer.isConnected
                    ? const Color(0xFF6C63FF)
                    : Colors.white24,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
