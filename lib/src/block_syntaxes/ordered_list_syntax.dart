import '../patterns.dart';
import 'list_syntax.dart';

/// Parses ordered lists.
class OrderedListSyntax extends ListSyntax {
  const OrderedListSyntax();

  @override
  RegExp get pattern => olPattern;

  @override
  String get listTag => 'ol';
}
