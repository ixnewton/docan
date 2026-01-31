import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/chat_message.dart';

/// Exception types for file processing
class FileProcessingException implements Exception {
  final String message;
  final String? fileName;
  final FileProcessingErrorType type;
  
  const FileProcessingException(
    this.message, {
    this.fileName,
    this.type = FileProcessingErrorType.general,
  });
  
  @override
  String toString() => 'FileProcessingException: $message${fileName != null ? ' (file: $fileName)' : ''}';
}

enum FileProcessingErrorType {
  fileSizeExceeded,
  unsupportedFileType,
  encodingError,
  parsingError,
  general,
}

/// Utility class for processing file attachments with safety and performance optimizations
class FileProcessor {
  // File size limits in bytes for different providers
  static const int _openaiMaxSize = 512 * 1024 * 1024; // 512MB
  static const int _claudeMaxSize = 150 * 1024 * 1024; // 150MB
  static const int _geminiMaxSize = 20 * 1024 * 1024; // 20MB
  static const int _deepseekMaxSize = 10 * 1024 * 1024; // 10MB
  static const int _ollamaMaxSize = 10 * 1024 * 1024; // 10MB
  static const int _lmstudioMaxSize = 10 * 1024 * 1024; // 10MB
  
  // Global processing limits for safety
  static const int _maxProcessingFileSize = 50 * 1024 * 1024; // 50MB max for text extraction
  static const int _maxCsvLines = 1000; // Maximum CSV lines to process
  
  // Cache for extracted text content
  static final Map<String, String> _textCache = {};
  static const int _maxCacheSize = 100;
  static const int _maxCacheEntrySize = 1024 * 1024; // 1MB per cache entry

  // Supported file types by provider
  static const Set<String> _openaiSupportedTypes = {
    'pdf', 'txt', 'md', 'json', 'csv', 'docx', 'doc', 'xlsx', 'xls',
    'pptx', 'ppt', 'html', 'xml', 'rtf', 'jpg', 'jpeg', 'png', 'gif',
    'webp', 'bmp', 'tiff', 'svg'
  };

  static const Set<String> _claudeSupportedTypes = {
    'pdf', 'txt', 'md', 'json', 'csv', 'docx', 'doc', 'xlsx', 'xls',
    'pptx', 'ppt', 'html', 'xml', 'rtf', 'jpg', 'jpeg', 'png', 'gif',
    'webp', 'bmp', 'svg'
  };

  static const Set<String> _geminiSupportedTypes = {
    'pdf', 'txt', 'md', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'
  };

  static const Set<String> _deepseekSupportedTypes = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'pdf', 'txt', 'md'
  };

  static const Set<String> _ollamaSupportedTypes = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'pdf', 'txt', 'md'
  };

  static const Set<String> _lmstudioSupportedTypes = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'pdf', 'txt', 'md'
  };

  /// Get file size limit for a provider
  static int getMaxFileSize(String providerName) {
    switch (providerName.toLowerCase()) {
      case 'openai':
        return _openaiMaxSize;
      case 'claude':
        return _claudeMaxSize;
      case 'gemini':
        return _geminiMaxSize;
      case 'deepseek':
        return _deepseekMaxSize;
      case 'ollama':
        return _ollamaMaxSize;
      case 'lmstudio':
        return _lmstudioMaxSize;
      default:
        return 10 * 1024 * 1024; // Default 10MB
    }
  }

  /// Get supported file types for a provider
  static Set<String> getSupportedFileTypes(String providerName) {
    switch (providerName.toLowerCase()) {
      case 'openai':
        return _openaiSupportedTypes;
      case 'claude':
        return _claudeSupportedTypes;
      case 'gemini':
        return _geminiSupportedTypes;
      case 'deepseek':
        return _deepseekSupportedTypes;
      case 'ollama':
        return _ollamaSupportedTypes;
      case 'lmstudio':
        return _lmstudioSupportedTypes;
      default:
        return {'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt', 'md'};
    }
  }

  /// Check if a file is supported by a provider with comprehensive validation
  static bool isFileSupported(Attachment attachment, String providerName) {
    try {
      final validationError = validateAttachment(attachment, providerName);
      return validationError == null;
    } catch (e) {
      return false;
    }
  }
  
  /// Generate cache key for attachment
  static String _generateCacheKey(Attachment attachment) {
    final bytes = attachment.bytes;
    final hash = sha256.convert(bytes).toString();
    return '${attachment.name}_$hash';
  }
  
  /// Clean cache if it exceeds limits
  static void _cleanCache() {
    if (_textCache.length > _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keysToRemove = _textCache.keys.take(_textCache.length - _maxCacheSize + 10).toList();
      for (final key in keysToRemove) {
        _textCache.remove(key);
      }
    }
  }
  
  /// Validate base64 data format
  static bool _isValidBase64(String base64String) {
    try {
      base64.decode(base64String);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Extract text content from a file attachment (synchronous version with safety checks)
  static String extractTextContentSync(Attachment attachment) {
    try {
      // Validate input
      if (attachment.bytes.isEmpty) {
        throw const FileProcessingException(
          'File is empty',
          type: FileProcessingErrorType.parsingError,
        );
      }
      
      // Check processing size limit
      if (attachment.bytes.length > _maxProcessingFileSize) {
        throw FileProcessingException(
          'File too large for text processing (${_formatFileSize(attachment.bytes.length)} > ${_formatFileSize(_maxProcessingFileSize)})',
          fileName: attachment.name,
          type: FileProcessingErrorType.fileSizeExceeded,
        );
      }
      
      // Check cache first
      final cacheKey = _generateCacheKey(attachment);
      if (_textCache.containsKey(cacheKey)) {
        return _textCache[cacheKey]!;
      }
      
      final extension = _getFileExtension(attachment.name);
      String result;
      
      switch (extension) {
        case 'txt':
        case 'md':
          result = _decodeTextSafely(attachment.bytes, attachment.name);
          break;
        
        case 'json':
          result = _processJsonSafely(attachment.bytes, attachment.name);
          break;
        
        case 'csv':
          result = _processCsvSafely(attachment.bytes, attachment.name);
          break;
        
        case 'pdf':
          result = '[PDF Document - ${attachment.bytes.length} bytes]\n\nNote: PDF text extraction requires additional processing. The file has been processed and can be analyzed by the AI model.';
          break;
        
        case 'docx':
          result = '[DOCX Document - ${attachment.bytes.length} bytes]\n\nNote: DOCX text extraction requires additional processing. The file has been processed and can be analyzed by the AI model.';
          break;
        
        case 'html':
        case 'htm':
          result = _extractFromHtmlSafely(attachment.bytes, attachment.name);
          break;
        
        case 'xml':
          result = _extractFromXmlSafely(attachment.bytes, attachment.name);
          break;
        
        case 'rtf':
          result = _extractFromRtfSafely(attachment.bytes, attachment.name);
          break;
        
        default:
          // For unsupported text-based files, try to decode as UTF-8
          result = _decodeTextSafely(attachment.bytes, attachment.name, fallbackToBinary: true);
          break;
      }
      
      // Cache result if it's not too large
      if (result.length < _maxCacheEntrySize) {
        _cleanCache();
        _textCache[cacheKey] = result;
      }
      
      return result;
    } catch (e) {
      if (e is FileProcessingException) {
        rethrow;
      }
      throw FileProcessingException(
        'Failed to extract text content: $e',
        fileName: attachment.name,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }

  /// Extract text content from a file attachment (async version)
  static Future<String> extractTextContent(Attachment attachment) async {
    // For now, delegate to sync version
    // In the future, this could handle async PDF/DOCX processing
    try {
      return extractTextContentSync(attachment);
    } catch (e) {
      if (e is FileProcessingException) {
        rethrow;
      }
      throw FileProcessingException(
        'Failed to extract text content: $e',
        fileName: attachment.name,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }

  /// Get file extension from filename with validation
  static String _getFileExtension(String filename) {
    if (filename.isEmpty) {
      throw const FileProcessingException(
        'Filename is empty',
        type: FileProcessingErrorType.parsingError,
      );
    }
    
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filename.length - 1) {
      return ''; // No extension or dot at end
    }
    return filename.substring(lastDot + 1).toLowerCase();
  }

  /// Process CSV content with safety checks and improved performance
  static String _processCsvSafely(Uint8List bytes, String fileName) {
    try {
      final content = _decodeTextSafely(bytes, fileName);
      final lines = content.split('\n');
      
      if (lines.isEmpty) {
        return '[Empty CSV file]';
      }
      
      if (lines.length > _maxCsvLines) {
        // For large CSV files, show first and last few rows with proper bounds checking
        final headerEnd = lines.length < 10 ? lines.length : 10;
        final header = lines.take(headerEnd).join('\n');
        
        if (lines.length > 20) {
          final footerStart = lines.length - 10;
          final footer = lines.skip(footerStart).join('\n');
          final middle = lines.length - 20;
          return '$header\n\n... and $middle more rows ...\n\n$footer';
        } else {
          // If file is not much larger than limit, just show everything
          return content;
        }
      }
      
      return content;
    } catch (e) {
      throw FileProcessingException(
        'Failed to process CSV: $e',
        fileName: fileName,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }

  /// Format file size in human readable format
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Validate attachment for a specific provider with comprehensive error handling
  static String? validateAttachment(Attachment attachment, String providerName) {
    try {
      // Check if attachment data is valid
      if (attachment.bytes.isEmpty) {
        return 'File is empty';
      }
      
      // Validate base64 data if present
      if (attachment.base64Data.isNotEmpty && !_isValidBase64(attachment.base64Data)) {
        return 'Invalid base64 data format';
      }
      
      // Check file size
      final maxSize = getMaxFileSize(providerName);
      if (attachment.bytes.length > maxSize) {
        return 'File size exceeds ${_formatFileSize(maxSize)} limit for $providerName';
      }
      
      // Check file type
      final supportedTypes = getSupportedFileTypes(providerName);
      final extension = _getFileExtension(attachment.name);
      if (extension.isEmpty) {
        return 'File has no extension';
      }
      
      if (!supportedTypes.contains(extension)) {
        return 'File type .$extension is not supported by $providerName';
      }
      
      return null; // No validation errors
    } catch (e) {
      return 'Validation error: $e';
    }
  }
  
  /// Safe text decoding with error handling
  static String _decodeTextSafely(Uint8List bytes, String fileName, {bool fallbackToBinary = false}) {
    try {
      return utf8.decode(bytes);
    } on FormatException catch (e) {
      if (fallbackToBinary) {
        return '[Binary file - cannot extract text content]';
      }
      throw FileProcessingException(
        'Text encoding error: $e',
        fileName: fileName,
        type: FileProcessingErrorType.encodingError,
      );
    } catch (e) {
      throw FileProcessingException(
        'Failed to decode text: $e',
        fileName: fileName,
        type: FileProcessingErrorType.encodingError,
      );
    }
  }
  
  /// Safe JSON processing with error handling
  static String _processJsonSafely(Uint8List bytes, String fileName) {
    try {
      final jsonContent = _decodeTextSafely(bytes, fileName);
      // Try to format JSON nicely
      try {
        final parsed = jsonDecode(jsonContent);
        return const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (e) {
        // If parsing fails, return raw content
        return jsonContent;
      }
    } catch (e) {
      if (e is FileProcessingException) {
        rethrow;
      }
      throw FileProcessingException(
        'Failed to process JSON: $e',
        fileName: fileName,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }
  
  /// Safe HTML extraction with error handling
  static String _extractFromHtmlSafely(Uint8List bytes, String fileName) {
    try {
      final content = _decodeTextSafely(bytes, fileName);
      // Simple HTML tag removal
      final cleanText = content
          .replaceAll(RegExp(r'<[^>]*>'), ' ') // Remove HTML tags
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();
      return cleanText.isEmpty ? '[Empty HTML content]' : cleanText;
    } catch (e) {
      if (e is FileProcessingException) {
        rethrow;
      }
      throw FileProcessingException(
        'Failed to extract HTML text: $e',
        fileName: fileName,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }
  
  /// Safe XML extraction with error handling
  static String _extractFromXmlSafely(Uint8List bytes, String fileName) {
    try {
      final content = _decodeTextSafely(bytes, fileName);
      // Simple XML tag removal
      final cleanText = content
          .replaceAll(RegExp(r'<[^>]*>'), ' ') // Remove XML tags
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();
      return cleanText.isEmpty ? '[Empty XML content]' : cleanText;
    } catch (e) {
      if (e is FileProcessingException) {
        rethrow;
      }
      throw FileProcessingException(
        'Failed to extract XML text: $e',
        fileName: fileName,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }
  
  /// Safe RTF extraction with error handling
  static String _extractFromRtfSafely(Uint8List bytes, String fileName) {
    try {
      final content = _decodeTextSafely(bytes, fileName);
      // Simple RTF tag removal
      final cleanText = content
          .replaceAll(RegExp(r'\\[^s]*? '), ' ') // Remove RTF commands
          .replaceAll(RegExp(r'\{[^}]*\}'), ' ') // Remove RTF groups
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();
      return cleanText.isEmpty ? '[Empty RTF content]' : cleanText;
    } catch (e) {
      if (e is FileProcessingException) {
        rethrow;
      }
      throw FileProcessingException(
        'Failed to extract RTF text: $e',
        fileName: fileName,
        type: FileProcessingErrorType.parsingError,
      );
    }
  }
  
  /// Format file information for display
  static String formatFileInfo(Attachment attachment) {
    return 'File: ${attachment.name}\nSize: ${_formatFileSize(attachment.bytes.length)}\nType: ${attachment.mimeType}';
  }

  /// Clear the text cache (useful for testing or memory management)
  static void clearCache() {
    _textCache.clear();
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'size': _textCache.length,
      'maxSize': _maxCacheSize,
      'maxEntrySize': _maxCacheEntrySize,
    };
  }
}
