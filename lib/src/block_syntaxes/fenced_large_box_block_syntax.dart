import 'package:markdown/src/block_syntaxes/fenced_box_block_syntax.dart';
import 'package:markdown/src/patterns.dart';

class FencedLargeBoxBlockSyntax extends FencedBoxBlockSyntax {
  FencedLargeBoxBlockSyntax();

  @override
  RegExp get pattern => largeBoxFencePattern;
}
