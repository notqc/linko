import 'dart:typed_data';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';

typedef OnPeerFound = void Function(Peer peer);
typedef OnPeerLost = void Function(String peerId);
typedef OnPeerConnected = void Function(Peer peer);
typedef OnPeerDisconnected = void Function(String peerId);
typedef OnMessageReceived = void Function(String peerId, Message message);
typedef OnConnectionRequest = void Function(String peerId, String peerName);

class NearbyService {
  static const String _serviceId = 'com.skylink.chat';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;

  String? _myId;
  String? _myName;
  String? _myEmoji;

  final Map<String, Peer> _peers = {};
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  // Callbacks
  OnPeerFound? onPeerFound;
  OnPeerLost? onPeerLost;
  OnPeerConnected? onPeerConnected;
  OnPeerDisconnected? onPeerDisconnected;
  OnMessageReceived? onMessageReceived;
  OnConnectionRequest? onConnectionRequest;

  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  String get myId => _myId ?? '';
  String get myName => _myName ?? '';
  String get myEmoji => _myEmoji ?? '✈️';

  Future<void> initialize(String name, String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('my_id') ?? const Uuid().v4();
    await prefs.setString('my_id', _myId!);
    _myName = name;
    _myEmoji = emoji;
  }

  Future<bool> startHosting() async {
    try {
      await Nearby().startAdvertising(
        _myName!,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      _isAdvertising = true;
      await startDiscovery();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        _myName!,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          if (_peers.containsKey(id)) return;
          final emojis = ['😊', '🚀', '🎵', '🌟', '🦋', '🔥', '🌈', '⚡'];
          final peer = Peer(
            id: id,
            name: name,
            emoji: emojis[name.hashCode.abs() % emojis.length],
          );
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
    } catch (e) {
      return false;
    }
  }

  Future<bool> connectToPeer(String peerId) async {
    try {
      await Nearby().requestConnection(
        _myName!,
        peerId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // Auto-accept all connections (friends in flight)
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (id, update) {},
    );

    if (!_peers.containsKey(id)) {
      final emojis = ['😊', '🚀', '🎵', '🌟', '🦋', '🔥', '🌈', '⚡'];
      final peer = Peer(
        id: id,
        name: info.endpointName,
        emoji: emojis[info.endpointName.hashCode.abs() % emojis.length],
      );
      _peers[id] = peer;
    }
    onConnectionRequest?.call(id, info.endpointName);
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      final peer = _peers[id];
      if (peer != null) {
        peer.isConnected = true;
        onPeerConnected?.call(peer);
      }
    }
  }

  void _onDisconnected(String id) {
    final peer = _peers[id];
    if (peer != null) {
      peer.isConnected = false;
      onPeerDisconnected?.call(id);
    }
  }

  void _onPayloadReceived(String id, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final jsonStr = utf8.decode(payload.bytes!);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final message = Message.fromJson(json, _myId!);
      _peers[id]?.messages.add(message);
      onMessageReceived?.call(id, message);
    }
  }

  Future<bool> sendMessage(String peerId, String content) async {
    if (_myId == null) return false;
    final message = Message(
      id: const Uuid().v4(),
      senderId: _myId!,
      senderName: _myName!,
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
    );

    try {
      final bytes = utf8.encode(jsonEncode(message.toJson()));
      await Nearby().sendBytesPayload(peerId, Uint8List.fromList(bytes));
      _peers[peerId]?.messages.add(message);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stopAll() async {
    if (_isAdvertising) await Nearby().stopAdvertising();
    if (_isDiscovering) await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _isAdvertising = false;
    _isDiscovering = false;
  }

  List<Message> getMessages(String peerId) {
    return _peers[peerId]?.messages ?? [];
  }
}
