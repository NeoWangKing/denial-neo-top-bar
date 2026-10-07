/// Finds a distribution mark to draw in the launcher pill.
///
/// Denial's plugin SDK exposes no branding and no file chooser, so the `system`
/// icon choice is answered by looking where distributions put their marks:
/// read `/etc/os-release` for the id, then try the paths in
/// [neoSystemLogoCandidates]. Both of those rules are pure; this file is only the
/// part that touches the filesystem.
///
/// The bundle ships the Arch mark as well, which is why an Arch-derived machine
/// still shows a logo after a distribution that forgot to install a pixmap — and
/// why [neoSystemIconProvider] reports availability rather than a path.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/launcher_options.dart';

/// A distribution mark found on this machine, if any.
///
/// Read once, synchronously: it is a small text file plus a handful of `exists`
/// checks, and doing it here rather than behind a `Future` means the pill draws
/// the right mark on its first frame instead of flashing the grid while a future
/// resolves. `/etc/os-release` and the icon directories cannot change while the
/// shell runs anyway.
final neoSystemLogoProvider = Provider<NeoSystemLogo>((ref) {
  final distroId = _readDistroId();
  for (final candidate in neoSystemLogoCandidates(distroId)) {
    if (File(candidate).existsSync()) {
      return NeoSystemLogo(distroId: distroId, path: candidate);
    }
  }
  return NeoSystemLogo(distroId: distroId, path: null);
});

class NeoSystemLogo {
  const NeoSystemLogo({required this.distroId, required this.path});

  /// The distribution id read from `/etc/os-release`; null when unreadable.
  final String? distroId;

  /// The mark installed on this machine, or null when there is none.
  final String? path;

  /// Whether the `system` choice has anything to draw: the machine's own mark, or
  /// the one this plugin bundles.
  bool get available =>
      (path != null && path!.isNotEmpty) ||
      neoLauncherBundledArchAsset.isNotEmpty;
}

String? _readDistroId() {
  try {
    return neoDistroId(File('/etc/os-release').readAsStringSync());
  } on Object {
    // A distribution without the file, or one this process cannot read: the
    // bundled mark is the answer, not an error.
    return null;
  }
}
