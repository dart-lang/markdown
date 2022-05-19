import 'package:kroki/kroki.dart';
import 'package:markdown/markdown.dart' as markdown;

/// Use public kroki installation, but this could be custom installation
/// of our own using a subset of diagram endpoints that we choose to support,
/// running on our own server.
final Kroki kroki =
    Kroki(krokiApiUrl: 'https://kroki.io/', cacheRequests: true);

class DiagramTransfomer extends markdown.CodeBlockTransformer {
  @override
  markdown.Node? transformCodeBlock(
      String codeBlockType, String rawCodeBlock, markdown.BlockParser parser) {
    final markdown.AsyncText asyncText = markdown.AsyncText(
        kroki.convertDiagram(codeBlockType, rawCodeBlock), parser,
        uncompletedFutureTextValue:
            rawCodeBlock // Fallback to showing original diagram source.
        );
    return asyncText;
  }

  /// Set supported code block types to all those that Kroki package supports.
  DiagramTransfomer()
      : super(handledCodeBlockTypes: KrokiDiagramEndpoints.supportedEndpoints);
}

final diagramTransformingFencedCodeBlock =
    markdown.TransformableFencedCodeBlockSyntax([DiagramTransfomer()]);

/// Example code to invoke markdown package to convert markdown source
/// which would have diagrams converted to svgs:
///
///```dart
///  final finalHtml = await markdown.markdownToHtmlWithAsyncTransforms(
///       markdownSource,
///       blockSyntaxes: [diagramTransformingFencedCodeBlock],
///       extensionSet: markdown.ExtensionSet.gitHubWeb);
///```
