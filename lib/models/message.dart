class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;       // always decrypted when stored
  final DateTime timestamp;
  final bool isMe;
  final bool isRelayed;
  final MessageStatus status;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.isRelayed = false,
    this.status = MessageStatus.sent,
  });

  // Wire format — content is RSA-encrypted ciphertext
  Map<String, dynamic> toWireJson(String encryptedContent) => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'content': encryptedContent,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'isRelayed': isRelayed,
  };

  // Relay envelope — wraps the full encrypted payload
  static Map<String, dynamic> toRelayEnvelope({
    required String destinationId,
    required String originId,
    required Map<String, dynamic> payload,
    required int ttl,
    required List<String> visited,
  }) => {
    'type': 'relay',
    'destinationId': destinationId,
    'originId': originId,
    'ttl': ttl,
    'visited': visited,
    'payload': payload,
  };
}

enum MessageStatus { sending, sent, received, failed }

class Peer {
  final String id;
  String name;
  String emoji;
  bool isConnected;
  bool isPinVerified;
  List<Message> messages;
  String? publicKeyPem;       // their RSA public key
  String? pendingPin;         // PIN shown during pairing

  Peer({
    required this.id,
    required this.name,
    required this.emoji,
    this.isConnected = false,
    this.isPinVerified = false,
    this.publicKeyPem,
    this.pendingPin,
    List<Message>? messages,
  }) : messages = messages ?? [];

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  // emoji based on name hash for consistency
  static String emojiForName(String name) {
    const emojis = [
  // Animals
  '🦁','🐯','🐻','🦊','🐺','🐗','🦝','🦨','🦦','🦥','🐼','🐨',
  // Birds
  '🦅','🦆','🦉','🦚','🦜','🐦','🕊️','🦩','🦢','🐧','🦤','🪶',
  // Insects
  '🦋','🐝','🪲','🐛','🦗','🪳','🐞','🦟','🪰','🦂','🐜','🪱',
  // Flowers
  '🌸','🌺','🌻','🌹','🌷','💐','🪷','🌼','🌸','🏵️','🪻','🌱',
];
    return emojis[name.hashCode.abs() % emojis.length];
  }
}
