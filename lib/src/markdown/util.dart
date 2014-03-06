library markdown.util;

import 'ast.dart';

/// Replaces `<`, `&`, and `>`, with their HTML entity equivalents.
String escapeHtml(String html) {
  return html.replaceAll('&', '&amp;')
             .replaceAll('<', '&lt;')
             .replaceAll('>', '&gt;');
}

typedef Node Resolver(String name);
