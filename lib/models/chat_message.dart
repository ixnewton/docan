import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

/// Message role in the conversation
enum MessageRole {
  user,
  assistant,
  system,
}

/// Attachment type
enum AttachmentType {
  image,
  file,
}

/// Represents a file attachment
class Attachment {
  final String id;
  final String name;
  final AttachmentType type;
  final String mimeType;
  final Uint8List bytes;
  
  Attachment({
    String? id,
    required this.name,
    required this.type,
    required this.mimeType,
    required this.bytes,
  }) : id = id ?? const Uuid().v4();
  
  /// Get base64 encoded data
  String get base64Data => base64Encode(bytes);
  
  /// Check if this is an image
  bool get isImage => type == AttachmentType.image;
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'mimeType': mimeType,
      'bytes': base64Data,
    };
  }
  
  /// Create from JSON
  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'],
      name: json['name'] ?? 'file',
      type: AttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttachmentType.file,
      ),
      mimeType: json['mimeType'] ?? 'application/octet-stream',
      bytes: base64Decode(json['bytes'] ?? ''),
    );
  }
}

/// Represents a single chat message
class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  final String? modelId;
  final String? error;
  final List<Attachment> attachments;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.modelId,
    this.error,
    this.attachments = const [],
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Create a user message
  factory ChatMessage.user(String content, {List<Attachment>? attachments}) {
    return ChatMessage(
      role: MessageRole.user,
      content: content,
      attachments: attachments ?? [],
    );
  }

  /// Create an assistant message
  factory ChatMessage.assistant(String content, {String? modelId}) {
    return ChatMessage(
      role: MessageRole.assistant,
      content: content,
      modelId: modelId,
    );
  }

  /// Create a system message
  factory ChatMessage.system(String content) {
    return ChatMessage(
      role: MessageRole.system,
      content: content,
    );
  }

  /// Create a streaming message placeholder
  factory ChatMessage.streaming({String? modelId}) {
    return ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
      modelId: modelId,
    );
  }

  /// Create an error message
  factory ChatMessage.error(String errorMessage) {
    return ChatMessage(
      role: MessageRole.assistant,
      content: '',
      error: errorMessage,
    );
  }

  /// Copy with updated content (for streaming)
  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    String? modelId,
    String? error,
    List<Attachment>? attachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      modelId: modelId ?? this.modelId,
      error: error ?? this.error,
      attachments: attachments ?? this.attachments,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
      'error': error,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      modelId: json['modelId'],
      error: json['error'],
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((a) => Attachment.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;
  bool get hasError => error != null;
  bool get hasAttachments => attachments.isNotEmpty;
}
