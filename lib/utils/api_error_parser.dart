/// Utility functions for parsing API errors into user-friendly messages
class ApiErrorParser {
  ApiErrorParser._();

  /// Parse API error messages into user-friendly messages
  static String parse(String message, int statusCode) {
    final lowerMessage = message.toLowerCase();

    // Quota exceeded errors
    if (lowerMessage.contains('quota') || statusCode == 429) {
      if (lowerMessage.contains('free_tier') ||
          lowerMessage.contains('free tier')) {
        return 'Free tier quota exceeded. Please upgrade your plan or wait for the quota to reset.';
      }
      // Extract retry time if present
      final retryMatch = RegExp(
        r'retry in (\d+\.?\d*)s',
      ).firstMatch(lowerMessage);
      if (retryMatch != null) {
        final seconds = double.tryParse(retryMatch.group(1) ?? '0') ?? 0;
        if (seconds > 60) {
          final minutes = (seconds / 60).ceil();
          return 'Rate limit exceeded. Please try again in $minutes minute${minutes > 1 ? 's' : ''}.';
        }
        return 'Rate limit exceeded. Please try again in ${seconds.ceil()} seconds.';
      }
      return 'API quota exceeded. Please check your plan and billing details or try again later.';
    }

    // Authentication errors
    if (statusCode == 401 ||
        lowerMessage.contains('authentication') ||
        lowerMessage.contains('invalid') && lowerMessage.contains('api key') ||
        lowerMessage.contains('invalid_api_key')) {
      return 'Invalid API key. Please check your API key in settings.';
    }

    // Forbidden errors
    if (statusCode == 403) {
      return 'Access denied. Your API key may not have permission for this feature.';
    }

    // Model not found
    if (statusCode == 404 ||
        lowerMessage.contains('model') && lowerMessage.contains('not found')) {
      return 'Model not available. Please try a different model.';
    }

    // Content policy violations
    if (lowerMessage.contains('safety') ||
        lowerMessage.contains('content policy') ||
        lowerMessage.contains('blocked') ||
        lowerMessage.contains('harm')) {
      return 'Your message was blocked due to content policy. Please try a different prompt.';
    }

    // Connection errors
    if (lowerMessage.contains('connection') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('network')) {
      return 'Connection error. Please check your internet connection and try again.';
    }

    // Server errors
    if (statusCode >= 500) {
      return 'Server error. The service is temporarily unavailable. Please try again later.';
    }

    // Return original message if no specific handling, but clean it up
    if (message.length > 200) {
      return '${message.substring(0, 200)}...';
    }
    return message;
  }
}
