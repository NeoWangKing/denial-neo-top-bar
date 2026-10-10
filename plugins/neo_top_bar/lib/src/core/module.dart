/// The module contract: one self-contained bar segment.
///
/// A module is deliberately small. It declares stable identity plus a build
/// function, and it may declare that it is unavailable for the current host so
/// the bar can hide it instead of reserving a dead pill. Everything a module
/// needs comes from [NeoModuleContext]; modules must not reach for private SDK
/// internals or build their own native bridge.
library;

import 'package:denial_flutter_sdk/panels.dart';
import 'package:denial_flutter_sdk/services.dart';
import 'package:denial_flutter_sdk/theme.dart';
import 'package:flutter/widgets.dart';

import 'module_descriptor.dart';

/// Identity and metadata for one module.
abstract interface class NeoModule {
  NeoModuleDescriptor get descriptor;

  /// Whether the host currently supplies what this module renders. Returning
  /// false hides the module even when the user enabled it, so an optional
  /// module never shows an empty pill on a machine without that data.
  bool isAvailable(NeoModuleContext context);

  Widget build(BuildContext context, NeoModuleContext module);
}

/// A module that has settings of its own.
///
/// Kept as a separate capability rather than a member of [NeoModule]: the bar
/// only ever builds pills, and most modules have nothing to configure. A module
/// that does implement this is a `NeoModuleSettings`, and the settings panel
/// gives it an inset area under its row.
///
/// The panel owns the row, the expander, the zone selector and the reorder
/// buttons; the module only describes the part that is genuinely its own. The
/// returned widget is laid out inside a horizontal-stretching [Column], so a
/// module can return a plain column of rows.
abstract interface class NeoModuleSettings {
  Widget buildSettings(BuildContext context, NeoModuleSettingsScope scope);
}

/// What a module needs in order to build its own settings.
///
/// A separate type from [NeoModuleContext] on purpose: the bar builds pills with
/// a context that carries no writer, and settings are the one place a module may
/// change something. Handing the pill a writer it must not use would be a
/// standing invitation to mutate the configuration from `build`.
class NeoModuleSettingsScope {
  const NeoModuleSettingsScope({
    required this.services,
    required this.monitorId,
    required this.options,
    required this.setOption,
  });

  /// Host services, for the same reason a pill gets them: a setting may need to
  /// list displays or ask the host a question.
  final ShellServices services;

  /// Output whose bar these settings belong to.
  final int monitorId;

  /// The module's stored settings; empty when the user never changed any.
  final Map<String, Object?> options;

  /// Writes a setting, or removes it when [value] is null. Persisting is the
  /// caller's job; a module just says what changed.
  final void Function(String key, Object? value) setOption;

  /// One setting read as a bool, falling back when absent or of another type.
  ///
  /// Settings live in a JSON file a user may hand-edit, so every read has to
  /// tolerate a value of the wrong shape rather than throw inside `build`.
  bool boolOption(String key, {required bool fallback}) {
    final value = options[key];
    return value is bool ? value : fallback;
  }
}

/// Per-bar-instance facts shared by every module of one output.
///
/// This deliberately carries no [BuildContext]: the context belongs to the
/// build call, not to the shared value, so two outputs cannot leak theme or
/// locale state into each other.
class NeoModuleContext {
  const NeoModuleContext({
    required this.services,
    required this.monitorId,
    required this.side,
    required this.accent,
    required this.density,
    this.crossExtent = 40,
    this.concession = 0,
    this.options = const <String, Object?>{},
  });

  final ShellServices services;

  /// Output this bar instance belongs to.
  final int monitorId;

  /// Configured edge. Horizontal bars are the common case; vertical edges are
  /// kept working because Denial's own bar supports them.
  final PanelEdge side;

  /// Wallpaper-derived accent, already resolved for text and fill helpers.
  final WallpaperAccent accent;

  /// Multiplier applied to card padding and gaps.
  final double density;

  /// Height of a pill on this bar, in logical pixels: the thickness Denial
  /// reserves for the strip, minus the padding the bar keeps at its edges.
  ///
  /// This is what icon sizes are derived from. A bar's glyphs should grow with
  /// the *bar*, which the user sets in Denial's own settings, and not with this
  /// plugin's spacing scale: switching between compact and comfortable is a
  /// request for less or more air between pills, not for smaller or larger
  /// icons inside them.
  final double crossExtent;

  /// Size for a glyph that should occupy [fraction] of the pill's height.
  ///
  /// Clamped to a legible range, because a very thin bar would otherwise ask for
  /// an icon nobody can see and a very thick one for an icon taller than its
  /// neighbours' text.
  double glyphSize(double fraction, {double min = 14, double max = 30}) =>
      (crossExtent * fraction).clamp(min, max).toDouble();

  /// Whether the bar is over budget is not a yes/no question, so this is how far
  /// down `NeoConcession`'s ladder the bar has had to go: 0 is the full bar, and
  /// each step takes something away from one module.
  ///
  /// A module decides what that means for itself, because only it knows which
  /// part of it is optional and what that part is worth: the tray collapses
  /// icons, media drops the track title, the clock drops the date. The bar never
  /// hides a whole pill on its own — a module the user enabled stays visible,
  /// just smaller.
  final int concession;

  /// This module's stored settings, as the user left them.
  ///
  /// Part of the context rather than a separate lookup so a pill renders from the
  /// same configuration the settings panel edits, and so the bar's module cache
  /// can tell when a setting changed.
  final Map<String, Object?> options;

  /// A stable identity for the settings, usable in the bar's module cache key.
  ///
  /// `Object.hash` on the map itself would be identity-based, because `Map` does
  /// not override `hashCode`; every rebuild would then look like a change and
  /// the cache would never hit.
  Object get optionsFingerprint => Object.hashAll(<Object>[
    for (final entry in options.entries) Object.hash(entry.key, entry.value),
  ]);

  bool get horizontal => side.isHorizontal;

  /// Theme for the owning bar, resolved from the current build context.
  ShellThemeData themeOf(BuildContext context) => ShellTheme.of(context);
}
