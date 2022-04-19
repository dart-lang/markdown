import '../patterns.dart';
import 'list_syntax.dart';

/// Parses ordered lists.
class OrderedListSyntax extends ListSyntax {
  @override
  RegExp get pattern => olPattern;

  @override
  String get listTag => 'ol';

  const OrderedListSyntax();
}
