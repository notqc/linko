import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../utils/rsa_helper.dart';
import '../utils/database_helper.dart';

typedef OnPeerFound        = void Function(Peer peer);
typedef OnPeerLost         = void Function(String peerId);
typedef OnPeerConnected    = void Function(Peer peer);
typedef OnPeerDisconnected = void Function(String peerId);
typedef OnMessageReceived  = void Function(String peerId, Message message);
typedef OnPinRequired      = void Function(String peerId, String peerName, String pin);
typedef OnPinVerified      = void Function(String peerId);
typedef OnPinRejected      = void Function(String peerId);

class NearbyService {
  static const String _serviceId = 'com.linko.chat';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;
  static const int _maxTtl = 5;          // max relay hops
  static const int _maxMessageBytes = 200; // RSA 2048 OAEP safe limit

  String? _myId;
  String? _myName;
  String? _myEmoji;
  RSAPublicKey?  _myPublicKey;
  RSAPrivateKey? _myPrivateKey;

  final Map<String, Peer>   _peers       = {};
  final Set<String>         _seenMsgIds  = {}; // dedup for relay
  final Map<String, String> _pendingPins = {}; // peerId → pin

  bool _isAdvertising = false;
  bool _isDiscovering = false;

  // ── Callbacks ──────────────────────────────────────────────
  OnPeerFound?        onPeerFound;
  OnPeerLost?         onPeerLost;
  OnPeerConnected?    onPeerConnected;
  OnPeerDisconnected? onPeerDisconnected;
  OnMessageReceived?  onMessageReceived;
  OnPinRequired?      onPinRequired;
  OnPinVerified?      onPinVerified;
  OnPinRejected?      onPinRejected;

  // ── Getters ────────────────────────────────────────────────
  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  String get myId    => _myId ?? '';
  String get myName  => _myName ?? '';
  String get myEmoji => _myEmoji ?? '💬';
  String get myPublicKeyPem =>
      _myPublicKey != null ? RSAHelper.publicKeyToString(_myPublicKey!) : '';

  // ── Init ───────────────────────────────────────────────────
  Future<void> initialize(String name, String emoji) async {
    final prefs = await SharedPreferences.getInstance();

    // Device ID
    _myId = prefs.getString('my_id') ?? const Uuid().v4();
    await prefs.setString('my_id', _myId!);
    _myName  = name;
    _myEmoji = emoji;

    // RSA key pair — generate once, persist as strings
    final pubStored  = prefs.getString('rsa_public');
    final privStored = prefs.getString('rsa_private');
    if (pubStored != null && privStored != null) {
      _myPublicKey  = RSAHelper.publicKeyFromString(pubStored);
      _myPrivateKey = RSAHelper.privateKeyFromString(privStored);
    } else {
      final pair = RSAHelper.generateKeyPair();
      _myPublicKey  = pair.publicKey;
      _myPrivateKey = pair.privateKey;
      await prefs.setString('rsa_public',  RSAHelper.publicKeyToString(_myPublicKey!));
      await prefs.setString('rsa_private', RSAHelper.privateKeyToString(_myPrivateKey!));
    }
  }

  // ── Start/Stop ─────────────────────────────────────────────
  Future<bool> startHosting() async {
    try {
      await Nearby().startAdvertising(
        _myName!,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult:    _onConnectionResult,
        onDisconnected:        _onDisconnected,
        serviceId: _serviceId,
      );
      _isAdvertising = true;
      await startDiscovery();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        _myName!,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          if (_peers.containsKey(id)) return;
          final peer = Peer(id: id, name: name, emoji: Peer.emojiForName(name));
          _peers[id] = peer;
          onPeerFound?.call(peer);
        },
        onEndpointLost: (id) {
          _peers.remove(id);
          onPeerLost?.call(id!);
        },
        serviceId: _serviceId,
      );
      _isDiscovering = true;
      return true;
    } catch (_) { return false; }
  }

  Future<bool> connectToPeer(String peerId) async {
    try {
      await Nearby().requestConnection(
        _myName!,
        peerId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult:    _onConnectionResult,
        onDisconnected:        _onDisconnected,
      );
      return true;
    } catch (_) { return false; }
  }

  Future<void> stopAll() async {
    if (_isAdvertising) await Nearby().stopAdvertising();
    if (_isDiscovering) await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _isAdvertising = false;
    _isDiscovering = false;
  }

  // ── Connection lifecycle ───────────────────────────────────
  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // Accept connection immediately — PIN happens after
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (_, __) {},
    );

    if (!_peers.containsKey(id)) {
      _peers[id] = Peer(id: id, name: info.endpointName,
          emoji: Peer.emojiForName(info.endpointName));
    }

    // Generate a 6-digit PIN for this pairing
    final pin = (100000 + Random.secure().nextInt(900000)).toString();
    _pendingPins[id] = pin;
    _peers[id]!.pendingPin = pin;
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      final peer = _peers[id];
      if (peer == null) return;
      peer.isConnected = true;

      // Step 1: Exchange public keys
      _sendHandshake(id);

      // Step 2: Trigger PIN UI
      onPinRequired?.call(id, peer.name, _pendingPins[id] ?? '------');
    }
  }

  void _onDisconnected(String id) {
    _peers[id]?.isConnected    = false;
    _peers[id]?.isPinVerified  = false;
    onPeerDisconnected?.call(id);
  }

  // ── Handshake (key exchange) ───────────────────────────────
  void _sendHandshake(String peerId) {
    final payload = jsonEncode({
      'type':      'handshake',
      'senderId':  _myId,
      'name':      _myName,
      'emoji':     _myEmoji,
      'publicKey': myPublicKeyPem,
    });
    _sendRaw(peerId, payload);
  }

  // ── PIN verification ───────────────────────────────────────
  void confirmPin(String peerId) {
    // User confirmed PINs match — send confirmation
    final payload = jsonEncode({'type': 'pin_ok', 'senderId': _myId});
    _sendRaw(peerId, payload);
    _peers[peerId]?.isPinVerified = true;
    onPeerConnected?.call(_peers[peerId]!);
  }

  void rejectPin(String peerId) {
    final payload = jsonEncode({'type': 'pin_reject', 'senderId': _myId});
    _sendRaw(peerId, payload);
    Nearby().disconnectFromEndpoint(peerId);
    onPinRejected?.call(peerId);
  }

  // ── Send message ───────────────────────────────────────────
  Future<bool> sendMessage(String peerId, String content) async {
    final peer = _peers[peerId];
    if (peer == null || !peer.isConnected || !peer.isPinVerified) return false;
    if (peer.publicKeyPem == null) return false;

    final msg = Message(
      id:         const Uuid().v4(),
      senderId:   _myId!,
      senderName: _myName!,
      content:    content,
      timestamp:  DateTime.now(),
      isMe:       true,
    );

    try {
      final recipientKey = RSAHelper.publicKeyFromString(peer.publicKeyPem!);
      final encrypted    = RSAHelper.encrypt(content, recipientKey);
      final wirePayload  = jsonEncode({
        'type': 'message',
        ...msg.toWireJson(encrypted),
      });
      _sendRaw(peerId, wirePayload);

      // Save to DB and memory
      peer.messages.add(msg);
      await DatabaseHelper.instance.insertMessage(msg, peerId, peer.name);
      await DatabaseHelper.instance.upsertPeer(peer);
      return true;
    } catch (_) { return false; }
  }

  // ── Relay logic ────────────────────────────────────────────
  void _relayMessage(Map<String, dynamic> envelope) {
    final destinationId = envelope['destinationId'] as String;
    final ttl           = (envelope['ttl'] as int) - 1;
    if (ttl <= 0) return;

    final visited = List<String>.from(envelope['visited']);
    visited.add(_myId!);
    envelope['ttl']     = ttl;
    envelope['visited'] = visited;

    // Direct delivery if destination is connected
    if (_peers[destinationId]?.isConnected == true) {
      _sendRaw(destinationId, jsonEncode(envelope));
      return;
    }

    // Forward to all connected peers not already visited
    for (final peer in _peers.values) {
      if (peer.isConnected && peer.isPinVerified && !visited.contains(peer.id)) {
        _sendRaw(peer.id, jsonEncode(envelope));
      }
    }
  }

  // ── Receive payload ────────────────────────────────────────
  void _onPayloadReceived(String id, Payload payload) async {
    if (payload.type != PayloadType.BYTES) return;
    final jsonStr = utf8.decode(payload.bytes!);
    Map<String, dynamic> data;
    try { data = jsonDecode(jsonStr); } catch (_) { return; }

    final type = data['type'] as String?;

    switch (type) {
      case 'handshake':
        _handleHandshake(id, data);
        break;

      case 'pin_ok':
        _peers[id]?.isPinVerified = true;
        onPinVerified?.call(id);
        onPeerConnected?.call(_peers[id]!);
        break;

      case 'pin_reject':
        Nearby().disconnectFromEndpoint(id);
        onPinRejected?.call(id);
        break;

      case 'message':
        await _handleMessage(id, data, isRelayed: false);
        break;

      case 'relay':
        await _handleRelay(data);
        break;
    }
  }

  void _handleHandshake(String peerId, Map<String, dynamic> data) {
    final peer = _peers[peerId];
    if (peer == null) return;
    peer.name         = data['name'] ?? peer.name;
    peer.emoji        = data['emoji'] ?? peer.emoji;
    peer.publicKeyPem = data['publicKey'];
  }

  Future<void> _handleMessage(String fromId, Map<String, dynamic> data,
      {required bool isRelayed}) async {
    final msgId = data['id'] as String?;
    if (msgId == null || _seenMsgIds.contains(msgId)) return;
    _seenMsgIds.add(msgId);

    String decrypted;
    try {
      decrypted = RSAHelper.decrypt(data['content'] as String, _myPrivateKey!);
    } catch (_) { return; } // not for us or corrupt

    final senderId = data['senderId'] as String;
    final peer     = _peers[fromId] ?? _peers[senderId];
    if (peer == null) return;

    final msg = Message(
      id:         msgId,
      senderId:   senderId,
      senderName: data['senderName'] ?? peer.name,
      content:    decrypted,
      timestamp:  DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
      isMe:       false,
      isRelayed:  isRelayed,
    );

    peer.messages.add(msg);
    await DatabaseHelper.instance.insertMessage(msg, peer.id, peer.name);
    await DatabaseHelper.instance.upsertPeer(peer);
    onMessageReceived?.call(peer.id, msg);
  }

  Future<void> _handleRelay(Map<String, dynamic> envelope) async {
    final destinationId = envelope['destinationId'] as String;
    final msgId = envelope['payload']?['id'] as String?;
    if (msgId != null && _seenMsgIds.contains(msgId)) return;
    if (msgId != null) _seenMsgIds.add(msgId);

    if (destinationId == _myId) {
      // This message is for me — decrypt and handle
      await _handleMessage('', envelope['payload'], isRelayed: true);
    } else {
      // Forward blindly — do NOT read content
      _relayMessage(envelope);
    }
  }

  // ── Send raw bytes ─────────────────────────────────────────
  void _sendRaw(String peerId, String jsonStr) {
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    Nearby().sendBytesPayload(peerId, bytes).catchError((_) {});
  }

  // ── Load persisted messages ────────────────────────────────
  Future<List<Message>> loadMessages(String peerId) async {
    return DatabaseHelper.instance.getMessages(peerId);
  }

  Future<List<Peer>> loadKnownPeers() async {
    return DatabaseHelper.instance.getKnownPeers();
  }

  Future<void> clearChat(String peerId) async {
    _peers[peerId]?.messages.clear();
    await DatabaseHelper.instance.deleteMessagesForPeer(peerId);
  }
}
