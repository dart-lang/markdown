import '../patterns.dart';
import 'list_syntax.dart';

/// Parses unordered lists.
class UnorderedListSyntax extends ListSyntax {
  const UnorderedListSyntax();

  @override
  RegExp get pattern => ulPattern;

  @override
  String get listTag => 'ul';
}
