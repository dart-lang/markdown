import 'dart:convert';

String escapeHtml(String html) =>
    const HtmlEscape(HtmlEscapeMode.ELEMENT).convert(html);
