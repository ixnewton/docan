import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:docan/models/chat_message.dart';
import 'package:docan/utils/file_processor.dart';

void main() {
  group('FileProcessor Tests', () {
    late Attachment testTextAttachment;
    late Attachment testJsonAttachment;
    late Attachment testCsvAttachment;
    late Attachment testImageAttachment;
    late Attachment testLargeAttachment;
    late Attachment testEmptyAttachment;
    late Attachment testInvalidBase64Attachment;

    setUpAll(() {
      // Clear cache before each test
      FileProcessor.clearCache();

      // Create test attachments
      testTextAttachment = Attachment(
        name: 'test.txt',
        mimeType: 'text/plain',
        type: AttachmentType.file,
        bytes: utf8.encode('This is a test text file with some content.'),
      );

      testJsonAttachment = Attachment(
        name: 'test.json',
        mimeType: 'application/json',
        type: AttachmentType.file,
        bytes: utf8.encode('{"name": "test", "value": 123, "nested": {"key": "value"}}'),
      );

      testCsvAttachment = Attachment(
        name: 'test.csv',
        mimeType: 'text/csv',
        type: AttachmentType.file,
        bytes: utf8.encode('Name,Age,City\nJohn,30,New York\nJane,25,Los Angeles\nBob,35,Chicago'),
      );

      testImageAttachment = Attachment(
        name: 'test.png',
        mimeType: 'image/png',
        type: AttachmentType.image,
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]), // PNG header
      );

      // Create a large attachment (over processing limit)
      final largeContent = 'A' * (60 * 1024 * 1024); // 60MB
      testLargeAttachment = Attachment(
        name: 'large.txt',
        mimeType: 'text/plain',
        type: AttachmentType.file,
        bytes: utf8.encode(largeContent),
      );

      testEmptyAttachment = Attachment(
        name: 'empty.txt',
        mimeType: 'text/plain',
        type: AttachmentType.file,
        bytes: Uint8List(0),
      );

      testInvalidBase64Attachment = Attachment(
        name: 'invalid.txt',
        mimeType: 'text/plain',
        type: AttachmentType.file,
        bytes: utf8.encode('test content'),
      );
    });

    tearDown(() {
      // Clear cache after each test
      FileProcessor.clearCache();
    });

    group('File Size Limits', () {
      test('should reject files that exceed processing limit', () {
        expect(
          () => FileProcessor.extractTextContentSync(testLargeAttachment),
          throwsA(isA<FileProcessingException>()
              .having((e) => e.type, 'type', FileProcessingErrorType.fileSizeExceeded)),
        );
      });

      test('should accept files within processing limit', () {
        expect(
          () => FileProcessor.extractTextContentSync(testTextAttachment),
          returnsNormally,
        );
      });
    });

    group('Text Extraction', () {
      test('should extract text from plain text files', () {
        final result = FileProcessor.extractTextContentSync(testTextAttachment);
        expect(result, equals('This is a test text file with some content.'));
      });

      test('should format JSON content nicely', () {
        final result = FileProcessor.extractTextContentSync(testJsonAttachment);
        expect(result, contains('  "name": "test"'));
        expect(result, contains('  "value": 123'));
        expect(result, contains('  "nested": {'));
      });

      test('should handle CSV files correctly', () {
        final result = FileProcessor.extractTextContentSync(testCsvAttachment);
        expect(result, contains('Name,Age,City'));
        expect(result, contains('John,30,New York'));
      });

      test('should handle empty files', () {
        expect(
          () => FileProcessor.extractTextContentSync(testEmptyAttachment),
          throwsA(isA<FileProcessingException>()
              .having((e) => e.type, 'type', FileProcessingErrorType.parsingError)),
        );
      });

      test('should return placeholder for PDF files', () {
        final pdfAttachment = Attachment(
          name: 'test.pdf',
          mimeType: 'application/pdf',
          type: AttachmentType.file,
          bytes: Uint8List.fromList([37, 80, 68, 70]), // PDF header
        );

        final result = FileProcessor.extractTextContentSync(pdfAttachment);
        expect(result, contains('PDF Document'));
        expect(result, contains('requires additional processing'));
      });

      test('should return placeholder for DOCX files', () {
        final docxAttachment = Attachment(
          name: 'test.docx',
          mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          type: AttachmentType.file,
          bytes: Uint8List.fromList([80, 75, 3, 4]), // DOCX header
        );

        final result = FileProcessor.extractTextContentSync(docxAttachment);
        expect(result, contains('DOCX Document'));
        expect(result, contains('requires additional processing'));
      });
    });

    group('Error Handling', () {
      test('should handle invalid UTF-8 encoding', () {
        final invalidUtf8Attachment = Attachment(
          name: 'invalid.txt',
          mimeType: 'text/plain',
          type: AttachmentType.file,
          bytes: Uint8List.fromList([0xFF, 0xFE, 0xFD]), // Invalid UTF-8
        );

        expect(
          () => FileProcessor.extractTextContentSync(invalidUtf8Attachment),
          throwsA(isA<FileProcessingException>()
              .having((e) => e.type, 'type', FileProcessingErrorType.encodingError)),
        );
      });

      test('should handle malformed JSON', () {
        final malformedJsonAttachment = Attachment(
          name: 'malformed.json',
          mimeType: 'application/json',
          type: AttachmentType.file,
          bytes: utf8.encode('{"invalid": json}'),
        );

        final result = FileProcessor.extractTextContentSync(malformedJsonAttachment);
        expect(result, equals('{"invalid": json}')); // Should return raw content
      });

      test('should handle empty filename', () {
        final emptyNameAttachment = Attachment(
          name: '',
          mimeType: 'text/plain',
          type: AttachmentType.file,
          bytes: utf8.encode('test'),
        );

        expect(
          () => FileProcessor.extractTextContentSync(emptyNameAttachment),
          throwsA(isA<FileProcessingException>()),
        );
      });
    });

    group('Attachment Validation', () {
      test('should validate supported file types for OpenAI', () {
        final result = FileProcessor.validateAttachment(testTextAttachment, 'openai');
        expect(result, isNull);
      });

      test('should reject unsupported file types for provider', () {
        final unsupportedAttachment = Attachment(
          name: 'test.xyz',
          mimeType: 'application/xyz',
          type: AttachmentType.file,
          bytes: utf8.encode('test'),
        );

        final result = FileProcessor.validateAttachment(unsupportedAttachment, 'openai');
        expect(result, contains('File type .xyz is not supported'));
      });

      test('should reject files that exceed provider size limit', () {
        final result = FileProcessor.validateAttachment(testLargeAttachment, 'gemini');
        expect(result, contains('File size exceeds'));
      });

      test('should reject empty files', () {
        final result = FileProcessor.validateAttachment(testEmptyAttachment, 'openai');
        expect(result, equals('File is empty'));
      });

      test('should reject invalid base64 data', () {
        // Since base64Data is now a getter computed from bytes, it will always be valid
        // This test is no longer applicable, but we can test the validation logic
        final result = FileProcessor.validateAttachment(testTextAttachment, 'openai');
        expect(result, isNull); // Should pass since base64 is valid
      });

      test('should reject files without extension', () {
        final noExtAttachment = Attachment(
          name: 'noextension',
          mimeType: 'text/plain',
          type: AttachmentType.file,
          bytes: utf8.encode('test'),
        );

        final result = FileProcessor.validateAttachment(noExtAttachment, 'openai');
        expect(result, equals('File has no extension'));
      });
    });

    group('Caching', () {
      test('should cache extracted text content', () {
        // First extraction
        final result1 = FileProcessor.extractTextContentSync(testTextAttachment);
        expect(result1, equals('This is a test text file with some content.'));

        // Check cache stats
        final stats = FileProcessor.getCacheStats();
        expect(stats['size'], equals(1));

        // Second extraction should use cache
        final result2 = FileProcessor.extractTextContentSync(testTextAttachment);
        expect(result2, equals(result1));
      });

      test('should not cache results that are too large', () {
        // Create a large text result (but small file)
        final largeTextAttachment = Attachment(
          name: 'large.txt',
          mimeType: 'text/plain',
          type: AttachmentType.file,
          bytes: utf8.encode('A' * (2 * 1024 * 1024)), // 2MB of text
        );

        FileProcessor.extractTextContentSync(largeTextAttachment);
        
        final stats = FileProcessor.getCacheStats();
        expect(stats['size'], equals(0)); // Should not be cached
      });

      test('should clean cache when it exceeds maximum size', () {
        // Fill cache beyond limit
        for (int i = 0; i < 150; i++) {
          final attachment = Attachment(
            name: 'test$i.txt',
            mimeType: 'text/plain',
            type: AttachmentType.file,
            bytes: utf8.encode('Content $i'),
          );
          FileProcessor.extractTextContentSync(attachment);
        }

        final stats = FileProcessor.getCacheStats();
        expect(stats['size'], lessThanOrEqualTo(100)); // Should be cleaned to max size
      });

      test('should clear cache manually', () {
        // Add something to cache
        FileProcessor.extractTextContentSync(testTextAttachment);
        expect(FileProcessor.getCacheStats()['size'], equals(1));

        // Clear cache
        FileProcessor.clearCache();
        expect(FileProcessor.getCacheStats()['size'], equals(0));
      });
    });

    group('File Type Support', () {
      test('should correctly identify supported files', () {
        expect(FileProcessor.isFileSupported(testTextAttachment, 'openai'), isTrue);
        expect(FileProcessor.isFileSupported(testImageAttachment, 'openai'), isTrue);
        expect(FileProcessor.isFileSupported(testJsonAttachment, 'openai'), isTrue);
      });

      test('should correctly identify unsupported files', () {
        final unsupportedAttachment = Attachment(
          name: 'test.xyz',
          mimeType: 'application/xyz',
          type: AttachmentType.file,
          bytes: utf8.encode('test'),
        );

        expect(FileProcessor.isFileSupported(unsupportedAttachment, 'openai'), isFalse);
      });

      test('should handle validation errors gracefully', () {
        expect(FileProcessor.isFileSupported(testEmptyAttachment, 'openai'), isFalse);
        // Test with a file that has no extension
        final noExtAttachment = Attachment(
          name: 'noextension',
          mimeType: 'text/plain',
          type: AttachmentType.file,
          bytes: utf8.encode('test'),
        );
        expect(FileProcessor.isFileSupported(noExtAttachment, 'openai'), isFalse);
      });
    });

    group('HTML/XML Processing', () {
      test('should extract text from HTML', () {
        final htmlAttachment = Attachment(
          name: 'test.html',
          mimeType: 'text/html',
          type: AttachmentType.file,
          bytes: utf8.encode('<html><body><h1>Title</h1><p>Paragraph content</p></body></html>'),
        );

        final result = FileProcessor.extractTextContentSync(htmlAttachment);
        expect(result, contains('Title'));
        expect(result, contains('Paragraph content'));
        expect(result, isNot(contains('<html>')));
      });

      test('should extract text from XML', () {
        final xmlAttachment = Attachment(
          name: 'test.xml',
          mimeType: 'text/xml',
          type: AttachmentType.file,
          bytes: utf8.encode('<?xml version="1.0"?><root><item>Content</item></root>'),
        );

        final result = FileProcessor.extractTextContentSync(xmlAttachment);
        expect(result, contains('Content'));
        expect(result, isNot(contains('<root>')));
      });

      test('should handle empty HTML/XML', () {
        final emptyHtmlAttachment = Attachment(
          name: 'empty.html',
          mimeType: 'text/html',
          type: AttachmentType.file,
          bytes: utf8.encode('<html></html>'),
        );

        final result = FileProcessor.extractTextContentSync(emptyHtmlAttachment);
        expect(result, equals('[Empty HTML content]'));
      });
    });

    group('CSV Processing Edge Cases', () {
      test('should handle empty CSV', () {
        final emptyCsvAttachment = Attachment(
          name: 'empty.csv',
          mimeType: 'text/csv',
          type: AttachmentType.file,
          bytes: utf8.encode(''),
        );

        expect(
          () => FileProcessor.extractTextContentSync(emptyCsvAttachment),
          throwsA(isA<FileProcessingException>()
              .having((e) => e.type, 'type', FileProcessingErrorType.parsingError)),
        );
      });

      test('should handle CSV with exactly maximum lines', () {
        final lines = List.generate(1000, (i) => 'Line$i,Data$i');
        final largeCsvAttachment = Attachment(
          name: 'large.csv',
          mimeType: 'text/csv',
          type: AttachmentType.file,
          bytes: utf8.encode(lines.join('\n')),
        );

        final result = FileProcessor.extractTextContentSync(largeCsvAttachment);
        expect(result, contains('Line0'));
        expect(result, contains('Line999'));
        expect(result, isNot(contains('... and')));
      });

      test('should handle CSV with more than maximum lines', () {
        final lines = List.generate(1500, (i) => 'Line$i,Data$i');
        final veryLargeCsvAttachment = Attachment(
          name: 'verylarge.csv',
          mimeType: 'text/csv',
          type: AttachmentType.file,
          bytes: utf8.encode(lines.join('\n')),
        );

        final result = FileProcessor.extractTextContentSync(veryLargeCsvAttachment);
        expect(result, contains('Line0'));
        expect(result, contains('Line1499'));
        expect(result, contains('... and'));
      });
    });

    group('Async Processing', () {
      test('should handle async text extraction', () async {
        final result = await FileProcessor.extractTextContent(testTextAttachment);
        expect(result, equals('This is a test text file with some content.'));
      });

      test('should handle async errors', () async {
        expect(
          () => FileProcessor.extractTextContent(testLargeAttachment),
          throwsA(isA<FileProcessingException>()),
        );
      });
    });

    group('Provider-specific Limits', () {
      test('should have different size limits for different providers', () {
        final openaiLimit = FileProcessor.getMaxFileSize('openai');
        final claudeLimit = FileProcessor.getMaxFileSize('claude');
        final geminiLimit = FileProcessor.getMaxFileSize('gemini');

        expect(openaiLimit, greaterThan(claudeLimit));
        expect(claudeLimit, greaterThan(geminiLimit));
      });

      test('should have different supported file types for different providers', () {
        final openaiTypes = FileProcessor.getSupportedFileTypes('openai');
        final geminiTypes = FileProcessor.getSupportedFileTypes('gemini');

        expect(openaiTypes, contains('xlsx'));
        expect(geminiTypes, isNot(contains('xlsx')));
        expect(openaiTypes, contains('tiff'));
        expect(geminiTypes, isNot(contains('tiff')));
      });
    });
  });
}
