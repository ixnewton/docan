import 'package:uuid/uuid.dart';
import 'chat_message.dart';
import 'ai_provider.dart';

/// Represents a conversation/chat session
class Conversation {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AIProvider provider;
  final String modelId;
  final bool isPinned;
  final bool isArchived;

  Conversation({
    String? id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.provider = AIProvider.gemini,
    String? modelId,
    this.isPinned = false,
    this.isArchived = false,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        modelId = modelId ?? provider.defaultModel;

  /// Create a new conversation
  factory Conversation.create({
    String? title,
    AIProvider provider = AIProvider.gemini,
    String? modelId,
  }) {
    return Conversation(
      title: title ?? 'New Chat',
      provider: provider,
      modelId: modelId,
    );
  }

  /// Get the last message preview
  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages yet';
    final lastMessage = messages.last;
    final preview = lastMessage.content.length > 50
        ? '${lastMessage.content.substring(0, 50)}...'
        : lastMessage.content;
    return preview.replaceAll('\n', ' ');
  }

  /// Get message count
  int get messageCount => messages.length;

  /// Get relative time string
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
    }
  }

  /// Get date category for grouping
  String get dateCategory {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(Duration(days: today.weekday - 1));
    final lastWeek = thisWeek.subtract(const Duration(days: 7));

    final messageDate = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (messageDate.isAfter(thisWeek)) {
      return 'This Week';
    } else if (messageDate.isAfter(lastWeek)) {
      return 'Last Week';
    } else if (messageDate.month == now.month && messageDate.year == now.year) {
      return 'This Month';
    } else {
      return '${_monthName(messageDate.month)} ${messageDate.year}';
    }
  }

  static String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  /// Add a message to the conversation
  Conversation addMessage(ChatMessage message) {
    return copyWith(
      messages: [...messages, message],
      updatedAt: DateTime.now(),
    );
  }

  /// Update a message in the conversation
  Conversation updateMessage(String messageId, ChatMessage updatedMessage) {
    final updatedMessages = messages.map((msg) {
      return msg.id == messageId ? updatedMessage : msg;
    }).toList();
    return copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove a message from the conversation
  Conversation removeMessage(String messageId) {
    return copyWith(
      messages: messages.where((msg) => msg.id != messageId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// Copy with modifications
  Conversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    AIProvider? provider,
    String? modelId,
    bool? isPinned,
    bool? isArchived,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'provider': provider.name,
      'modelId': modelId,
      'isPinned': isPinned,
      'isArchived': isArchived,
    };
  }

  /// Create from JSON
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      provider: AIProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AIProvider.gemini,
      ),
      modelId: json['modelId'],
      isPinned: json['isPinned'] ?? false,
      isArchived: json['isArchived'] ?? false,
    );
  }
}
