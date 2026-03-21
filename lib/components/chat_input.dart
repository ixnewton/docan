import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../config/constants.dart';
import '../models/chat_message.dart';
import '../utils/file_processor.dart';
import '../utils/liquid_glass_effects.dart';

/// Liquid Glass styled chat input field
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onSend;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool isLoading;
  final String hintText;
  final List<Attachment> attachments;
  final ValueChanged<List<Attachment>>? onAttachmentsChanged;

  const ChatInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSend,
    this.onChanged,
    this.enabled = true,
    this.isLoading = false,
    this.hintText = 'Message...',
    this.attachments = const [],
    this.onAttachmentsChanged,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _handleTextChange() {
    if (!mounted) return;
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onChanged?.call(widget.controller.text);
  }

  void _handleSend() {
    if (widget.controller.text.trim().isEmpty && widget.attachments.isEmpty) return;
    if (widget.isLoading) return;
    widget.onSend?.call();
  }

  bool get _canSend => _hasText || widget.attachments.isNotEmpty;

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _showAttachmentOptions(BuildContext buttonContext) async {
    if (_isDesktop(context)) {
      // On desktop, go directly to file picker
      _pickFile();
    } else {
      _showAttachmentBottomSheet();
    }
  }

  bool _isMobilePlatform() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }


  void _showAttachmentBottomSheet() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlassContainer(
        borderRadius: AppConstants.radiusL,
        margin: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image, color: theme.primaryColor),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_isMobilePlatform()) ListTile(
              leading: Icon(Icons.camera_alt, color: theme.primaryColor),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: theme.primaryColor),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
        
        final attachment = Attachment(
          name: image.name,
          type: AttachmentType.image,
          mimeType: mimeType,
          bytes: bytes,
        );
        
        final newAttachments = [...widget.attachments, attachment];
        widget.onAttachmentsChanged?.call(newAttachments);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'doc', 'docx', 'md', 'json', 'csv', 'png', 'jpg', 'jpeg', 'gif', 'webp'],
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
          final isImage = mimeType.startsWith('image/');
          final isPdf = mimeType == 'application/pdf';
          final isDocx = file.name.toLowerCase().endsWith('.docx');
          final isDoc = file.name.toLowerCase().endsWith('.doc');
          final needsProcessing = isPdf || isDocx || isDoc;
          
          if (needsProcessing) {
            // Process incompatible files immediately and add processed attachments
            await _processFileAndAddAttachments(file.name, file.bytes!, mimeType);
          } else {
            // Handle compatible files (images, text, json, csv, md)
            final attachment = Attachment(
              name: file.name,
              type: isImage ? AttachmentType.image : AttachmentType.file,
              mimeType: mimeType,
              bytes: file.bytes!,
            );
            
            final newAttachments = [...widget.attachments, attachment];
            widget.onAttachmentsChanged?.call(newAttachments);
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _processFileAndAddAttachments(String fileName, Uint8List bytes, String mimeType) async {
    try {
      debugPrint('[ChatInput] Processing file immediately on selection: $fileName (${bytes.length} bytes)');
      
      // Show processing indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing ${fileName.split('.').last.toUpperCase()} file...'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final attachment = Attachment(
        name: fileName,
        type: AttachmentType.file,
        mimeType: mimeType,
        bytes: bytes,
      );

      // Process the file based on its type - always create .txt output
      final processedAttachments = <Attachment>[];
      
      if (mimeType == 'application/pdf') {
        // Handle PDF - extract text only
        debugPrint('[ChatInput] Processing PDF file to text...');
        final textContent = await FileProcessor.extractTextContent(attachment);
        
        // Create text file attachment
        final textFileName = '${fileName.substring(0, fileName.lastIndexOf('.'))}_extracted_text.txt';
        final textAttachment = Attachment(
          name: textFileName,
          type: AttachmentType.file,
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(textContent.codeUnits),
        );
        
        processedAttachments.add(textAttachment);
        
        // Show completion message
        debugPrint('[ChatInput] PDF processing completed. Text length: ${textContent.length}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF processed: Extracted ${textContent.length} characters of text'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Handle other incompatible files (DOC, DOCX, etc.)
        debugPrint('[ChatInput] Processing ${fileName.split('.').last} file to text...');
        final textContent = await FileProcessor.extractTextContent(attachment);
        
        // Create text file attachment
        final textFileName = '${fileName.substring(0, fileName.lastIndexOf('.'))}_extracted_text.txt';
        final textAttachment = Attachment(
          name: textFileName,
          type: AttachmentType.file,
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(textContent.codeUnits),
        );
        
        processedAttachments.add(textAttachment);
        
        // Show completion message
        debugPrint('[ChatInput] File processing completed. Text length: ${textContent.length}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File processed: Extracted ${textContent.length} characters of text'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      // Add only the processed text attachments (original file is discarded)
      final newAttachments = [...widget.attachments, ...processedAttachments];
      debugPrint('[ChatInput] Adding processed text attachments to list, total: ${newAttachments.length}');
      widget.onAttachmentsChanged?.call(newAttachments);
      
    } catch (e) {
      debugPrint('[ChatInput] Error processing file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process file: $e')),
        );
        
        // If processing fails, add a placeholder to indicate failure
        final failedAttachment = Attachment(
          name: '${fileName}_processing_failed.txt',
          type: AttachmentType.file,
          mimeType: 'text/plain',
          bytes: Uint8List.fromList('File processing failed. Please try again or copy the text manually.'.codeUnits),
        );
        
        final newAttachments = [...widget.attachments, failedAttachment];
        widget.onAttachmentsChanged?.call(newAttachments);
      }
    }
  }

  void _removeAttachment(int index) {
    final newAttachments = [...widget.attachments];
    newAttachments.removeAt(index);
    widget.onAttachmentsChanged?.call(newAttachments);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = !widget.enabled;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment previews
            if (widget.attachments.isNotEmpty)
              Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = widget.attachments[index];
                    return _AttachmentPreview(
                      attachment: attachment,
                      onRemove: () => _removeAttachment(index),
                    );
                  },
                ),
              ),
            // Input field
            LiquidGlassContainer(
              borderRadius: AppConstants.radiusNavBar,
              padding: EdgeInsets.zero,
              blurIntensity: 25,
              animateOnHover: false,
              child: AnimatedContainer(
                duration: AppConstants.hoverDuration,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusNavBar),
                  border: Border.all(
                    color: _isFocused && !isDisabled
                        ? theme.primaryColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Attachment button
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppConstants.spacingXS,
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Builder(
                          builder: (buttonContext) => IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.add,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: isDisabled ? 0.3 : 0.6),
                              size: 20,
                            ),
                            onPressed: isDisabled ? null : () => _showAttachmentOptions(buttonContext),
                          ),
                        ),
                      ),
                    ),
                    // Text field
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          // Desktop: Enter to send, Shift+Enter for newline
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            _handleSend();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingS,
                              vertical: AppConstants.spacingM,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Send button
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppConstants.spacingXS,
                      ),
                      child: AnimatedContainer(
                        duration: AppConstants.hoverDuration,
                        child: widget.isLoading
                            ? SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.primaryColor,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _canSend
                                      ? theme.primaryColor
                                      : theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed:
                                      _canSend && widget.enabled ? _handleSend : null,
                                  icon: Icon(
                                    Icons.arrow_upward_rounded,
                                    color: _canSend
                                        ? Colors.white
                                        : theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.4),
                                    size: 20,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 70,
      height: 70,
      margin: const EdgeInsets.only(right: AppConstants.spacingS),
      child: Stack(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusM - 1),
              child: attachment.isImage
                  ? Image.memory(
                      attachment.bytes,
                      fit: BoxFit.cover,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            attachment.name,
                            style: theme.textTheme.labelSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
