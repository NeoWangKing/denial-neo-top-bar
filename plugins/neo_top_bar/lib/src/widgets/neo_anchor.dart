/// Anchor capture for popups attached to a bar control.
library;

import 'package:flutter/widgets.dart';

/// The scene-space rectangle of the widget that owns [context].
///
/// `localToGlobal` maps into the render tree's root space, which is the same
/// space the popup host lays its children out in: both the bar surfaces and the
/// popup layer are descendants of the same scene stack, and the scene's only
/// ancestor transform (`OutputRelativeTranslation` in the secure stage) is a
/// zero translation whenever the session is unlocked and settled — the only time
/// these panels can be opened.
///
/// Returns null when the element has no laid-out box yet, so callers can fall
/// back to a centered card rather than placing it at a bogus origin.
Rect? neoAnchorRectOf(BuildContext context) {
  final object = context.findRenderObject();
  if (object is! RenderBox || !object.attached || !object.hasSize) return null;
  return object.localToGlobal(Offset.zero) & object.size;
}
