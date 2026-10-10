/// Pure parsing for the workspace pill's own settings.
///
/// Kept free of Flutter so it can be unit-tested with the rest of the logic, and
/// written in the same shape as every other module's options: one key, one
/// type-tolerant read, defaults that leave the stock look alone.
library;

/// The option key holding whether each workspace cell draws its windows.
const String neoWorkspaceShowWindowsKey = 'showWindows';

/// The workspace pill's stored settings.
class NeoWorkspaceOptions {
  const NeoWorkspaceOptions({required this.showWindowIcons});

  /// Whether each workspace cell draws the icons of the windows it holds.
  final bool showWindowIcons;

  bool get isDefault => !showWindowIcons;

  @override
  String toString() => 'NeoWorkspaceOptions(showWindowIcons: $showWindowIcons)';
}

/// Resolves the stored settings, tolerating anything a hand-edited file holds.
///
/// Off by default, and deliberately so: the pill is a workspace indicator first,
/// and icons make it much wider, so drawing them is something the user asks for.
/// A value of the wrong shape reads as "not asked for" rather than throwing.
NeoWorkspaceOptions neoWorkspaceOptions(Map<String, Object?> options) =>
    NeoWorkspaceOptions(
      showWindowIcons: options[neoWorkspaceShowWindowsKey] == true,
    );
