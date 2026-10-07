/// Wired-link detection for the control centre's network slot.
///
/// Denial's own network snapshot describes only the **Wi-Fi** device: its
/// NetworkManager backend filters devices to `DeviceType == 2` and derives the
/// connectivity status from that device's state, so a machine running on
/// Ethernet with the radio off reports `disconnected` even though it is online.
/// Until that snapshot grows a device-kind field, the only way for a plugin to
/// tell the user "you are on a cable" is to ask the kernel directly.
///
/// That is what this does, and it does it by reading files — `/sys/class/net` —
/// plus the address list `dart:io` already exposes. No process is spawned and no
/// privilege is needed: sysfs is world-readable, and the rule that interprets it
/// (`neoWiredLinkUp`) is pure and unit-tested.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/control_center_model.dart';

/// How often the link state is re-read.
///
/// A cable being plugged in is not an event this shell can subscribe to, and the
/// read is a directory listing plus a few `stat` calls, so a poll is cheaper
/// than the machinery an event source would need. The provider only exists while
/// the pill is on screen, so an unused bar costs nothing.
const Duration neoLinkPollInterval = Duration(seconds: 5);

/// Whether any interface currently looks like an up Ethernet link.
final neoWiredLinkProvider = StreamProvider<bool>((ref) async* {
  while (true) {
    yield neoWiredLinkUp(await readLinkFacts());
    await Future<void>.delayed(neoLinkPollInterval);
  }
});

/// Reads every network interface's sysfs facts plus its address state.
Future<List<NeoLinkFacts>> readLinkFacts() async {
  final routable = <String>{};
  try {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      if (interface.addresses.isNotEmpty) routable.add(interface.name);
    }
  } on Object {
    // A sandboxed or restricted environment: without addresses nothing can be
    // reported as connected, which is the conservative answer.
  }

  final directory = Directory('/sys/class/net');
  if (!directory.existsSync()) return const <NeoLinkFacts>[];

  final facts = <NeoLinkFacts>[];
  for (final entity in directory.listSync(followLinks: false)) {
    final name = entity.path.split('/').last;
    if (name == 'lo') continue;
    facts.add(
      NeoLinkFacts(
        name: name,
        operState: _readText('${entity.path}/operstate'),
        wireless: Directory('${entity.path}/wireless').existsSync(),
        // A `device` entry is a symlink to the parent bus device. Bridges, veth
        // pairs, bonds, tunnels and other software interfaces do not have one,
        // which is what keeps `docker0` from being reported as a cable.
        physical:
            Link('${entity.path}/device').existsSync() ||
            Directory('${entity.path}/device').existsSync(),
        routable: routable.contains(name),
      ),
    );
  }
  return facts;
}

String _readText(String path) {
  try {
    return File(path).readAsStringSync().trim();
  } on Object {
    return '';
  }
}
