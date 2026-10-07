/// A plugin-owned request to open the settings card.
///
/// This exists because of a gap in the plugin API: a `ShellAction` handler only
/// receives a `ShellActionContext` (services plus an optional monitor id) — no
/// `BuildContext`, no Riverpod container. The action therefore cannot open a
/// popup itself, so it bumps this notifier and every mounted bar, which does have
/// a context, opens the card. The popup controller's `keyName` dedupe keeps
/// several bars from stacking several cards.
///
/// Deliberately not exported from `neo_top_bar_logic.dart`: it is Flutter-side
/// state, not pure logic.
library;

import 'package:flutter/foundation.dart';

class NeoSettingsRequests extends ValueNotifier<int> {
  NeoSettingsRequests() : super(0);

  /// The one instance shared by the action and every bar in this process.
  static final NeoSettingsRequests instance = NeoSettingsRequests();

  void request() => value = value + 1;
}
