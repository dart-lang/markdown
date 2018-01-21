/// Information for a link-like object, typically representing a link or image
/// tag.
///
/// A [LinkLike] is only meant to represent information that can be parsed
/// immediately from Markdown text, not including the link text. It is not
/// meant to contain resolved reference information.
///
/// Note that a [LinkLike] might also not resolve to anything other than text,
/// for example when a reference link label cannot be found.
class LinkLike {
  final String destination;

  final String title;

  final String label;

  /// THIS IS HACK; PARSER SHOULD KNOW HOW TO WALK.
  final int endPos;

  LinkLike({this.destination, this.title, this.label, this.endPos});

  bool get isReference => label != null;
}
