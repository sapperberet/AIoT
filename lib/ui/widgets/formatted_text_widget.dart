import 'package:flutter/material.dart';

/// Widget that renders text with Markdown-like formatting
/// Supports: **bold**, *italic*, ~~strikethrough~~, `code`, __underline__, [links](url)
class FormattedTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final Color? linkColor;
  final VoidCallback? onLinkTap;

  const FormattedTextWidget({
    super.key,
    required this.text,
    this.baseStyle,
    this.linkColor,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = baseStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 15);

    return RichText(
      text: TextSpan(
        children:
            _parseFormattedText(text, defaultStyle, linkColor ?? Colors.blue),
      ),
    );
  }

  List<InlineSpan> _parseFormattedText(
      String text, TextStyle baseStyle, Color linkColor) {
    final List<InlineSpan> spans = [];

    // Combined pattern to find all matches
    final combinedPattern = RegExp(
      r'(\*\*\*(.+?)\*\*\*)|' // Bold+Italic
      r'(\*\*(.+?)\*\*)|' // Bold
      r'(__(.+?)__)|' // Bold (underscore)
      r'(\*([^*]+?)\*)|' // Italic
      r'(~~(.+?)~~)|' // Strikethrough
      r'(```([\s\S]+?)```)|' // Code block
      r'(`([^`]+?)`)|' // Inline code
      r'(\+\+(.+?)\+\+)|' // Underline
      r'(\[(.+?)\]\((.+?)\))|' // Links
      r'(==(.+?)==)|' // Highlight
      r'(\^([^^]+?)\^)|' // Superscript
      r'(~([^~]+?)~)', // Subscript
      multiLine: true,
    );

    int lastEnd = 0;

    for (final match in combinedPattern.allMatches(text)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final fullMatch = match.group(0) ?? '';

      // Determine which pattern matched and apply appropriate style
      if (fullMatch.startsWith('***') && fullMatch.endsWith('***')) {
        // Bold + Italic
        final content = fullMatch.substring(3, fullMatch.length - 3);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        // Bold
        final content = fullMatch.substring(2, fullMatch.length - 2);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (fullMatch.startsWith('__') && fullMatch.endsWith('__')) {
        // Bold (underscore)
        final content = fullMatch.substring(2, fullMatch.length - 2);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (fullMatch.startsWith('*') &&
          fullMatch.endsWith('*') &&
          !fullMatch.startsWith('**')) {
        // Italic
        final content = fullMatch.substring(1, fullMatch.length - 1);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (fullMatch.startsWith('~~') && fullMatch.endsWith('~~')) {
        // Strikethrough
        final content = fullMatch.substring(2, fullMatch.length - 2);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else if (fullMatch.startsWith('```') && fullMatch.endsWith('```')) {
        // Code block
        final content = fullMatch.substring(3, fullMatch.length - 3).trim();
        spans.add(WidgetSpan(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: baseStyle.color?.withOpacity(0.1) ??
                  Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: baseStyle.color?.withOpacity(0.2) ??
                    Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Text(
              content,
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) - 1,
              ),
            ),
          ),
        ));
      } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        // Inline code
        final content = fullMatch.substring(1, fullMatch.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: baseStyle.color?.withOpacity(0.15) ??
                  Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              content,
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) - 1,
              ),
            ),
          ),
        ));
      } else if (fullMatch.startsWith('++') && fullMatch.endsWith('++')) {
        // Underline
        final content = fullMatch.substring(2, fullMatch.length - 2);
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(decoration: TextDecoration.underline),
        ));
      } else if (fullMatch.startsWith('[') && fullMatch.contains('](')) {
        // Link
        final linkPattern = RegExp(r'\[(.+?)\]\((.+?)\)');
        final linkMatch = linkPattern.firstMatch(fullMatch);
        if (linkMatch != null) {
          final linkText = linkMatch.group(1) ?? '';
          spans.add(TextSpan(
            text: linkText,
            style: baseStyle.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
            ),
          ));
        }
      } else if (fullMatch.startsWith('==') && fullMatch.endsWith('==')) {
        // Highlight
        final content = fullMatch.substring(2, fullMatch.length - 2);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              content,
              style: baseStyle,
            ),
          ),
        ));
      } else if (fullMatch.startsWith('^') && fullMatch.endsWith('^')) {
        // Superscript
        final content = fullMatch.substring(1, fullMatch.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: const Offset(0, -4),
            child: Text(
              content,
              style: baseStyle.copyWith(
                  fontSize: (baseStyle.fontSize ?? 14) * 0.7),
            ),
          ),
        ));
      } else if (fullMatch.startsWith('~') &&
          fullMatch.endsWith('~') &&
          !fullMatch.startsWith('~~')) {
        // Subscript
        final content = fullMatch.substring(1, fullMatch.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Transform.translate(
            offset: const Offset(0, 2),
            child: Text(
              content,
              style: baseStyle.copyWith(
                  fontSize: (baseStyle.fontSize ?? 14) * 0.7),
            ),
          ),
        ));
      } else {
        // Fallback - just add the text as is
        spans.add(TextSpan(text: fullMatch, style: baseStyle));
      }

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    // If no matches found, return the original text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }
}

/// Chat bubble specific formatted text with theme awareness
class ChatFormattedText extends StatelessWidget {
  final String text;
  final bool isUser;
  final TextStyle? baseStyle;

  const ChatFormattedText({
    super.key,
    required this.text,
    required this.isUser,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final style = baseStyle ??
        TextStyle(
          color: isUser ? Colors.white : theme.colorScheme.onSurface,
          fontSize: 15,
        );

    return FormattedTextWidget(
      text: text,
      baseStyle: style,
      linkColor: isUser
          ? Colors.lightBlueAccent
          : (isDark ? Colors.lightBlue : Colors.blue),
    );
  }
}
