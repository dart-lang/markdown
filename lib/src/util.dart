import 'dart:convert';

String escapeHtml(String html) =>
    const HtmlEscape(HtmlEscapeMode.ELEMENT).convert(html);

String escapeAttribute(String attribute) => attribute
    .replaceAll(r'\"', '&quot;')
    .replaceAll(r'"', '%22')
    .replaceAll(r'\', '%5C');
