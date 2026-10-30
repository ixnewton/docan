import 'dart:convert';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';

class StreamingMarkdown extends StatefulWidget {
  final String data;
  final Color textColor;
  final bool selectable;

  const StreamingMarkdown({
    super.key,
    required this.data,
    required this.textColor,
    this.selectable = true,
  });

  @override
  State<StreamingMarkdown> createState() => _StreamingMarkdownState();

  static List<String> splitBlocks(String text) {
    final blocks = <String>[];
    final current = StringBuffer();
    var inFence = false;
    for (final line in text.split('\n')) {
      if (RegExp(r'^\s*(?:```|~~~)').hasMatch(line)) {
        inFence = !inFence;
      }
      if (!inFence && line.trim().isEmpty) {
        if (current.isNotEmpty) {
          blocks.add(current.toString());
          current.clear();
        }
      } else {
        current.writeln(line);
      }
    }
    if (current.isNotEmpty) blocks.add(current.toString());
    return blocks;
  }
}

class _StreamingMarkdownState extends State<StreamingMarkdown> {
  final Map<String, Widget> _blockCache = HashMap();

  @override
  void didUpdateWidget(StreamingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textColor != oldWidget.textColor ||
        widget.selectable != oldWidget.selectable) {
      _blockCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final blocks = StreamingMarkdown.splitBlocks(widget.data);
    final stableCount = blocks.length > 1 ? blocks.length - 1 : 0;

    final validKeys = <String>{};
    final children = <Widget>[];
    for (var i = 0; i < stableCount; i++) {
      final cacheKey = '$i:$isDark:${blocks[i].hashCode}';
      validKeys.add(cacheKey);
      final cached = _blockCache[cacheKey];
      if (cached != null) {
        children.add(cached);
      } else {
        final built = KeyedSubtree(
          key: ValueKey('sm-block-$i'),
          child: _buildMarkdown(blocks[i], theme, isDark),
        );
        _blockCache[cacheKey] = built;
        children.add(built);
      }
    }
    if (_blockCache.length > 96) {
      _blockCache.removeWhere((k, _) => !validKeys.contains(k));
    }
    if (blocks.isNotEmpty) {
      children.add(_buildMarkdown(blocks.last, theme, isDark));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildMarkdown(String data, ThemeData theme, bool isDark) {
    return MarkdownBody(
      data: data,
      selectable: widget.selectable,
      builders: {
        'latex': LatexElementBuilder(
          textStyle: theme.textTheme.bodyLarge?.copyWith(
            color: widget.textColor,
          ),
          textScaleFactor: 1.2,
        ),
      },
      extensionSet: md.ExtensionSet(
        [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
        [
          md.EmojiSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          LatexSyntax(),
        ],
      ),
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      imageBuilder: (uri, title, alt) {
        if (uri.toString().startsWith('data:image/')) {
          try {
            final dataUri = uri.toString();
            final commaIndex = dataUri.indexOf(',');
            if (commaIndex != -1) {
              final base64Data = dataUri.substring(commaIndex + 1);
              final bytes = base64Decode(base64Data);
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(AppConstants.spacingM),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      child: const Text('Failed to load generated image'),
                    );
                  },
                ),
              );
            }
          } catch (e) {
            return Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              child: Text('Image error: $e'),
            );
          }
        }
        return const SizedBox.shrink();
      },
      styleSheet: _buildStyleSheet(theme, isDark),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme, bool isDark) {
    final textColor = widget.textColor;
    return MarkdownStyleSheet(
      p: theme.textTheme.bodyLarge?.copyWith(color: textColor),
      h1: theme.textTheme.headlineLarge?.copyWith(color: textColor),
      h2: theme.textTheme.headlineMedium?.copyWith(color: textColor),
      h3: theme.textTheme.headlineSmall?.copyWith(color: textColor),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: isDark
            ? Colors.black26
            : Colors.black.withValues(alpha: 0.05),
        color: textColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? Colors.black38
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.primaryColor, width: 3),
        ),
      ),
      listBullet: theme.textTheme.bodyLarge?.copyWith(color: textColor),
      a: TextStyle(
        color: isDark ? Colors.lightBlueAccent : Colors.blue,
        decoration: TextDecoration.underline,
        decorationColor: isDark ? Colors.lightBlueAccent : Colors.blue,
      ),
    );
  }
}

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'(\$\$[\s\S]*?\$\$)|(\$[^$]*\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final input = match.input;
    final matchStart = match.start;
    final matchEnd = match.end;
    final text = input.substring(matchStart, matchEnd);
    final isBlock = text.startsWith('\$\$') && text.endsWith('\$\$');

    final content = isBlock
        ? text.substring(2, text.length - 2)
        : text.substring(1, text.length - 1);

    md.Element el = md.Element.text('latex', content);
    el.attributes['displayMode'] = isBlock.toString();
    parser.addNode(el);
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  final TextStyle? textStyle;
  final double textScaleFactor;

  LatexElementBuilder({this.textStyle, this.textScaleFactor = 1.0});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;
    final isBlock = element.attributes['displayMode'] == 'true';

    return Math.tex(
      content,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      textStyle: textStyle?.copyWith(
        fontSize:
            (textStyle?.fontSize ?? 14) * (isBlock ? textScaleFactor : 1.0),
      ),
      onErrorFallback: (err) {
        return Text(
          '\$$content\$',
          style: textStyle?.copyWith(color: Colors.red),
        );
      },
    );
  }
}
