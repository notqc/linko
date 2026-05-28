class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final MessageStatus status;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory Message.fromJson(Map<String, dynamic> json, String myId) => Message(
        id: json['id'],
        senderId: json['senderId'],
        senderName: json['senderName'],
        content: json['content'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
        isMe: json['senderId'] == myId,
        status: MessageStatus.received,
      );
}

enum MessageStatus { sending, sent, received, failed }

class Peer {
  final String id;
  final String name;
  final String emoji;
  bool isConnected;
  List<Message> messages;

  Peer({
    required this.id,
    required this.name,
    required this.emoji,
    this.isConnected = false,
    List<Message>? messages,
  }) : messages = messages ?? [];

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
