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

  bool get horizontal => side.isHorizontal;

  /// Theme for the owning bar, resolved from the current build context.
  ShellThemeData themeOf(BuildContext context) => ShellTheme.of(context);
}
